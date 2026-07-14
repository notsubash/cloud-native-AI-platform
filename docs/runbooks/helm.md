# Helm — start, upgrade, rollback, which stack to run

Namespace: `ai-platform`. Context: `docker-desktop` (kubeadm).  
Preferred app path after Phase 4: **Bitnami Postgres + Bitnami Redis + `helm/api`**.

---

## Which stack am I running?

Only **one** of these at a time on the laptop:

| Stack | When | How |
|-------|------|-----|
| **Compose** | Phase 1 / quick API work without K8s | `make up` → `localhost:8000` |
| **Raw K8s** (`kubernetes/base`) | Phase 3 learning (Deployments by hand) | `kubectl apply -k kubernetes/base` |
| **Helm + Bitnami** | Phase 4+ (preferred now) | Bitnami charts + `helm upgrade --install api ...` |

Rules:

- Do **not** run `make up` while anything is in the cluster.
- Do **not** leave Phase 3 raw `api` / `postgres` / `redis` Deployments next to Helm/Bitnami — delete the old objects first (see below).
- Terraform (`infrastructure/terraform`) is **not** part of daily local bring-up; it is for the future VPS. Skip it until you need cloud.

Layer mental model:

```text
Terraform (later)     → creates the machine / DNS
Kubernetes            → runs workloads on a cluster
Helm                  → packages + versions your K8s YAML (releases/revisions)
Bitnami charts        → mature Postgres/Redis instead of hand-rolled YAML
Compose               → laptop-only alternative to the cluster (not both)
```

Cold-start K8s cluster itself: [app-wont-start.md](app-wont-start.md) (Docker Desktop + image build). This runbook assumes the cluster is up.

---

## Start (Helm path, cold or tomorrow)

### 1. Cluster + image

```bash
kubectl config use-context docker-desktop
kubectl get nodes

docker build -t cloud-native-ai-api:local ./apps/api
```

### 2. Namespace (once)

```bash
kubectl create namespace ai-platform --dry-run=client -o yaml | kubectl apply -f -
```

### 3. Bitnami Postgres (if not already installed)

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install postgres bitnami/postgresql -n ai-platform \
  --set auth.username=app \
  --set auth.password=app \
  --set auth.database=app \
  --set primary.persistence.size=1Gi

kubectl -n ai-platform get pods,svc -l app.kubernetes.io/name=postgresql
```

Service host for the API: **`postgres-postgresql`**.

### 4. Bitnami Redis (if not already installed)

```bash
helm upgrade --install redis bitnami/redis -n ai-platform \
  --set architecture=standalone \
  --set auth.enabled=false \
  --set master.persistence.size=1Gi

kubectl -n ai-platform get svc | grep redis
```

Service host for the API: usually **`redis-master`** (must match `values-local.yaml`).

### 5. Remove Phase 3 leftovers (only if still present)

```bash
# Old hand-rolled objects — NOT postgres-postgresql / redis-master
kubectl -n ai-platform delete deploy api postgres redis --ignore-not-found
kubectl -n ai-platform delete svc api postgres redis --ignore-not-found
kubectl -n ai-platform delete pvc postgres-data --ignore-not-found
kubectl -n ai-platform delete configmap api-config --ignore-not-found
```

### 6. Install / upgrade the API chart

```bash
helm lint ./helm/api
helm template api ./helm/api -n ai-platform -f ./helm/api/values-local.yaml

helm upgrade --install api ./helm/api -n ai-platform -f ./helm/api/values-local.yaml

kubectl -n ai-platform get pods,svc
```

### 7. Smoke test

```bash
kubectl -n ai-platform port-forward svc/api 8000:8000
```

Other terminal:

```bash
curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/ready
curl -s -X POST http://127.0.0.1:8000/v1/summarize \
  -H 'content-type: application/json' \
  -d '{"text":"Helm tracks releases and revisions."}'
```

After API code changes: rebuild `cloud-native-ai-api:local`, then either `helm upgrade --install ...` again or `kubectl -n ai-platform rollout restart deploy/api`.

---

## Upgrade image tag (revision mechanics)

```bash
docker tag cloud-native-ai-api:local cloud-native-ai-api:local-v2

helm upgrade api ./helm/api -n ai-platform -f ./helm/api/values-local.yaml \
  --set image.tag=local-v2

helm history api -n ai-platform
kubectl -n ai-platform get pods -l app.kubernetes.io/instance=api \
  -o jsonpath='{.items[*].spec.containers[*].image}{"\n"}'
```

Expect `cloud-native-ai-api:local-v2`.

---

## Rollback

```bash
helm rollback api 1 -n ai-platform
helm history api -n ai-platform
kubectl -n ai-platform get pods -l app.kubernetes.io/instance=api \
  -o jsonpath='{.items[*].spec.containers[*].image}{"\n"}'
```

Rollback creates a **new** revision (e.g. rev 3 = “Rollback to 1”); it does not delete history. Image should return to `cloud-native-ai-api:local` if rev 1 used that tag.

---

## Tear down

**API release only:**

```bash
helm uninstall api -n ai-platform
```

**Data stores too:**

```bash
helm uninstall redis postgres -n ai-platform
# PVCs may remain — delete if you want a clean DB next time:
kubectl -n ai-platform get pvc
```

**Full stop overnight:** uninstall releases (or delete the namespace), then stop Kubernetes / quit Docker Desktop. See [app-wont-start.md](app-wont-start.md).

---

## Debug path

1. `helm status api -n ai-platform` / `helm history api -n ai-platform`
2. `kubectl -n ai-platform get pods,svc`
3. `/ready` failing → check `DATABASE_URL` / `REDIS_URL` hosts match `kubectl get svc` (`postgres-postgresql`, `redis-master`)
4. ImagePull / Never → rebuild `cloud-native-ai-api:<tag>` on the Docker Desktop node
5. Two APIs or weird DNS → leftovers from `kubernetes/base` still present
6. Pod crash → `kubectl -n ai-platform logs -l app.kubernetes.io/instance=api --tail=50`

More pod-level debugging: [app-wont-start.md](app-wont-start.md).

Chart vs Bitnami structure notes: [helm/NOTES-bitnami-compare.md](../../helm/NOTES-bitnami-compare.md).
