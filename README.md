# Cloud Native AI Platform

A cost-bounded platform for a minimal AI summarization API, built with production-oriented patterns: multi-stage containers, Kubernetes probes, Helm packaging, Terraform foundations, and GitHub Actions publishing immutable images to GHCR.

Monthly spend is capped at **$15**. See [docs/cost-budget.md](docs/cost-budget.md).

## Platform status

| Layer | Status | Delivered |
|-------|--------|-----------|
| API + local dev | Done | FastAPI (`/health`, `/ready`, `/metrics`, `POST /v1/summarize`), Compose, golden-path tests |
| Container image | Done | Multi-stage Dockerfile, non-root runtime |
| Terraform (hobby) | Scaffolded | Hetzner modules + hobby env; not applied until a VPS is needed |
| Kubernetes (local) | Done | `kubernetes/base`, liveness/readiness probes. [Runbook](docs/runbooks/app-wont-start.md) |
| Helm | Done | `helm/api` + Bitnami Postgres/Redis. [Runbook](docs/runbooks/helm.md) |
| CI / registry | Done | GitHub Actions: test → build → push to GHCR on `main` |
| GitOps / cloud deploy | Next | Argo CD + VPS |

Operational notes: [docs/lessons-learned.md](docs/lessons-learned.md).

## Architecture

```
Client → FastAPI (apps/api) → PostgreSQL
                          └→ Redis
```

The API exposes standard health and metrics endpoints. LLM calls go through a single `summarize()` abstraction: `stub` in tests/CI, `deepseek` via OpenAI-compatible HTTP when configured. Liveness (`/health`) stays cheap; readiness (`/ready`) gates traffic until Postgres and Redis are reachable.

## Repository layout

```
apps/api/              FastAPI service, Dockerfile, tests
kubernetes/base/       Raw Kustomize manifests
helm/api/              Application Helm chart
infrastructure/        Terraform modules + hobby environment
.github/workflows/     CI pipeline
docs/                  Runbooks, architecture, cost budget
```

## Deployment options

Pick **one** local stack. Do not run Compose and a cluster side by side.

| Goal | Path |
|------|------|
| Fastest dev loop | Docker Compose (below) |
| Learn raw K8s objects | `kubectl apply -k kubernetes/base` |
| Day-to-day cluster work | Helm + Bitnami. [Runbook](docs/runbooks/helm.md) |

Cloud infrastructure (`infrastructure/terraform/environments/hobby`) stays offline until a VPS is required.

## Local development (Compose)

```bash
cp .env.example .env
# Optional: LLM_MODE=deepseek and DEEPSEEK_API_KEY=sk-...
make up
curl -s localhost:8000/health
curl -s localhost:8000/ready
curl -s -X POST localhost:8000/v1/summarize \
  -H 'content-type: application/json' \
  -d '{"text":"Cloud native platforms need boring, reliable plumbing."}'
make test    # stub LLM, no API key required
make down
```

Services: API (`:8000`), Postgres (`:5432`), Redis (`:6379`).

## Kubernetes (Helm)

Prerequisites: Docker Desktop Kubernetes (kubeadm), image built as `cloud-native-ai-api:local`.

```bash
helm upgrade --install api ./helm/api -n ai-platform -f ./helm/api/values-local.yaml
kubectl -n ai-platform port-forward svc/api 8000:8000
```

Upgrade and rollback:

```bash
helm upgrade api ./helm/api -n ai-platform -f ./helm/api/values-local.yaml --set image.tag=local-v2
helm rollback api 1 -n ai-platform
helm history api -n ai-platform
```

Full sequence, DNS notes, and tear-down: [docs/runbooks/helm.md](docs/runbooks/helm.md).

## CI / container registry

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on pull requests and pushes to `main`:

| Job | Purpose |
|-----|---------|
| `test` | `compileall` + pytest (`apps/api`) |
| `build` | Buildx image build; push to GHCR on `main` only |
| `helm` | `helm lint` + `helm template` (offline chart validation) |

Published image: `ghcr.io/<owner>/cloud-native-ai-api`, tagged `sha-<short>` (immutable) and `latest` on `main`.

Pull after merge:

```bash
gh auth token | docker login ghcr.io -u <owner> --password-stdin
docker pull ghcr.io/<owner>/cloud-native-ai-api:sha-<commit>
```

PR builds validate the Dockerfile without publishing. Deploy wiring to GHCR images is handled by GitOps, not in CI.

## Image build

The API uses a multi-stage Dockerfile: a builder stage installs dependencies into a venv; the runtime stage copies only the venv and application code under a non-root user. Smaller images mean faster CI pulls and a reduced attack surface.
