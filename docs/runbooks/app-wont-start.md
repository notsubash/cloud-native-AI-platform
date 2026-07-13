# App won’t start — debug path

1. `kubectl get pods -n ai-platform`
   - Pending → describe (scheduling / PVC)
   - ImagePullBackOff → image not loaded into kind/k3d
   - CrashLoopBackOff → logs + describe Events
   - Running but 0/1 Ready → readiness failing (/ready → Postgres/Redis)

2. `kubectl describe pod <pod> -n ai-platform` → read Events bottom-up

3. `kubectl logs <pod> -n ai-platform` and `--previous` if it restarted

4. Check DNS/env:
   - DATABASE_URL host must be `postgres`, not localhost
   - REDIS_URL host must be `redis`

5. Dependency check:
   `kubectl exec -it deploy/api -n ai-platform -- python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/ready').read())"`

6. Port-forward smoke test:
   `kubectl -n ai-platform port-forward svc/api 8000:8000`
   then `curl localhost:8000/health`