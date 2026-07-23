# Observability (Phase 7)

Right-sized stack for the hobby VPS: **Prometheus + Grafana + Alertmanager**, **Loki**, **Promtail**. Tempo / OpenTelemetry are optional if RAM allows.

```
API /metrics  →  ServiceMonitor  →  Prometheus  →  Grafana (RED)
API stdout    →  Promtail        →  Loki        →  Grafana Explore
PrometheusRule → Alertmanager (high 5xx rate)
```

Values live in this folder. Install with Helm from the laptop (`KUBECONFIG` → hobby cluster). App scrape config is the `ServiceMonitor` in `helm/api` (needs Prometheus Operator CRDs from kube-prometheus-stack **before** Argo can sync it).

## Install order (do not reverse)

1. **kube-prometheus-stack** (creates `ServiceMonitor` / `PrometheusRule` CRDs)
2. Re-sync Argo `api` Application
3. Confirm API image has RED metrics + `/debug/boom`
4. **Loki**
5. **Promtail** (points at Loki push URL)
6. Apply `alerts/api-rules.yaml`
7. Import / build RED dashboard → save JSON here

### 1) Prometheus stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install mon prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f monitoring/kube-prometheus-stack-values.yaml \
  --wait --timeout 15m

kubectl get crd servicemonitors.monitoring.coreos.com
kubectl -n monitoring get pods
```

Then Sync Argo `api` so `ServiceMonitor` applies:

```bash
kubectl -n ai-platform get servicemonitor
```

### 2) Loki

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

helm upgrade --install loki grafana/loki \
  -n monitoring \
  -f monitoring/loki-values.yaml \
  --wait --timeout 10m

kubectl -n monitoring get pods,svc | grep loki
```

### 3) Promtail

Confirm Loki Service name, then set `config.clients[0].url` in `promtail-values.yaml`:

- Gateway (if present): `http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push`
- Direct: `http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push`

```bash
helm upgrade --install promtail grafana/promtail \
  -n monitoring \
  -f monitoring/promtail-values.yaml \
  --wait

kubectl -n monitoring logs -l app.kubernetes.io/name=promtail --tail=40
```

### 4) Alert rule

```bash
kubectl apply -f monitoring/alerts/api-rules.yaml
kubectl -n monitoring get prometheusrule
```

## Port-forwards (local UIs)

| What | Command | Open |
|------|---------|------|
| Grafana | `kubectl -n monitoring port-forward svc/mon-grafana 3000:80` | http://localhost:3000 |
| Prometheus | `kubectl -n monitoring port-forward svc/mon-kube-prometheus-stac-prometheus 9090:9090` | http://localhost:9090 |
| Alertmanager | `kubectl -n monitoring port-forward svc/mon-kube-prometheus-stac-alertmanager 9093:9093` | http://localhost:9093 |
| API | `kubectl -n ai-platform port-forward svc/api 8000:8000` | http://localhost:8000 |

Service names can truncate; confirm with:

```bash
kubectl -n monitoring get svc
```

Grafana admin password:

```bash
kubectl -n monitoring get secret mon-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

## Grafana: Loki datasource

**Connections → Data sources → Add Loki**

URL (pick what matches `kubectl get svc`):

- `http://loki.monitoring.svc.cluster.local:3100`
- or `http://loki-gateway.monitoring.svc.cluster.local`

Save & test.

## How to find a failed / slow request

1. **Metrics** — Grafana Explore (Prometheus) or RED dashboard: error rate or p95 spikes.
2. Note the time window.
3. **Logs** — Explore (Loki):

```logql
{namespace="ai-platform"} |= "status=500"
{namespace="ai-platform"} |= "request_id=phase7-demo"
```

4. Copy `request_id=...` from the log line; filter on that id for the full story.
5. Optional: Prometheus `/targets` — API ServiceMonitor must be **UP**.

### Drill

```bash
kubectl -n ai-platform port-forward svc/api 8000:8000
# other terminal:
curl -si -H "X-Request-ID: phase7-demo" http://127.0.0.1:8000/debug/boom

for i in $(seq 1 40); do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -H "X-Request-ID: drill-$i" \
    http://127.0.0.1:8000/debug/boom
  sleep 1
done
```

Expect: `/metrics` shows `http_requests_total` / histograms; Loki shows `phase7-demo`; after ~2m sustained 5xx, alert `ApiHighErrorRate` fires.

If `/debug/boom` is **404** or metrics lack `http_requests_total`, the running image is old — pin a newer `sha-...` in `helm/api/values-hobby.yaml`, push, Argo Sync, `rollout restart deploy/api`.

## Step F — RED dashboard

### Build in UI (once)

1. Grafana → **Dashboards → New → New dashboard**.
2. Add three panels (Prometheus datasource):

**Rate (R)**

```promql
sum(rate(http_requests_total{path="/v1/summarize"}[5m]))
```

**Errors (E)** — 5xx ratio

```promql
sum(rate(http_requests_total{status=~"5.."}[5m]))
/
clamp_min(sum(rate(http_requests_total[5m])), 0.001)
```

**Duration (D)** — p95

```promql
histogram_quantile(
  0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket{path="/v1/summarize"}[5m]))
)
```

3. Title the dashboard **API RED**.
4. **Share → Export → Save to file** → replace `monitoring/dashboards/api-red.json` (or keep the committed starter JSON and tweak).

### Import committed JSON

**Dashboards → New → Import** → upload `monitoring/dashboards/api-red.json` → select Prometheus datasource → Import.

## Useful PromQL

```promql
up{namespace="ai-platform"}
summarize_requests_total
http_requests_total
```

## Cost / RAM

Single replicas, short retention (see values files). If the node OOMs: drop Tempo (if any) → shorten Loki retention → lower Prometheus memory. Never starve the API for the monitoring stack.

Full stack map (all namespaces, charts, ports): [docs/runbooks/hobby-stack.md](../docs/runbooks/hobby-stack.md).
