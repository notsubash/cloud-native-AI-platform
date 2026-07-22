#cloud-config
# =============================================================================
# Minimal cloud-init — install single-node k3s
# =============================================================================
# After terraform apply:
#   ssh root@<ip>
#   cat /etc/rancher/k3s/k3s.yaml   # this is your kubeconfig
# On your laptop: replace 127.0.0.1 with the public IP.
# =============================================================================

package_update: true

packages:
  - curl

runcmd:
  # Install k3s as a single-node cluster (default Traefik + servicelb).
  # DISABLE traefik later if you prefer nginx — for Phase 6, leave defaults.
  - curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644