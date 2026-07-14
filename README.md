# Cloud Native AI Platform

Cost-first learning lab: infrastructure around a deliberately dumb AI API.

See [PLAN.md](PLAN.md) for the full roadmap and [docs/cost-budget.md](docs/cost-budget.md) for the **$15/mo** hard cap.

## Progress so far

| Phase | Status | What landed |
|-------|--------|-------------|
| 1 — Local API + Compose | Done | FastAPI (`/health`, `/ready`, `/metrics`, `/v1/summarize`), multi-stage image, Compose, tests |
| 2 — Terraform foundations | Scaffolded | Modules + hobby env; **plan only** until cloud VPS is needed |
| 3 — Local Kubernetes | Done | `kubernetes/base`, probes, port-forward; runbook [docs/runbooks/app-wont-start.md](docs/runbooks/app-wont-start.md) |
| 4 — Helm | Done | `helm/api`, Bitnami Postgres/Redis, upgrade/rollback; runbook [docs/runbooks/helm.md](docs/runbooks/helm.md) |
| 5+ — CI / GitOps / cloud | Next | See `PLAN.md` |

Lessons: [docs/lessons-learned.md](docs/lessons-learned.md). Chart vs Bitnami: [helm/NOTES-bitnami-compare.md](helm/NOTES-bitnami-compare.md).

## Which stack to run (pick one)

| Goal | Use |
|------|-----|
| Fast laptop loop, no cluster | **Compose** below |
| Learn raw Deployments / Services | **Kustomize** (`kubectl apply -k kubernetes/base`) |
| Day-to-day after Phase 4 | **Helm + Bitnami** — [docs/runbooks/helm.md](docs/runbooks/helm.md) |

Do not run Compose and the cluster at the same time. Terraform is offline until you need a VPS.

---

## Phase 1 — local Compose

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

Services: API (`:8000`), Postgres (`:5432`), Redis (`:6379`). Compose healthcheck uses `/health` (liveness); K8s/Helm use `/ready` for traffic routing.

**DeepSeek:** get an API key from [platform.deepseek.com](https://platform.deepseek.com). Model defaults to `deepseek-chat` (OpenAI-compatible `/chat/completions`).

## Phase 4 — Helm (preferred local cluster path)

Prerequisites: Docker Desktop Kubernetes (kubeadm), image built as `cloud-native-ai-api:local`.

```bash
# Bitnami data stores + our API chart — full sequence in the runbook
helm upgrade --install api ./helm/api -n ai-platform -f ./helm/api/values-local.yaml
kubectl -n ai-platform port-forward svc/api 8000:8000
```

Upgrade / rollback:

```bash
helm upgrade api ./helm/api -n ai-platform -f ./helm/api/values-local.yaml --set image.tag=local-v2
helm rollback api 1 -n ai-platform
helm history api -n ai-platform
```

Full start, DNS notes, and tear-down: [docs/runbooks/helm.md](docs/runbooks/helm.md).

## Why multi-stage Docker builds

Builder stage installs deps; runtime stage copies only the venv + app. Smaller images → faster CI pulls and a smaller attack surface (no compilers/pip cache in prod).
