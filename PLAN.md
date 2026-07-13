# Cloud Native AI Platform — Cost-First Learning Plan

> A **10–12 week** roadmap to learn modern cloud / platform engineering by building a production-shaped AI platform — **without burning money**.

---

## How to use this plan

1. Treat this as a **learning lab**, not a SaaS product launch.
2. Stay on the **cheapest path that still teaches the real concept**.
3. Do **not** jump to multi-cloud, GPUs, or a service mesh until the core loop works.
4. After each phase, write 5–10 lines in `docs/lessons-learned.md`: what broke, what you fixed, what you’d do differently.

**Primary goal:** infrastructure around AI (IaC, K8s, GitOps, CI/CD, observability, HA/DR).  
**AI goal:** keep the app deliberately dumb so infra stays the focus.

---

## Cost philosophy (read this first)

| Principle | What it means here |
|-----------|--------------------|
| Local first | Weeks 1–3 should cost **$0** (Docker + local k3s/kind). |
| One cheap box | Prefer **one VPS** running k3s over managed EKS/GKE/AKS. |
| One cluster, many namespaces | `dev` / `staging` / `prod` as namespaces before a second cluster. |
| Free tiers only | Cloudflare DNS, GitHub Actions minutes, GHCR images. |
| Defer heavy tools | Vault, Istio, Kafka, GPUs = stretch only. |
| Destroy when idle | Tear down the VPS between phases if budget is tight; keep Terraform so recreate is cheap. |
| No paid LLM required | Use **Ollama** locally or a free/cheap API; mock the model in tests. |

### Recommended budget tiers

| Tier | Monthly target | What you run |
|------|----------------|--------------|
| **$0 Lab** | $0 | Laptop: Docker Compose → kind/k3d. All concepts except real public DNS/TLS. |
| **Hobby Cloud** | **~$5–12** | 1× Hetzner / OVH / Oracle Free Tier VPS + Cloudflare free DNS. **Recommended default.** |
| **Comfort** | ~$20–40 | Larger VPS or 2 small nodes; still avoid managed K8s. |
| **Avoid for learning** | $100+ | EKS/GKE + managed DBs + GPU nodes — learn those *after* you can operate k3s yourself. |

### Concrete cheap stack (default for this plan)

```
DNS / TLS edge     → Cloudflare (free)
Compute            → 1 VPS, 2–4 vCPU, 4–8 GB RAM (Hetzner CX22/CX32 or Oracle Always Free)
Kubernetes         → k3s (lightweight, one binary, low RAM)
Registry           → GHCR (free with GitHub)
GitOps             → Argo CD
Object storage     → MinIO on the same VPS (not AWS S3 yet)
DB / cache / queue → PostgreSQL + Redis on-cluster (Bitnami/official charts)
Vectors            → Qdrant (single replica)
LLM                → Ollama on laptop OR tiny API calls; never GPU VPS in core path
Observability      → kube-prometheus-stack + Loki (+ Tempo when RAM allows)
Secrets            → SOPS / Sealed Secrets first; Vault only as stretch
Mesh               → skip until Phase 10 optional; prefer Linkerd over Istio if you try one
```

**Why this stack:** you still touch Terraform, Kubernetes, Helm, GitOps, CI/CD, ingress, TLS, metrics, HPA, backups — the senior-engineer surface area — on a bill you can actually sustain for 3 months.

---

## What you will *not* do in the core 12 weeks

These are valuable later; they inflate cost and complexity early:

- Multi-cloud (AWS + GCP + Azure)
- Multi-cluster federation
- GPU inference nodes
- Kafka (use Redis lists / RabbitMQ later if needed)
- Full Istio service mesh on day one
- Managed Kubernetes (EKS/GKE/AKS)
- Separate prod account with always-on HA across AZs

Stretch goals at the end map 1:1 to these — earn them.

---

## Final architecture (cost-optimized)

```
                         Internet
                             │
                      Cloudflare DNS (free)
                             │
                    VPS public IP / LB
                             │
                      NGINX / Traefik Ingress
                             │
                 Kubernetes (k3s) — single node*
────────────────────────────────────────────────
              AI Gateway (FastAPI)

           /         |          \
      API         Worker      Scheduler

              Redis (queue + cache)

   PostgreSQL      Qdrant       MinIO
────────────────────────────────────────────────
 Observability (right-sized)
 Prometheus · Grafana · Loki · (Tempo if RAM OK)
 OpenTelemetry SDK in apps
────────────────────────────────────────────────
 GitOps
 GitHub → GitHub Actions → GHCR → Argo CD → cluster
────────────────────────────────────────────────
 Infrastructure
 Terraform (VPS, firewall, DNS) · Helm · Kustomize overlays
```

\* Start single-node. Add a second cheap node only if you specifically want to practice HA / PDB eviction — not required for learning most topics.

---

## Repository structure (target)

```
cloud-native-ai-platform/
├── apps/
│   ├── api/                 # FastAPI gateway
│   ├── worker/              # async jobs
│   └── scheduler/           # cron-like triggers (can wait until mid-project)
├── infrastructure/
│   └── terraform/
│       ├── environments/    # dev (local docs) / cloud
│       └── modules/         # network, server, dns, firewall
├── kubernetes/
│   ├── base/
│   └── overlays/            # dev, staging, prod (namespaces)
├── helm/
│   ├── api/
│   └── worker/
├── monitoring/              # dashboards, alerts, OTel hints
├── .github/workflows/
├── docs/
│   ├── architecture.md
│   ├── runbooks/
│   └── lessons-learned.md
├── scripts/
├── PLAN.md                  # this file
└── README.md
```

Keep AI code thin. Most learning value lives under `infrastructure/`, `kubernetes/`, `helm/`, `.github/`, `monitoring/`.

---

## Timeline overview (10–12 weeks)

| Week | Phase | Cost | Focus |
|------|-------|------|--------|
| 1 | 0 + 1 | $0 | Repo hygiene + simple AI service on Compose |
| 2 | 2 | $0 | Terraform locally (Docker provider / mock) + plan cloud modules |
| 3 | 3 | $0 | Local Kubernetes (k3d/kind) — replace Compose |
| 4 | 4 | $0 | Helm charts |
| 5 | 5 | $0 | GitHub Actions → GHCR |
| 6 | 6 | **~$5–12** | Cheap VPS + k3s + Argo CD GitOps |
| 7 | 7 | same VPS | Observability (right-sized) |
| 8 | 8 | same VPS | HPA + KEDA (queue-based) |
| 9 | 9–10 | same VPS | Secrets + TLS/Ingress/Cloudflare |
| 10 | 11 | same VPS | Argo Rollouts (canary) |
| 11 | 12–13 | same VPS | Backups/DR + multi-env overlays |
| 12 | 14–15 | same VPS | Hardening + portfolio docs |

**Buffer:** if a week slips, cut Tempo, scheduler app, or mesh — never cut backups/docs at the end.

---

## Phase 0 — Project framing & cost guardrails (Day 1)

**Goal:** decide maturity and budget before writing infra.

**Why first:** without a budget ceiling and a “dumb AI” scope, this project turns into an expensive chatbot.

### Decisions to lock

- [ ] Maturity: **Level 1 learning lab** (not Level 2 multi-tenant SaaS)
- [ ] Monthly max spend: e.g. **$15 hard cap**
- [ ] Cloud provider for VPS: Hetzner / Oracle Free / OVH (pick one)
- [ ] LLM strategy: Ollama local **or** free-tier API **or** stubbed responses
- [ ] Domain: free subdomain or cheap `.xyz` behind Cloudflare

### Deliverables

- [ ] This `PLAN.md` accepted
- [ ] Empty repo skeleton + `.gitignore` (no secrets, no model weights)
- [ ] `docs/cost-budget.md` with hard monthly cap and “destroy VPS” checklist

### Cost controls (non-negotiable)

- No GPU instances in core path
- Auto-destroy / calendar reminder to `terraform destroy` if pausing > 7 days
- Prefer GHCR over paid registries
- Cap GitHub Actions: build on `main` + PRs only; no matrix of 6 OS images

---

## Phase 1 — Build a simple, deployable AI service (Week 1)

**Goal:** something that runs in Docker and exposes the hooks ops cares about.

**AI ideas (pick one, keep it tiny):**

- Document summarizer (paste text → summary)
- Tiny RAG API (upload a few docs → query)
- Embedding + search playground
- Prompt playground with provider stub

### Requirements (infra-relevant)

| Requirement | Why it matters for cloud learning |
|-------------|-----------------------------------|
| FastAPI | Common production API shape |
| `/health` + `/ready` | Probes later in K8s |
| `/metrics` (Prometheus format) | Observability phase |
| PostgreSQL | Stateful workload + backups |
| Redis | Cache + later queue for workers |
| Docker multi-stage build | Smaller images, CI speed |
| `docker compose` | Local baseline before K8s |
| Env-based config | 12-factor; no secrets in image |

### Explicitly out of scope

- Fancy RAG quality, fine-tuning, agents, GPU models
- Perfect frontend (CLI or minimal Swagger is enough)

### Learn

- Docker, multi-stage builds, Compose networking
- Env vars / `.env.example`
- Basic API design and structured logging

### Deliverables

- [ ] `apps/api` (+ optional `apps/worker`)
- [ ] Dockerfile(s)
- [ ] `docker-compose.yml` (api, postgres, redis; optional qdrant)
- [ ] README: `make up` / compose up, hit health + one AI endpoint
- [ ] Golden path: one happy-path integration test (even if AI is stubbed)

### Cost

**$0** — laptop only.

### Exit checklist

- [ ] `curl` health/metrics works via Compose
- [ ] Image builds reproducibly
- [ ] You can explain *why* multi-stage builds matter for CI and attack surface

---

## Phase 2 — Terraform foundations (Week 2)

**Goal:** everything *cloud-shaped* is described as code — even before you pay for a server.

**Why before K8s in cloud:** you want “recreate my lab in 20 minutes” muscle memory. That is the platform engineer skill.

### Topics

- Providers, variables, outputs, state, modules
- Local state first → remote state later (cheap: Cloudflare R2 / Backblaze B2 / MinIO — or Terraform Cloud free tier)

### Provision (when you are ready to spend)

| Resource | Cheap approach |
|----------|----------------|
| VPS | Hetzner / Oracle Always Free |
| Firewall | Provider firewall + SSH key only |
| DNS | Cloudflare (free) |
| Object storage | Skip cloud S3; use MinIO in-cluster later |

### Suggested layout

```
infrastructure/terraform/
├── modules/
│   ├── network/      # or provider-specific firewall
│   ├── server/       # VPS + cloud-init for k3s
│   └── dns/          # Cloudflare records
├── environments/
│   └── hobby/        # the one real env
├── main.tf
├── variables.tf
└── outputs.tf
```

### Cost-saving tactics

1. **Week 2:** write modules + `terraform plan` against real provider; **do not apply** until Phase 6 if you want $0 longer.
2. Use **one workspace / one env** only.
3. Prefer **cloud-init** to install k3s over a separate configuration management tool.
4. Store state remotely only when collaborating or destroying/recreating often.

### Deliverables

- [ ] Modules for server + firewall + DNS
- [ ] Documented `init` / `plan` / `apply` / `destroy`
- [ ] Output: public IP, SSH command, DNS names
- [ ] Stretch: reusable modules with clear inputs/outputs

### Exit checklist

- [ ] You can destroy and recreate the VPS from Terraform without clicking the UI
- [ ] You understand state lock and why local state is risky

---

## Phase 3 — Kubernetes fundamentals (Week 3, still $0)

**Goal:** replace Compose with Kubernetes **locally**.

**Why local first:** managed/cloud K8s bills teach billing, not Pods. Learn objects on kind/k3d/k3s-in-Docker.

### Topics

Pods, Deployments, ReplicaSets, Services, Ingress, ConfigMaps, Secrets, Namespaces

### Deploy locally

- API, Worker (if exists)
- Redis, PostgreSQL
- Qdrant (optional if RAG)

### Learn

- `kubectl` get/describe/logs/exec
- Port-forward vs Ingress
- CrashLoopBackOff debugging

### Cost

**$0** — kind or k3d on the laptop.

### Deliverables

- [ ] `kubernetes/base` manifests (or Kustomize)
- [ ] Local Ingress (or port-forward documented)
- [ ] Short runbook: “app won’t start — debug path”

### Exit checklist

- [ ] App reachable on local cluster without Compose
- [ ] You can explain Service vs Deployment vs Pod in one minute each

---

## Phase 4 — Helm (Week 4)

**Goal:** templatize deploys; stop copy-pasting YAML.

### Charts to own

| Chart | Notes |
|-------|--------|
| `helm/api` | Your app — **write this yourself** |
| `helm/worker` | Your app |
| Postgres / Redis | **Use Bitnami or official charts**; study them, don’t rewrite |

**Why not chart everything:** rewriting Postgres Helm teaches little and burns time. Own *your* charts; consume mature ones for data stores.

### Learn

- `values.yaml`, templates, helpers, hooks
- `helm upgrade` / `rollback`
- values per environment (prep for Phase 13)

### Deliverables

- [ ] Working `helm install` for api (+ worker)
- [ ] values for local cluster
- [ ] Notes comparing your chart to a Bitnami chart structure

### Exit checklist

- [ ] Upgrade changes image tag cleanly
- [ ] Rollback restores previous revision

---

## Phase 5 — GitHub Actions CI (Week 5)

**Goal:** push → test → build → push image. **Deploy can wait for GitOps.**

### Pipeline (cost-aware)

```
PR / push
  → lint + unit tests
  → docker buildx (cache)
  → push to GHCR (on main only)
  → (optional) helm template / kubeconform
```

**Do not** auto-deploy with SSH/`kubectl apply` from Actions as the long-term path — that fights GitOps. If you add a temporary deploy job, delete it in Phase 6.

### Learn

- Actions, secrets/OIDC, buildx, layer cache
- Avoid wide matrix builds (cost + minutes)

### Deliverables

- [ ] Workflow file(s) under `.github/workflows/`
- [ ] Images on GHCR tagged by git SHA + `latest` on main
- [ ] Branch protection optional but good practice

### Cost

**$0** within free Actions minutes for a solo learner.

### Exit checklist

- [ ] Main branch produces a digest you can deploy by tag
- [ ] Secrets are not echoed in logs

---

## Phase 6 — Cheap cloud + GitOps (Argo CD) (Week 6)

**Goal:** first **paid** (or Always Free) environment; remove manual deploy as the source of truth.

### Why this week for money

You now have: app, Terraform modules, K8s YAML/Helm, CI images. Applying Terraform + installing k3s + Argo CD is the highest learning-per-dollar moment.

### Steps

1. `terraform apply` → VPS + firewall + DNS
2. Install **k3s** (cloud-init or script)
3. Install **Argo CD**
4. Point Argo at `kubernetes/` or Helm via Git
5. Sync app + dependencies
6. Confirm: git change → Argo sync → new pods (image from GHCR)

### Flow

```
git push → GitHub Actions → GHCR
                ↓
         GitOps repo/path update (image tag)
                ↓
            Argo CD sync
                ↓
             Cluster
```

### Learn

- GitOps, sync policies, drift detection, rollback via Git revert
- Pull secrets for private GHCR (imagePullSecrets)

### Cost

**~$5–12/mo** for the VPS (or $0 on Oracle Always Free if you accept quota pain).

### Deliverables

- [ ] Public (or Cloudflare-protected) URL hitting the API
- [ ] Argo Application(s) documented
- [ ] `terraform destroy` tested at least once (then recreate)

### Exit checklist

- [ ] You no longer deploy by hand as the happy path
- [ ] Drift: change a live Deployment and watch Argo report it

---

## Phase 7 — Observability (Week 7)

**Goal:** see latency, errors, logs — the ops feedback loop.

**Probably the highest career-value phase.** Keep the stack **right-sized for 4–8 GB RAM**.

### Install (recommended order)

1. **kube-prometheus-stack** (Prometheus + Grafana + Alertmanager)
2. **Loki** (+ Promtail or alloy) for logs
3. **OpenTelemetry** instrumentation in FastAPI/worker
4. **Tempo** only if memory allows — else defer traces to stretch

### Track

| Signal | Minimum bar |
|--------|-------------|
| Metrics | RPS, latency p95, error rate, pod CPU/mem |
| Logs | request id / trace id correlation |
| Traces | one request through API → worker (if Tempo enabled) |

### Cost tactics

- Single replicas, short retention (e.g. 3–7 days)
- Don’t install every Grafana plugin
- Scrape intervals 30s is fine for learning
- If the node OOMs: drop Tempo first, then shorten Loki retention

### Deliverables

- [ ] Grafana dashboards for API RED metrics
- [ ] One useful alert (e.g. high error rate) — even if it only notifies you via a webhook you mock
- [ ] Short doc: how to find a slow request

### Exit checklist

- [ ] You can diagnose a forced 500 using metrics → logs (→ traces)

---

## Phase 8 — Autoscaling (Week 8)

**Goal:** scale on CPU **and** on queue depth (the AI-worker pattern).

### Path

1. Metrics Server
2. **HPA** on API (CPU/memory)
3. **KEDA** ScaledObject on worker (Redis list length / RabbitMQ depth)
4. Stress test (`k6`, `hey`, or a simple script)

### Cost tactics

- Cap `maxReplicaCount` hard (e.g. 3–5) so a bad scaler can’t melt the VPS
- Single-node: you learn the *mechanism*; true multi-node capacity is optional later

### Deliverables

- [ ] HPA + KEDA configs in Git
- [ ] Load-test notes with before/after replica counts
- [ ] Screenshot or notes in `docs/`

### Exit checklist

- [ ] Workers scale up under queue load and scale down after idle

---

## Phase 9 — Secrets management (Week 9a)

**Goal:** stop relying on raw K8s Secrets committed to Git (even base64 is not encryption).

### Cost-ordered options

| Option | Cost | When to use |
|--------|------|-------------|
| **SOPS + age** or **Sealed Secrets** | Free | **Default for this plan** |
| External Secrets Operator + Cloudflare/GSM/etc. | Free–cheap | If you want cloud secret store sync |
| HashiCorp Vault | Heavy on RAM/ops | Stretch only |

### Store

- DB passwords, API tokens, LLM keys (if any)

### Learn

- Encryption at rest vs in Git
- Rotation story (manual is OK: document rotate → sync → rollout)

### Deliverables

- [ ] No plaintext secrets in Git
- [ ] Runbook: rotate DB password
- [ ] Argo still syncs cleanly with sealed/SOPS secrets

### Exit checklist

- [ ] Fresh clone + bootstrap instructions work without copying secrets from chat history

---

## Phase 10 — Networking & TLS (Week 9b)

**Goal:** production-shaped edge networking on a budget.

### Must-do

- Ingress (NGINX or Traefik — k3s often ships Traefik; pick one and standardize)
- **cert-manager** + Let’s Encrypt (or Cloudflare origin certs)
- Cloudflare DNS + proxy (free)
- Basic rate limiting at Ingress or Cloudflare

### Optional (only if time/RAM)

- **Linkerd** (lighter) for mTLS demo
- Avoid **Istio** on a 4 GB node

### Learn

- DNS → LB/IP → Ingress → Service → Pod
- TLS termination, HTTP→HTTPS redirect
- NetworkPolicies (simple deny-egress / allow DNS+DB)

### Deliverables

- [ ] HTTPS URL
- [ ] Documented Cloudflare + cert-manager setup
- [ ] Optional: one NetworkPolicy example

### Exit checklist

- [ ] HTTP fails closed or redirects; cert auto-renew path understood

---

## Phase 11 — Progressive delivery (Week 10)

**Goal:** stop “deploy 100% and pray.”

### Implement

- **Argo Rollouts**: canary (e.g. 10% → 50% → 100%)
- Analysis via metrics (Prometheus) if possible; otherwise manual promote/pause is still educational
- Document rollback

### Skip for cost/complexity

- Flagger + mesh-heavy setups until Linkerd/Istio exists
- True blue/green needing double capacity on a tiny node — prefer canary with low extra replicas

### Deliverables

- [ ] Rollout manifest for API
- [ ] Demo script: ship bad version → auto/manual abort → stable

### Exit checklist

- [ ] You can explain canary vs blue/green and when each needs more capacity

---

## Phase 12 — Disaster recovery (Week 11a)

**Goal:** the portfolio differentiator — most tutorials stop before restore drills.

### Implement

| Data | Backup approach (cheap) |
|------|-------------------------|
| PostgreSQL | CronJob + `pg_dump` → MinIO (or B2/R2 off-box) |
| MinIO | Versioning / bucket replication to cheap remote if possible |
| Cluster | Document “recreate from Terraform + Git + backup” |

### Must test

1. Take backup  
2. **Delete** the database (in a controlled window)  
3. Restore  
4. Write the timeline in a runbook  

### Cost tactics

- Off-box backup to Backblaze B2 / Cloudflare R2 free tiers beats “backup on same disk only”
- Retention: keep last N dumps, not forever

### Deliverables

- [ ] Automated backup Job/CronJob in Git
- [ ] `docs/runbooks/restore-postgres.md` with actual commands you ran
- [ ] Evidence: restore succeeded (notes + timestamps)

### Exit checklist

- [ ] You have performed a restore at least once — not only a backup

---

## Phase 13 — Multi-environment (Week 11b)

**Goal:** promotion path without three clusters.

### Cheap model

```
one cluster
  namespace: dev
  namespace: staging
  namespace: prod   # or just dev + prod
```

| Concern | Approach |
|---------|----------|
| Helm values | `values-dev.yaml` / `values-prod.yaml` |
| Terraform | one hobby env; optional second micro VPS only if needed |
| Secrets | separate SOPS keys / sealed secrets per env |
| Promotion | merge to `main` → prod; feature branch → dev Application |

### Avoid

- Three always-on VPSes for “prod parity”
- Full Terraform workspaces explosion

### Deliverables

- [ ] Overlays or value files for ≥2 envs
- [ ] Argo Apps (or ApplicationSet) per env
- [ ] Short doc: how a change goes from PR → dev → prod

### Exit checklist

- [ ] Prod image tag is promoted deliberately, not “whatever was on my laptop”

---

## Phase 14 — Production hardening (Week 12a)

**Goal:** make the cluster look like something a platform team would review.

### Checklist (implement what fits RAM)

- [ ] Liveness / readiness / startup probes
- [ ] Resources requests **and** limits
- [ ] PodDisruptionBudgets (even on 1 node — know the concept)
- [ ] SecurityContext (non-root, read-only root FS where possible)
- [ ] NetworkPolicies (default deny + allowlist)
- [ ] RBAC least privilege for CI/Argo
- [ ] Image scanning in CI (Trivy — free)
- [ ] Dependency scanning (Dependabot/Renovate)

### Cost

Mostly **time**, not money. Scanning runs in Actions free tier.

### Deliverables

- [ ] Hardening applied to API/worker charts
- [ ] CI fails on critical image CVEs (start with HIGH+CRITICAL)

---

## Phase 15 — Documentation & portfolio (Week 12b)

**Goal:** turn the lab into a story you can defend in interviews.

### Create

- Architecture diagram (one overview + one sequence for a request)
- Deploy walkthrough (GitOps path)
- Scaling, monitoring, networking, recovery runbooks
- Terraform + Kubernetes decision log
- **Lessons learned** (failures are gold)
- Cost report: what you spent per month and what you’d cut

### Portfolio sentence (target)

> I designed, provisioned, deployed, secured, monitored, and operated a cloud-native AI platform on Kubernetes using Terraform, Helm, GitOps, CI/CD, observability, autoscaling, and tested disaster recovery — optimized to run on a single low-cost VPS.

---

## Stretch goals (after core plan — cost ranked)

| Stretch | Extra cost | Prerequisite |
|---------|------------|--------------|
| Cost dashboard (CPU/mem + token usage) | ~$0 | Phase 7 |
| AI gateway multi-provider routing | API $ | Stable API |
| Event-driven (RabbitMQ/NATS) | RAM | Phase 8 |
| Second small node (HA practice) | +VPS $ | Phase 14 |
| Vault | RAM/ops | Phase 9 |
| Linkerd mTLS | RAM | Phase 10 |
| Knative / serverless workers | Complexity | Strong K8s |
| GPU node + local LLM | **$$$** | Only with hard budget |
| Multi-cluster | **$$** | Everything else solid |
| Multi-cloud | **$$$** | Career specialization, not week 13 |

---

## Learning resources (aligned to phases)

| Area | Resource |
|------|----------|
| Terraform | HashiCorp Learn; Terraform Associate path |
| Kubernetes | KodeKloud / TechWorld with Nana; “Hard Way” optional later |
| Helm | Official docs; read Bitnami charts as examples |
| GitOps | Argo CD docs; Argo Rollouts docs |
| Observability | Prometheus / Grafana / OpenTelemetry docs |
| Cost ops | Your own `docs/cost-budget.md` + provider billing alerts |

---

## Success criteria

You are “done” with the core plan when you can honestly check these:

- [ ] Docker + Compose baseline
- [ ] Terraform create/destroy of the lab VPS
- [ ] Kubernetes deploy via kubectl **and** Helm
- [ ] GitHub Actions → GHCR
- [ ] Argo CD GitOps sync + drift awareness
- [ ] Grafana dashboards for RED metrics + logs in Loki
- [ ] HPA + KEDA demonstrated
- [ ] Secrets not plaintext in Git
- [ ] HTTPS via cert-manager / Cloudflare
- [ ] Canary with Argo Rollouts
- [ ] Backup **and restore** drill documented
- [ ] ≥2 environments via namespaces/overlays
- [ ] Hardening + scanning in CI
- [ ] Portfolio-quality docs and diagrams

---

## Suggested weekly habit

| Day | Activity |
|-----|----------|
| 1–2 | Build / break |
| 3 | Write lessons-learned |
| 4 | Cost check (is the VPS still needed?) |
| 5 | Demo to yourself: explain the phase out loud |

---

## Immediate next step

**Phase 0 + start of Phase 1:**

1. Confirm monthly budget cap and VPS provider preference.  
2. Scaffold the repo folders.  
3. Implement the thinnest FastAPI service with `/health`, `/ready`, `/metrics`, Compose, and a stubbed “summarize” endpoint.

When you are ready, say what budget tier you want (**$0 Lab** vs **Hobby Cloud**) and which AI toy feature you prefer — then we implement Phase 1 in tutor mode (you write the key logic; I review).
