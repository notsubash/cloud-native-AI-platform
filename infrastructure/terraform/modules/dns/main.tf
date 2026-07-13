data "cloudflare_zone" "this" {
  name = var.zone_name
}

resource "cloudflare_record" "lab" {
  zone_id = data.cloudflare_zone.this.id
  name    = var.record_name
  type    = "A"
  content = var.ipv4_address
  ttl     = 1          # 1 = automatic when proxied
  proxied = true       # orange cloud — TLS edge later


  # TODO: confirm whether we want proxied=true before you have ingress ready
}