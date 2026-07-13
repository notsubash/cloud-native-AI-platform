locals {
    ssh_public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

module "firewall" {
    source = "../../modules/firewall"

    name = "${var.server_name}-fw"
    ssh_source_cidrs = ["0.0.0.0/0"] # TODO: replace with our IP/32
}

module "server" {
    source = "../../modules/server"

    name         = var.server_name
    server_type  = var.server_type
    location     = var.location
    ssh_public_key = local.ssh_public_key
    firewall_id  = module.firewall.id

    
    # TODO: switch to templatefile() once you create cloud-init.yaml.tpl
    user_data = <<-EOT
        #cloud-config
        package_update: true
        runcmd:
        - echo "hobby VPS ready — k3s comes later"
    EOT
}

module "dns" {
  source = "../../modules/dns"
  count  = var.enable_dns ? 1 : 0
  
  zone_name    = var.domain
  record_name  = var.subdomain
  ipv4_address = module.server.ipv4_address
}