# =============================================================================
# templatefile() reads the .tpl and substitutes ${...} variables.
# Here we keep the template simple (no vars) — empty map {}.
#
# MONEY MOMENT: the next `terraform apply` creates a billable Hetzner server.
# ==========================================================================

locals {
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

module "firewall" {
    source = "../../modules/firewall"

    name = "${var.server_name}-fw"
    ssh_source_cidrs = ["103.129.135.175/32"] 
}

module "server" {
    source = "../../modules/server"

    name         = var.server_name
    server_type  = var.server_type
    location     = var.location
    ssh_public_key = local.ssh_public_key
    firewall_id  = module.firewall.id

    user_data = templatefile("${path.module}/cloud-init.yaml.tpl", {})
}

# module "dns" {
#  source = "../../modules/dns"
#  count  = var.enable_dns ? 1 : 0
#  
#  zone_name    = var.domain
#  record_name  = var.subdomain
#  ipv4_address = module.server.ipv4_address
#}