# Why: Hetzner firewall attaches to the server; rules are declarative.

resource "hcloud_firewall" "this" {
    name = var.name

    # SSH
    rule {
        direction = "in"
        protocol = "tcp"
        port = "22"
        source_ips = var.ssh_source_cidrs
    }

    # HTTP / HTTPS (ingress later)
    rule {
        direction = "in"
        protocol = "tcp"
        port = "80"
        source_ips = ["0.0.0.0/0", "::/0"]
    }

    rule {
        direction  = "in"
        protocol   = "tcp"
        port       = "443"
        source_ips = ["0.0.0.0/0", "::/0"]
    }

    # TODO (optional): allow ICMP for ping diagnostics
}