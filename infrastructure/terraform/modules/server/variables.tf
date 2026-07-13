variable "name" { type = string }

variable "server_type" { type = string }

variable "location" { type = string }

variable "ssh_public_key" {
  type        = string
  description = "Full public key string, not a path"
}

variable "firewall_id" {
  type = string
}

variable "user_data" {
  type        = string
  description = "cloud-init YAML"
  default     = ""
}