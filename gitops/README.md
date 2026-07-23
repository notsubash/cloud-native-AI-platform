# GitOps (Argo CD)

Desired state for the hobby cluster lives in Git. Argo CD watches this repo, renders the Helm chart, and applies it into `ai-platform`. You do not `helm upgrade` from your laptop for cloud deploys.

```
GitHub (branch in Application) → Argo CD → Helm (helm/api + values-hobby.yaml) → k3s
```

## Layout

| Path | Role |
|------|------|
| `gitops/applications/api.yaml` | Argo `Application` CR — source repo/path, destination namespace, sync policy |
| `helm/api/` | Chart Argo renders |
| `helm/api/values-hobby.yaml` | Cloud values: GHCR image, `IfNotPresent`, `imagePullSecrets: ghcr-pull` |

`root-app.yaml` is reserved for an optional app-of-apps bootstrap later; the working entry point today is `applications/api.yaml`.

## Prerequisites (cluster already up)

- Hobby VPS with k3s (Terraform + cloud-init; API cert includes public IP via `--tls-san`)
- Firewall allows your IP on **22** and **6443** (`admin_cidrs` in `terraform.tfvars`)
- Laptop kubeconfig from `./scripts/fetch-hobby-kubeconfig.sh` → `export KUBECONFIG=~/.kube/hobby.yaml`
- Argo CD installed in namespace `argocd`
- Namespace `ai-platform` and docker-registry secret `ghcr-pull` (GitHub PAT with `read:packages` — not an image tag)

## Bootstrap Argo CD (once per cluster)

```bash
# From repo root, after terraform apply:
./scripts/fetch-hobby-kubeconfig.sh
export KUBECONFIG=~/.kube/hobby.yaml

kubectl create namespace argocd
kubectl apply --server-side -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# If objects already exist and conflict:
# kubectl apply --server-side --force-conflicts -n argocd -f <same URL>

kubectl -n argocd get pods   # wait until Running
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo

kubectl -n argocd port-forward svc/argocd-server 8080:443
# UI: https://localhost:8080  (user: admin)
```

Use **server-side** apply: client-side `kubectl apply` can fail on large Argo CRDs (annotation size limit).

## Register the Application

Commit and **push** the chart path and values Argo should see. Argo clones GitHub — uncommitted or local-only branches are invisible.

```bash
# Secret once per namespace (PAT, not an image digest)
kubectl create namespace ai-platform   # if missing
kubectl -n ai-platform create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=<github-user> \
  --docker-password='<PAT with read:packages>' \
  --docker-email=<email>

kubectl apply -f gitops/applications/api.yaml
kubectl -n argocd get application api
```

Sync is **manual** by default (safer while learning). In the UI: open `api` → **SYNC**, or:

```bash
# after installing the argocd CLI, or use the UI Sync button
argocd app sync api
```

Automated sync / self-heal can be enabled later in `api.yaml` (`syncPolicy.automated`).

## Day-to-day loop

1. Change chart or `values-hobby.yaml` (prefer pinning `image.tag` to `sha-<short>` from CI).
2. Commit + push to the revision in `api.yaml` (`targetRevision`).
3. Refresh / Sync in Argo.
4. Check: `kubectl -n ai-platform get pods` and port-forward `svc/api` if needed.

## Common failures

| Symptom | Likely cause |
|---------|----------------|
| `unable to resolve '<branch>' to a commit SHA` | Branch not pushed to GitHub |
| `values-hobby.yaml: no such file` | File not on the tracked revision / not committed |
| Sync OK but `ImagePullBackOff` | Bad `ghcr-pull` secret (need PAT with `read:packages`) |
| Application Healthy but empty namespace | Manual sync not run yet |
| SSH to VPS hangs / kubectl :6443 times out | Your public IP changed; update `admin_cidrs` in `terraform.tfvars` + `terraform apply` |
| Host key verification failed after recreate | Normal after destroy/recreate; `./scripts/fetch-hobby-kubeconfig.sh` clears the old key |

## Cost note

Argo and k3s are free. The Hetzner VPS is the bill. Power-off still charges; `terraform destroy` stops billing. See the pause/resume section in the root [README.md](../README.md).
