# Hobby stack — start to finish

One map of everything that runs on the Hetzner k3s lab: what to install, which namespace, which ports to forward, and how pieces connect. Prefer this over hunting across scattered notes.

Related: [gitops/README.md](../../gitops/README.md) · [monitoring/README.md](../../monitoring/README.md) · [helm.md](helm.md) · root [README.md](../../README.md)

---

## Mental model

```
Internet (you + port-forward)
        │
   Hetzner VPS (cnai-hobby) — k3s
        │
 ┌──────┴──────────────────────────────────────────┐
 │  argocd        │  ai-platform   │  monitoring   │
 │  Argo CD       │  API + PG+Redis│  Prom/Graf/…  │
 └────────────────┴────────────────┴───────────────┘

GitHub main → Actions → GHCR image
           └→ Argo syncs helm/api (+ values-hobby.yaml)
```

| Layer | Job |
|-------|-----|
| Terraform | Creates VPS + firewall (+ optional DNS later) |
| k3s | Kubernetes on that one box |
| Argo CD | GitOps: Git → cluster for the API chart |
| Helm (manual) | Monitoring charts + Bitnami Postgres/Redis (until GitOps’d) |
| GHCR | Immutable app images `sha-<short>` |

---

## Namespaces

| Namespace | What lives there |
|-----------|------------------|
| `kube-system` | k3s system (Traefik, etc.) |
| `argocd` | Argo CD |
| `ai-platform` | API, Postgres, Redis, `ghcr-pull` secret, ServiceMonitor |
| `monitoring` | kube-prometheus-stack, Loki, Promtail, PrometheusRules |

---

## Charts & how they got there

| Release / chart | Namespace | How installed | Values / source |
|-----------------|-----------|---------------|-----------------|
| `api` (`helm/api`) | `ai-platform` | **Argo CD** Application | `gitops/applications/api.yaml` + `values-hobby.yaml` |
| `postgres` (Bitnami postgresql) | `ai-platform` | Helm (manual) | auth user/pass/db `app` |
| `redis` (Bitnami redis) | `ai-platform` | Helm (manual) | standalone, auth off (lab) |
| `mon` (kube-prometheus-stack) | `monitoring` | Helm (manual) | `monitoring/kube-prometheus-stack-values.yaml` |
| `loki` (grafana/loki) | `monitoring` | Helm (manual) | `monitoring/loki-values.yaml` |
| `promtail` (grafana/promtail) | `monitoring` | Helm (manual) | `monitoring/promtail-values.yaml` |
| Argo CD | `argocd` | upstream install YAML | [gitops/README.md](../../gitops/README.md) |

In-cluster DNS the API must use (Bitnami):

| Dependency | Service host | URL shape in values |
|------------|--------------|---------------------|
| Postgres | `postgres-postgresql` | `postgresql+psycopg://app:app@postgres-postgresql:5432/app` |
| Redis | `redis-master` | `redis://redis-master:6379/0` |

Wrong host → `/ready` 503 even when pods look fine.

---

## Port-forward cheat sheet

Run from a laptop with `KUBECONFIG` pointing at hobby (`~/.kube/hobby.yaml` or `./scripts/fetch-hobby-kubeconfig.sh`). Use **separate terminals** for each forward.

| Service | Local URL | kubectl command |
|---------|-----------|-----------------|
| **API** | http://localhost:8000 | `kubectl -n ai-platform port-forward svc/api 8000:8000` |
| **Argo CD** | https://localhost:8080 | `kubectl -n argocd port-forward svc/argocd-server 8080:443` |
| **Grafana** | http://localhost:3000 | `kubectl -n monitoring port-forward svc/mon-grafana 3000:80` |
| **Prometheus** | http://localhost:9090 | `kubectl -n monitoring port-forward svc/mon-kube-prometheus-stac-prometheus 9090:9090` |
| **Alertmanager** | http://localhost:9093 | `kubectl -n monitoring port-forward svc/mon-kube-prometheus-stac-alertmanager 9093:9093` |

Confirm truncated Service names:

```bash
kubectl -n monitoring get svc
kubectl -n argocd get svc
kubectl -n ai-platform get svc
```

### Passwords / logins

```bash
# Argo CD admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo

# Grafana admin
kubectl -n monitoring get secret mon-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Argo user: `admin`. Grafana user: `admin`.

Postgres/Redis lab credentials are in `values-hobby.yaml` / Bitnami install flags (`app`/`app`) — Phase 9 will seal them.

---

## Cold start (empty VPS → working platform)

Do once after `terraform apply` (or after destroy/recreate).

### 1. Cluster access

```bash
cd infrastructure/terraform/environments/hobby
# terraform.tfvars: ssh key + admin_cidrs = ["YOUR.IP/32"]
export HCLOUD_TOKEN=...
terraform init && terraform apply

# repo root
./scripts/fetch-hobby-kubeconfig.sh
export KUBECONFIG=~/.kube/hobby.yaml
kubectl get nodes
```

### 2. Argo CD

Follow [gitops/README.md](../../gitops/README.md): install Argo, create `ghcr-pull`, `kubectl apply -f gitops/applications/api.yaml`, Sync.

### 3. Postgres + Redis (if not already in cluster)

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install postgres bitnami/postgresql -n ai-platform \
  --create-namespace \
  --set auth.username=app \
  --set auth.password=app \
  --set auth.database=app \
  --set primary.persistence.size=1Gi

helm upgrade --install redis bitnami/redis -n ai-platform \
  --set architecture=standalone \
  --set auth.enabled=false \
  --set master.persistence.size=1Gi

kubectl -n ai-platform get pods,svc
```

Ensure `values-hobby.yaml` uses `postgres-postgresql` and `redis-master`.

### 4. API via Argo

Pin `image.tag` to a CI `sha-...` that includes the code you want → commit/push → Sync.

```bash
kubectl -n ai-platform get pods
kubectl -n ai-platform port-forward svc/api 8000:8000
curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/ready
```

### 5. Observability

Install order and drill: [monitoring/README.md](../../monitoring/README.md).

```bash
# CRDs first, then Sync api (ServiceMonitor), then Loki + Promtail + alerts
helm upgrade --install mon prometheus-community/kube-prometheus-stack \
  -n monitoring -f monitoring/kube-prometheus-stack-values.yaml --wait --timeout 15m
# … Sync Argo …
helm upgrade --install loki grafana/loki -n monitoring -f monitoring/loki-values.yaml --wait
helm upgrade --install promtail grafana/promtail -n monitoring -f monitoring/promtail-values.yaml --wait
kubectl apply -f monitoring/alerts/api-rules.yaml
```

---

## Day-2 loop (change already deployed)

1. Edit app / Helm values / monitoring values.
2. For **API**: merge to `main` → CI pushes GHCR → bump `values-hobby.yaml` `image.tag` → push → Argo Sync.
3. For **monitoring / Bitnami**: `helm upgrade --install ... -f ...` from the laptop (not Argo yet).
4. Verify with port-forwards + curls / Grafana.

---

## Quick health checks

```bash
kubectl get nodes
kubectl -n argocd get application api
kubectl -n ai-platform get pods,svc,servicemonitor
kubectl -n monitoring get pods

# API still on old image? (no http_requests_total, /debug/boom 404)
kubectl -n ai-platform get deploy api -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```

---

## Common failures

| Symptom | Fix |
|---------|-----|
| Argo SyncFailed: ServiceMonitor CRD missing | Install kube-prometheus-stack first, then Sync |
| `/debug/boom` 404 / no RED metrics | Image tag predates Phase 7 code; pin newer SHA + Sync |
| `/ready` 503 | Wrong Postgres/Redis Service DNS in values |
| `ImagePullBackOff` | `ghcr-pull` PAT needs `read:packages` |
| SSH / kubectl timeout | Public IP changed → update `admin_cidrs` + `terraform apply` |
| Promtail can’t push | Client URL ≠ actual Loki Service (`kubectl -n monitoring get svc`) |
| Node OOM | Drop Tempo; shorten Loki/Prometheus retention; see monitoring values |

---

## Cost

Only the VPS bills (~$5–12/mo). Power-off still charges; `terraform destroy` stops billing. See root README pause/resume and [docs/cost-budget.md](../cost-budget.md).
