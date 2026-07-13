# Why: credentials come from env vars - never commit tokens.
# export HCLOUD_TOKEN=...

provider "hcloud"{
    # token defaults to HCLOUD_TOKEN - so no need to hardcode
}

provider "cloudflare" {
    # uses CLOUDFLARE_API_TOKEN when we enable the dns module
}