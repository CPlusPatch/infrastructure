terraform {
  # "~>" allows minor updates (tofu init -upgrade), not new major versions
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.69"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.27"
    }

    # GitHub SSH keys (keys.tf)
    http = {
      source  = "hashicorp/http"
      version = "~> 3.6"
    }

    # nixos-vars.json (servers.tf)
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
  }
}
