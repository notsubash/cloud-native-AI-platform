from __future__ import annotations

import uuid
import json
import logging
from contextlib import asynccontextmanager
from typing import Annotated
import time
import httpx
import psycopg
import redis
from fastapi import Depends, FastAPI, HTTPException, Response, Request
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest, Histogram
from pydantic import BaseModel, Field
from starlette.middleware.base import BaseHTTPMiddleware
from app.config import Settings, get_settings
from app.llm import summarize

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s request_id=%(request_id)s %(message)s")
log = logging.getLogger("api")

SUMMARIZE_REQUESTS = Counter("summarize_requests_total", "Summarize endpoint calls", ["status"])

# ---- RED metrics for ALL HTTP requests -------------------------------------
HTTP_REQUESTS = Counter(
    "http_requests_total",
    "HTTP requests",
    ["method", "path", "status"],
)

# Buckets in seconds — tune for your SLOs. These are fine for a learning API.
HTTP_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["method", "path"],
    buckets=(0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
)

class RequestIdFilter(logging.Filter):
    """Ensure every log record has request_id so the format string never KeyErrors."""
    def filter(self, record: logging.LogRecord) -> bool:
        if not hasattr(record, "request_id"):
            record.request_id = "-"
        return True
logging.getLogger().addFilter(RequestIdFilter())
class ObservabilityMiddleware(BaseHTTPMiddleware):
    """
    One middleware, two teaching jobs:
      1) Attach X-Request-ID (client-provided or generated) for log correlation
      2) Record RED metrics for every request
    Later (OTel): the same place is where a trace span often starts.
    """
    async def dispatch(self, request: Request, call_next):
        # Prefer inbound header so a client / gateway can propagate the id
        request_id = request.headers.get("x-request-id") or str(uuid.uuid4())
        request.state.request_id = request_id
        # Skip scraping /metrics itself from RED (optional; avoids noise)
        path = request.url.path
        track = path != "/metrics"
        start = time.perf_counter()
        status_code = 500
        try:
            response = await call_next(request)
            status_code = response.status_code
            response.headers["X-Request-ID"] = request_id
            return response
        finally:
            if track:
                elapsed = time.perf_counter() - start
                # Use path as-is for this tiny API; normalize if you add path params
                HTTP_REQUESTS.labels(
                    method=request.method,
                    path=path,
                    status=str(status_code),
                ).inc()
                HTTP_DURATION.labels(method=request.method, path=path).observe(elapsed)
                # Structured-ish log line — Loki can filter on request_id=
                log.info(
                    "request method=%s path=%s status=%s duration_ms=%.1f",
                    request.method,
                    path,
                    status_code,
                    elapsed * 1000.0,
                    extra={"request_id": request_id},
                )

@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    logging.getLogger().setLevel(settings.log_level.upper())
    log.info("starting api llm_mode=%s", settings.llm_mode)
    yield


app = FastAPI(title="cloud-native-ai-api", version="0.1.0", lifespan=lifespan)
app.add_middleware(ObservabilityMiddleware)

SettingsDep = Annotated[Settings, Depends(get_settings)]


class SummarizeIn(BaseModel):
    text: str = Field(min_length=1, max_length=20_000)


class SummarizeOut(BaseModel):
    summary: str
    mode: str


@app.get("/health")
def health():
    """Liveness: process is up. K8s will use this as livenessProbe."""
    return {"status": "ok"}


@app.get("/ready")
def ready(settings: SettingsDep):
    """Readiness: dependencies reachable. K8s will use this as readinessProbe."""
    errors: list[str] = []

    try:
        with psycopg.connect(settings.psycopg_dsn, connect_timeout=2) as conn:
            conn.execute("SELECT 1")
    except Exception as exc:  # ponytail: coarse errors for probe; split later if needed
        errors.append(f"postgres: {exc}")

    try:
        with redis.from_url(settings.redis_url, socket_connect_timeout=2) as r:
            if r.ping() is not True:
                errors.append("redis: unexpected ping response")
    except Exception as exc:
        errors.append(f"redis: {exc}")

    if errors:
        return Response(
            content=json.dumps({"status": "not_ready", "errors": errors}),
            status_code=503,
            media_type="application/json",
        )
    return {"status": "ready"}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.post("/v1/summarize", response_model=SummarizeOut)
def summarize_endpoint(body: SummarizeIn, settings: SettingsDep):
    try:
        summary = summarize(body.text, settings)
        SUMMARIZE_REQUESTS.labels(status="ok").inc()
        return SummarizeOut(summary=summary, mode=settings.llm_mode)
    except httpx.HTTPError as exc:
        SUMMARIZE_REQUESTS.labels(status="error").inc()
        detail = str(exc)
        if isinstance(exc, httpx.HTTPStatusError) and exc.response.text:
            detail = exc.response.text
        raise HTTPException(status_code=502, detail=f"llm backend error: {detail}") from exc
    except ValueError as exc:
        SUMMARIZE_REQUESTS.labels(status="error").inc()
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    except Exception:
        SUMMARIZE_REQUESTS.labels(status="error").inc()
        raise

# ---------------------------------------------------------------------------
# TEACHING ONLY — remove or gate behind env before "real" use.
# Hit this to practice: metrics spike → Loki shows request_id → you diagnose.
# ---------------------------------------------------------------------------
@app.get("/debug/boom")
def boom():
    raise HTTPException(status_code=500, detail="forced failure for observability drill")