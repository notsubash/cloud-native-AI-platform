# Cloud Native AI Platform

Cost-first learning lab: infrastructure around a deliberately dumb AI API.

See [PLAN.md](PLAN.md) for the full roadmap and [docs/cost-budget.md](docs/cost-budget.md) for the **$15/mo** hard cap.

## Phase 1 — local stack

```bash
cp .env.example .env
# For DeepSeek: set LLM_MODE=deepseek and DEEPSEEK_API_KEY=sk-...
make up          # or: docker compose up --build -d
curl -s localhost:8000/health
curl -s localhost:8000/ready
curl -s localhost:8000/metrics | head
curl -s -X POST localhost:8000/v1/summarize \
  -H 'content-type: application/json' \
  -d '{"text":"Cloud native platforms need boring, reliable plumbing."}'
make test        # uses stub via dependency overrides — no API key required
make down
```

Services: API (`:8000`), Postgres (`:5432`), Redis (`:6379`). Compose healthcheck uses `/health` (liveness); K8s will use `/ready` for traffic routing.

**DeepSeek:** get an API key from [platform.deepseek.com](https://platform.deepseek.com). Model defaults to `deepseek-chat` (OpenAI-compatible `/chat/completions`).

## Why multi-stage Docker builds

Builder stage installs deps; runtime stage copies only the venv + app. Smaller images → faster CI pulls and a smaller attack surface (no compilers/pip cache in prod).
