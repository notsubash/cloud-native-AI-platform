# Local Kubernetes — start, stop, debug

Stack: Docker Desktop Kubernetes + `kubernetes/base` (api, postgres, redis).  
Context: `docker-desktop`. Namespace: `ai-platform`.

Prefer **kubeadm** in Docker Desktop for Phase 3 (local images work with `imagePullPolicy: Never`).  
Docker Desktop **kind** does not show up in `kind get clusters` / `kind load` — host images are not on the node until you switch to kubeadm or import manually.

Do not run `make up` (Compose) at the same time as this stack.

---

## Start (tomorrow / cold start)

1. Start **Docker Desktop** and wait until Kubernetes shows running.
2. Point kubectl at it:

```bash
kubectl config use-context docker-desktop
kubectl get nodes
```

3. Build the API image (tag must match `kubernetes/base/api.yaml`):

```bash
docker build -t cloud-native-ai-api:local ./apps/api
```

4. Apply manifests (safe to re-run):

```bash
kubectl apply -k kubernetes/base
kubectl get pods -n ai-platform -w
```

Wait until `api`, `postgres`, and `redis` are `1/1 Running`.

5. Port-forward (leave this terminal open):

```bash
kubectl -n ai-platform port-forward svc/api 8000:8000
```

6. Smoke test (other terminal):

```bash
curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/ready
curl -s -X POST http://127.0.0.1:8000/v1/summarize \
  -H 'content-type: application/json' \
  -d '{"text":"Kubernetes runs pods behind services."}'
```

After changing API code: rebuild the image, then `kubectl -n ai-platform rollout restart deploy/api`.

---

## Tear down

**Apps only** (keep the cluster for tomorrow):

```bash
# Ctrl+C the port-forward first
kubectl delete -k kubernetes/base
```

**Full stop** (free RAM overnight):

```bash
kubectl delete -k kubernetes/base
# Docker Desktop → Kubernetes → Stop
# or quit Docker Desktop entirely
```

Postgres PVC is deleted with the manifests above. Next `apply` starts with an empty DB — fine for this lab.

---

## App won’t start — debug path

1. `kubectl get pods -n ai-platform`
   - Pending → describe (scheduling / PVC)
   - `ErrImageNeverPull` / ImagePullBackOff → image missing on the node (rebuild `cloud-native-ai-api:local`; if on Docker Desktop kind, switch to kubeadm or import into the node)
   - CrashLoopBackOff → logs + describe Events
   - Running but 0/1 Ready → readiness failing (`/ready` → Postgres/Redis)

2. `kubectl describe pod <pod> -n ai-platform` → read Events bottom-up

3. `kubectl logs <pod> -n ai-platform` and `--previous` if it restarted

4. Check DNS/env:
   - `DATABASE_URL` host must be `postgres`, not localhost
   - `REDIS_URL` host must be `redis`

5. Dependency check:

```bash
kubectl exec -it deploy/api -n ai-platform -- python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/ready').read())"
```

6. Port-forward smoke test (see Start step 5–6).
