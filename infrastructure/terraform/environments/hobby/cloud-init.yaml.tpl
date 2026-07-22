#cloud-config
# =============================================================================
# First-boot: install single-node k3s with TLS SAN = this VPS public IP
# so kubectl from your laptop (https://<public-ip>:6443) trusts the API cert.
#
# Public IP comes from Hetzner link-local metadata (no Terraform cycle needed).
# After apply: ./scripts/fetch-hobby-kubeconfig.sh
# =============================================================================

package_update: true

packages:
  - curl

runcmd:
  - |
    set -e
    PUBLIC_IP=$(curl -fsSL http://169.254.169.254/hetzner/v1/metadata/public-ipv4)
    curl -sfL https://get.k3s.io | sh -s - \
      --write-kubeconfig-mode 644 \
      --tls-san "$PUBLIC_IP"
