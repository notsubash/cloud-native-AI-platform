#!/usr/bin/env bash
# =============================================================================
# After terraform apply: pull k3s kubeconfig and point it at the VPS public IP.
# Usage (from repo root):
#   ./scripts/fetch-hobby-kubeconfig.sh
#
# Requires: terraform state in hobby env, SSH key that matches the server.
# Windows tip: if ssh-keygen -R fails with "Permission denied", we rewrite
# known_hosts with grep instead.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TF_DIR="$ROOT/infrastructure/terraform/environments/hobby"
KUBE_OUT="${KUBECONFIG_OUT:-$HOME/.kube/hobby.yaml}"

IP="$(terraform -chdir="$TF_DIR" output -raw public_ip)"
echo "VPS IP: $IP"

# Drop stale host key (common after destroy/recreate on same IP)
KNOWN_HOSTS="${HOME}/.ssh/known_hosts"
if [[ -f "$KNOWN_HOSTS" ]]; then
  if grep -q "$IP" "$KNOWN_HOSTS" 2>/dev/null; then
    grep -v "$IP" "$KNOWN_HOSTS" > "${KNOWN_HOSTS}.tmp" && mv "${KNOWN_HOSTS}.tmp" "$KNOWN_HOSTS"
    echo "Removed old known_hosts entry for $IP"
  fi
fi

mkdir -p "$(dirname "$KUBE_OUT")"

# Wait until k3s API answers on the node (cloud-init may still be running)
echo "Waiting for SSH + k3s (up to ~3 min)..."
for i in $(seq 1 36); do
  if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 \
    "root@${IP}" "kubectl get nodes >/dev/null 2>&1"; then
    break
  fi
  if [[ "$i" -eq 36 ]]; then
    echo "Timed out waiting for k3s. SSH in and check: journalctl -u k3s -e" >&2
    exit 1
  fi
  sleep 5
done

scp -o StrictHostKeyChecking=accept-new \
  "root@${IP}:/etc/rancher/k3s/k3s.yaml" "$KUBE_OUT"

# k3s writes 127.0.0.1; replace with public IP (firewall allows your admin_cidrs)
# portable sed: write to temp then mv (works on macOS + Git Bash)
tmp="$(mktemp)"
sed "s#https://127.0.0.1:6443#https://${IP}:6443#g" "$KUBE_OUT" > "$tmp"
mv "$tmp" "$KUBE_OUT"

export KUBECONFIG="$KUBE_OUT"
echo ""
echo "Wrote $KUBE_OUT"
echo "Run:  export KUBECONFIG=$KUBE_OUT"
kubectl get nodes
