output "public_ip" {
  description = "VPS IPv4 — SSH and kubectl API"
  value       = module.server.ipv4_address
}

output "ssh_command" {
  description = "Copy-paste SSH"
  value       = "ssh root@${module.server.ipv4_address}"
}

output "kubeconfig_hint" {
  description = "After apply + ~2 min for cloud-init, run this from repo root"
  value       = "./scripts/fetch-hobby-kubeconfig.sh"
}

output "dns_name" {
  description = "FQDN if DNS enabled"
  value       = null
}
