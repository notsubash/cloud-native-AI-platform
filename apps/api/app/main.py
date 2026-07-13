from __future__ import annotations

import json
import logging
from contextlib import asynccontextmanager
from typing import Annotated

import httpx
import psycopg
import redis
from fastapi import Depends, FastAPI, HTTPException, Response
from prometheus_client import CONTENT_TYPE_LATEST, Counter, generate_latest
from pydantic import BaseModel, Field

from app.config import Settings, get_settings
from app.llm import summarize

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
log = logging.getLogger("api")

SUMMARIZE_REQUESTS = Counter("summarize_requests_total", "Summarize endpoint calls", ["status"])


@asynccontextmanager
async def lifespan(app: FastAPI):
    settings = get_settings()
    logging.getLogger().setLevel(settings.log_level.upper())
    log.info("starting api llm_mode=%s", settings.llm_mode)
    yield


app = FastAPI(title="cloud-native-ai-api", version="0.1.0", lifespan=lifespan)

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
