variable "name" {
 type = string
}

variable "ssh_source_cidrs" {
    type = list(string)
    description = "Who may SSH. Our home IP/32"
    default = ["0.0.0.0/0"] # TODO: tighten to our IP/32 before real apply
}