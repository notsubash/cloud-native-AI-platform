# =============================================================================
# Hobby env: one VPS + firewall. cloud-init installs k3s with --tls-san so
# kubectl can talk to the public IP on :6443 (firewall-locked to admin_cidrs).
#
# MONEY: terraform apply starts Hetzner billing; destroy stops it.
# =============================================================================

locals {
  ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

module "firewall" {
  source = "../../modules/firewall"

  name             = "${var.server_name}-fw"
  ssh_source_cidrs = var.admin_cidrs
}

module "server" {
  source = "../../modules/server"

  name           = var.server_name
  server_type    = var.server_type
  location       = var.location
  ssh_public_key = local.ssh_public_key
  firewall_id    = module.firewall.id

  user_data = templatefile("${path.module}/cloud-init.yaml.tpl", {})
}

# module "dns" {
#   source = "../../modules/dns"
#   count  = var.enable_dns ? 1 : 0
#
#   zone_name    = var.domain
#   record_name  = var.subdomain
#   ipv4_address = module.server.ipv4_address
# }
