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

locals {
  servers = [{
    server = hcloud_server.chell
    ipv4   = hcloud_primary_ip.fsn1_ipv4_1
    ipv6   = hcloud_primary_ip.fsn1_ipv6_1
  }]

  # DNS configuration to be applied to Cloudflare
  domains = {
    "uptime.cpluspatch.com" = hcloud_server.chell
    "stats.cpluspatch.com"  = hcloud_server.chell
  }
}
