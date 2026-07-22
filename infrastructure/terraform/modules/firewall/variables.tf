variable "name" {
 type = string
}

variable "ssh_source_cidrs" {
  type        = list(string)
  description = "Who may SSH and reach the K8s API (6443). Use your home IP/32."
  # No wide-open default — hobby env must pass admin_cidrs explicitly.
}