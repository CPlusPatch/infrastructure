terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.50"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5"
    }
  }
}

variable "hcloud_token" {
  type        = string
  sensitive   = true
  description = "Hetzner Cloud API Token"
}

variable "cloudflare_token" {
  type        = string
  sensitive   = true
  description = "Cloudflare API Token"
}

variable "cpluspatch-com-zone_id" {
  type        = string
  description = "Cloudflare Zone ID for cpluspatch.com"
  nullable    = false
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_token
}

resource "hcloud_ssh_key" "jesse" {
  name       = "jesse"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "hcloud_primary_ip" "fsn1_ipv4_1" {
  name          = "fsn1_ipv4_1"
  type          = "ipv4"
  assignee_type = "server"
  datacenter    = "fsn1"
  auto_delete   = false
}

resource "hcloud_primary_ip" "fsn1_ipv6_1" {
  name          = "fsn1_ipv6_1"
  type          = "ipv6"
  assignee_type = "server"
  datacenter    = "fsn1"
  auto_delete   = false
}

resource "hcloud_server" "chell" {
  name                     = "chell"
  image                    = "arch-linux"
  server_type              = "ax41-nvme"
  location                 = "fsn1"
  ssh_keys                 = [hcloud_ssh_key.jesse.id]
  delete_protection        = true
  rebuild_protection       = true
  shutdown_before_deletion = true

  public_net {
    ipv4_enabled = true
    ipv4         = hcloud_primary_ip.fsn1_ipv4_1.id
    ipv6_enabled = true
    ipv6         = hcloud_primary_ip.fsn1_ipv6_1.id
  }

  lifecycle {
    ignore_changes = [ssh_keys]
  }
}

# Additional records will be CNAMEs to main servers
resource "cloudflare_dns_record" "chell_infra_ipv4" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "Main IPv4 record for the ${hcloud_server.chell.name} server"
  name    = "chell.infra.cpluspatch.com"
  type    = "A"
  content = hcloud_primary_ip.fsn1_ipv4_1.ip_address
  ttl     = 1
}

resource "cloudflare_dns_record" "chell_infra_ipv6" {
  zone_id = var.cpluspatch-com-zone_id
  comment = "Main IPv6 record for the ${hcloud_server.chell.name} server"
  name    = "chell.infra.cpluspatch.com"
  type    = "AAAA"
  content = hcloud_primary_ip.fsn1_ipv6_1.ip_address
  ttl     = 1
}

# Map of main server DNS records to domains
# E.g. chell -> matrix.cpluspatch.dev, uptime.cpluspatch.com, stats.cpluspatch.com, etc
locals {
  domain_server_mappings = {
    "uptime.cpluspatch.com" = "chell"
    "stats.cpluspatch.com"  = "chell"
  }
}

# Create CNAME records for each server
# In the above example, we should have:
# CNAME matrix.cpluspatch.dev -> chell.infra.cpluspatch.com
# CNAME uptime.cpluspatch.com -> chell.infra.cpluspatch.com
# etc
resource "cloudflare_dns_record" "server_cnames" {
  for_each = local.domain_server_mappings

  zone_id = var.cpluspatch-com-zone_id
  name    = each.key
  type    = "CNAME"
  content = "${each.value}.infra.cpluspatch.com"
  ttl     = 1
}
