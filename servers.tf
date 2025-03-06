resource "hcloud_server" "test1" {
  name                     = "test1"
  image                    = "ubuntu-24.04"
  server_type              = "cx22"
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
  datacenter    = "fsn1-dc14"
  auto_delete   = false
}

resource "hcloud_primary_ip" "fsn1_ipv6_1" {
  name          = "fsn1_ipv6_1"
  type          = "ipv6"
  assignee_type = "server"
  datacenter    = "fsn1-dc14"
  auto_delete   = false
}

locals {
  servers = [{
    server = hcloud_server.test1
    ipv4   = hcloud_primary_ip.fsn1_ipv4_1
    ipv6   = hcloud_primary_ip.fsn1_ipv6_1
  }]

  # DNS configuration to be applied to Cloudflare
  domains = {
    "test01.cpluspatch.com" = hcloud_server.test1
    "test02.cpluspatch.com" = hcloud_server.test1
  }
}
