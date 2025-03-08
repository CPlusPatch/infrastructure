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
    ipv6_enabled = true
  }

  lifecycle {
    ignore_changes = [ssh_keys]
  }
}

locals {
  servers = [{
    server = hcloud_server.test1
  }]

  # DNS configuration to be applied to Cloudflare
  domains = {
    "test01.cpluspatch.com" = hcloud_server.test1
    "test02.cpluspatch.com" = hcloud_server.test1
  }
}

# Call nixos-install module for each server
module "nixos_install" {
  source = "./nixos-install"

  for_each    = { for s in local.servers : s.server.name => s }
  ssh_user    = "root"
  target_host = "${each.key}.infra.cpluspatch.com"
}
