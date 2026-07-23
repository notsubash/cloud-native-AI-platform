# why: size, location, and SSH key stay outside code so we do not bake secrets into git.

variable  "server_name" {
    type = string
    description = "Hetzner server name"
    default = "cnai-hobby"
}

variable "server_type" {
    type = string
    description = "Hetzner type - CX22 is the cheap learning default"
    default = "cx23"
}

variable "location" {
    type = string
    description = "Hetzner location code (e.g. nbg1, fsn1, hel1)"
    default = "nbg1"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to our public key file (contents get uploaded to Hetzner)"
}

variable "admin_cidrs" {
  type        = list(string)
  description = "Your public IP(s) as /32 — SSH (22) and kubectl API (6443). Find IP: curl -4 ifconfig.me"
}

variable "enable_dns" {
  type        = bool
  description = "Wire Cloudflare DNS? Keep false until later"
  default     = false
}

variable "domain" {
  type        = string
  description = "Apex domain in Cloudflare (only if enable_dns)"
  default     = ""
}

variable "subdomain" {
  type        = string
  description = "Hostname prefix, e.g. lab → lab.example.com"
  default     = "lab"
}
