terraform {
    required_version = ">= 1.5.0"

    required_providers {
        hcloud = {
            source = "hetznercloud/hcloud"
            version = "~> 1.45"
        }

        # DNS can wait until we have a domain
        cloudflare = {
            source = "cloudflare/cloudflare"
            version = "~> 4.0"
        }
    }

    # TODO: backend "s3" or terraform cloud when we destroy/recreate often
}