# Architecture (stub)

Phase 0–1: local Docker Compose only.

```
Client → FastAPI (apps/api) → PostgreSQL
                          └→ Redis
```

LLM calls are **stubbed** so infra stays the focus. Later phases replace Compose with k3s and add GitOps/observability — see `PLAN.md`.
