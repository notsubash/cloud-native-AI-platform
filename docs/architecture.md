# Architecture

Cost-bounded learning lab: one Hetzner VPS running k3s, GitOps for the API, right-sized observability. AI stays thin so infra stays the focus. See [PLAN.md](../PLAN.md) and [docs/cost-budget.md](cost-budget.md).

```
                         You (laptop)
                    kubectl port-forward
                              │
                      Hetzner VPS + k3s
                              │
         ┌────────────────────┼────────────────────┐
         │                    │                    │
      argocd            ai-platform            monitoring
      Argo CD           API (FastAPI)          Prometheus
                        Postgres (Bitnami)     Grafana
                        Redis (Bitnami)        Alertmanager
                        ServiceMonitor         Loki + Promtail
         │
GitHub main ──► GHCR (sha-*) ──► Argo syncs helm/api
```

| Path | Role |
|------|------|
| Client → API → Postgres / Redis | App data path |
| API `/metrics` → ServiceMonitor → Prometheus → Grafana | RED metrics |
| API stdout → Promtail → Loki → Grafana | Logs + `request_id` correlation |
| PrometheusRule → Alertmanager | e.g. high 5xx rate |

Local alternatives (not both at once with cloud): Docker Compose, or laptop Helm — [docs/runbooks/helm.md](runbooks/helm.md).

Full install map, charts, and port-forwards: [docs/runbooks/hobby-stack.md](runbooks/hobby-stack.md).
