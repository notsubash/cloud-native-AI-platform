# Lessons learned

Short notes after each phase (5–10 lines): what broke, what you fixed, what you’d do differently.

## Phase 0–1

Locked the lab to Level 1 maturity with a $15/mo cap and a repo skeleton that mirrors the target layout (`apps/`, `infrastructure/`, `kubernetes/`, `helm/`, `docs/`) so later phases slot in without reshuffling.

Built a thin FastAPI gateway with `/health`, `/ready`, `/metrics`, and `POST /v1/summarize` — the probe and observability hooks K8s will need before any real AI complexity.

Split liveness from readiness on purpose: `/health` stays cheap and always 200 when the process is up; `/ready` checks Postgres and Redis so traffic can wait until dependencies are actually there.

Used a multi-stage Dockerfile (builder venv → slim runtime, non-root user) to keep the image small and CI-friendly — same pattern we’ll push to GHCR later.

Wired local dev with Docker Compose: API + Postgres + Redis, env-based config via `.env`, and a `Makefile` for `up` / `test` / `down`.

Kept the LLM behind a single `summarize()` function with `stub` for tests/CI and `deepseek` for real calls via OpenAI-compatible HTTP — routes stay stable when the backend changes.

Added golden-path tests with `dependency_overrides` so CI never needs an API key, plus mocked `/ready` coverage for the K8s-relevant probe path.
