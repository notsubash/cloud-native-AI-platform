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

## Helm foundations

Owned the API as `helm/api` (Chart.yaml, values, templates, helpers, NOTES) and left Postgres/Redis to Bitnami — own app charts, consume mature data-store charts.

`values-local.yaml` is the local knob file: `pullPolicy: Never`, stub LLM, tiny resources, and Bitnami Service DNS (`postgres-postgresql`, `redis-master`). Defaults in `values.yaml` stay closer to the raw `kubernetes/base` names; local overrides win with `-f`.

Proved the exit checklist: `helm upgrade ... --set image.tag=local-v2` moved the pod image; `helm rollback api 1` restored `cloud-native-ai-api:local` and wrote a new history revision (rollback is a new revision, not a rewind of the list).

Service DNS still bites after switching charts: Bitnami release `postgres` → Service `postgres-postgresql`, Redis standalone → `redis-master`. Wrong host → `/ready` fails even when pods look fine.

Do not run raw `api`/`postgres`/`redis` manifests next to Helm/Bitnami in the same namespace — two Deployments fight for the same mental model. Pick one path: today that path is Bitnami + `helm/api` locally, and Argo + `values-hobby.yaml` on the VPS.

`helm template` before `install` caught path typos (`./help/...`); `helm lint` + rendered YAML beat debugging CrashLoops from bad templates.

## CI & GHCR (GitHub Actions)

Split the pipeline into jobs on purpose: `test` fails fast on lint/pytest before Buildx spends time; `build` only runs after tests green; `helm` lint/template runs in parallel with `build` as an offline chart check — no cluster, no deploy.

Kept CI and the Dockerfile aligned: Python 3.12, same `requirements.txt`, same golden-path pytest as `make test` — stub LLM via dependency overrides so no API key in secrets.

PR runs prove the Dockerfile (`build` with `push: false`); only `push` to `main` logs into GHCR and publishes. Unmerged code never becomes `:latest` — the registry stays a merge gate, not a PR artifact dump.

GHCR auth is `GITHUB_TOKEN` + `packages: write` on the build job only — no PAT for same-account push. Tags: immutable `sha-<short>` on every build context, `latest` only on default-branch pushes (pin deploys on SHA, not floating latest).

Buildx + `cache-from` / `cache-to type=gha,mode=max` stores builder layers in GitHub Actions cache — first run cold (~0% cached), later runs reuse pip/install layers. The `.dockerbuild` artifact is a Buildx record, not a published package.

CI produces images; it does not deploy. Laptop Helm keeps local tags; cloud wiring (`ghcr.io/...`, `pullPolicy: IfNotPresent`, `imagePullSecrets`) lives in `values-hobby.yaml` and is applied by Argo — not bolted onto Actions with `kubectl apply`.

## Hobby cloud & GitOps (Hetzner + k3s + Argo CD)

Applied Terraform for real: Hetzner CX23 (`cnai-hobby`), firewall, cloud-init → single-node k3s. Billing starts at `apply`; the only reliable off switch is `terraform destroy` (console power-off still charges for the reserved server).

Cloudflare provider still configures even when DNS is disabled — empty `provider "cloudflare" {}` demands a token and can pull a breaking provider major. For hobby without DNS: leave Cloudflare out of the apply path entirely (comment provider + DNS module) until you need records.

Copied kubeconfig from the **laptop** with `scp root@<ip>:... ~/.kube/hobby.yaml`, then replaced `127.0.0.1` with the public IP. Running `scp` while already SSH’d into the VPS targets the server itself and fails (key-only auth, wrong destination).

Argo install: prefer `kubectl apply --server-side` — client-side apply blows the last-applied annotation size limit on large CRDs (ApplicationSet). Core `Application` still works; finish install with server-side / `--force-conflicts` if needed.

GitOps only sees what GitHub has. Local branch + uncommitted `values-hobby.yaml` → Argo errors like “unable to resolve revision” or missing values file. Commit, push, then Sync.

`ghcr-pull` must be a docker-registry Secret whose password is a GitHub PAT (`read:packages`). An image tag like `sha-...` is not a password — that mistake yields `ImagePullBackOff` after a “healthy” Application.

Kept sync **manual** at first: applying the Application CR registers desired state; pods appear after Sync. Automate prune/selfHeal later once the loop feels boring.

Firewall `ssh_source_cidrs` is a single home IP `/32`. Café/VPN IP changes look like “SSH hang” — update Terraform and re-apply before debugging k3s.

## Observability (Phase 7)

Installed kube-prometheus-stack **before** expecting Argo to sync a `ServiceMonitor`. SyncFailed with “could not find monitoring.coreos.com/ServiceMonitor” means the Prometheus Operator CRDs are missing — consumer before provider. Fix: Helm install `mon`, then Sync `api`.

Git having RED middleware + `/debug/boom` is not enough: the **running** GHCR tag must include that commit. Symptoms of an old image: `/debug/boom` → 404 and `/metrics` only shows `summarize_requests_total` (no `http_requests_total`). Pin `sha-...` from a build after the observability commit, Sync, restart if needed.

Loki alone stores nothing useful; Promtail (or Alloy) must ship stdout. Wrong Promtail client URL → silent empty Grafana Explore until `kubectl -n monitoring get svc` matches the push endpoint.

Kept the stack right-sized (3d retention, 30s scrape, single replicas). Diagnosis drill that matters for interviews: force 500 with a known `X-Request-ID` → PromQL error rate → Loki `|= "request_id=..."` → optional Alertmanager `ApiHighErrorRate`.

One place for ports/charts/namespaces: `docs/runbooks/hobby-stack.md`. Monitoring how-to: `monitoring/README.md`.
