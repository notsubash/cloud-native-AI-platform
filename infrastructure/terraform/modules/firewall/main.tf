# Why: Hetzner firewall attaches to the server; rules are declarative.
# admin_cidrs (ssh_source_cidrs): home IP/32 for SSH + kubectl API — not the world.

resource "hcloud_firewall" "this" {
  name = var.name

  # SSH
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "22"
    source_ips = var.ssh_source_cidrs
  }

  # Kubernetes API (kubectl from laptop — same CIDRs as SSH)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "6443"
    source_ips = var.ssh_source_cidrs
  }

  # HTTP / HTTPS (ingress later)
  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "80"
    source_ips = ["0.0.0.0/0", "::/0"]
  }

  rule {
    direction  = "in"
    protocol   = "tcp"
    port       = "443"
    source_ips = ["0.0.0.0/0", "::/0"]
  }
}