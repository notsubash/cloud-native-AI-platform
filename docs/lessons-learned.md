# Lessons learned

Short notes after each stretch of work (5–10 lines): what broke, what you fixed, what you’d do differently.

## Repo skeleton & local API

Locked the lab to Level 1 maturity with a $15/mo cap and a repo skeleton that mirrors the target layout (`apps/`, `infrastructure/`, `kubernetes/`, `helm/`, `docs/`) so later work slots in without reshuffling.

Built a thin FastAPI gateway with `/health`, `/ready`, `/metrics`, and `POST /v1/summarize` — the probe and observability hooks K8s will need before any real AI complexity.

Split liveness from readiness on purpose: `/health` stays cheap and always 200 when the process is up; `/ready` checks Postgres and Redis so traffic can wait until dependencies are actually there.

Used a multi-stage Dockerfile (builder venv → slim runtime, non-root user) to keep the image small and CI-friendly — same pattern we’ll push to GHCR later.

Wired local dev with Docker Compose: API + Postgres + Redis, env-based config via `.env`, and a `Makefile` for `up` / `test` / `down`.

Kept the LLM behind a single `summarize()` function with `stub` for tests/CI and `deepseek` for real calls via OpenAI-compatible HTTP — routes stay stable when the backend changes.

Added golden-path tests with `dependency_overrides` so CI never needs an API key, plus mocked `/ready` coverage for the K8s-relevant probe path.

## Terraform foundations

Scaffolded infra under `infrastructure/terraform/` with reusable `modules/{server,firewall,dns}` and a thin `environments/hobby` root — same “compose later without reshuffling” idea as the repo layout.

Verified tools in the shell that actually runs them: WinGet can install Terraform while an old terminal still lacks it on PATH, so `which terraform` / `terraform version` beat assuming the install worked.

Learned HCL is strict about assignment — `source =` not `source -` — and that a missing quote or brace often shows up as “missing argument” or “unclosed block,” not a clear syntax tip.

Treated `terraform init` as per-module: one bad `module` block does not mean the whole tree is wrong; fix the failing block and leave the rest alone.

Declared provider sources in every module that uses them (`hetznercloud/hcloud`, `cloudflare/cloudflare`). Root `required_providers` alone is not enough — child modules default to `hashicorp/<name>` and init fails even after the correct plugins install.

Kept cost control explicit: run `plan` early, delay `apply` until the VPS is actually needed so Hetzner stays off the bill during scaffolding.

## Kubernetes foundations (local)

Mapped Compose concepts straight onto Kubernetes: services → Deployments + Services, env/`.env` → ConfigMap + Secret, volumes → PVC, `depends_on` → readiness probes. Applied everything with `kubectl apply -k kubernetes/base` under namespace `ai-platform`.

Wired in-cluster DNS on purpose: `DATABASE_URL` / `REDIS_URL` must use Service names (`postgres`, `redis`), not `localhost` — the API pod’s localhost is itself, not the host or sibling containers.

Reused the FastAPI probes as designed: liveness → `/health` (process up), readiness → `/ready` (Postgres + Redis reachable). That split is what keeps a pod from getting traffic while deps are still starting.

Hit `ErrImageNeverPull` with `imagePullPolicy: Never` when the image existed on the host Docker daemon but not on the node. Docker Desktop’s **kind** cluster does not share the host image store, and it does not show up in the standalone `kind` CLI (`kind get clusters` / `kind load` are empty or wrong).

Preferred Docker Desktop **kubeadm** for this lab so a local `docker build -t cloud-native-ai-api:local` is visible with `Never` and no import step. Tag must match `api.yaml` exactly — Compose’s image name is a different string and does not help the Deployment.

Do not run `make up` (Compose) alongside the K8s stack. Access the API with `kubectl port-forward svc/api 8000:8000`, then curl `/health`, `/ready`, and `/v1/summarize`. After code changes: rebuild the image and `rollout restart deploy/api`.
