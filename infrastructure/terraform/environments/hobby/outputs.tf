output "public_ip" {
  description = "VPS IPv4 — use for SSH and later DNS"
  value       = module.server.ipv4_address
}

output "ssh_command" {
  description = "Copy-paste SSH"
  value       = "ssh root@${module.server.ipv4_address}"
}

output "dns_name" {
  description = "FQDN if DNS enabled"
  value       = var.enable_dns ? module.dns[0].fqdn : null
}