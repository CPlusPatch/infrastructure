resource "hcloud_server" "faithplate" {
  name                     = "faithplate"
  image                    = "ubuntu-24.04"
  server_type              = "cx32"
  location                 = "fsn1"
  ssh_keys                 = [hcloud_ssh_key.jesse.id]
  delete_protection        = false
  rebuild_protection       = false
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
    server = hcloud_server.faithplate
  }]

  # DNS configuration to be applied to Cloudflare
  domains = {
    #"test01.cpluspatch.com" = hcloud_server.faithplate
    #"test02.cpluspatch.com" = hcloud_server.faithplate
  }
}

# Save JSON file to be imported in the NixOS installation
resource "local_file" "nixos_vars" {
  content = jsonencode({
    for s in local.servers : s.server.name => {
      ipv4     = s.server.ipv4_address
      ipv6     = s.server.ipv6_address
      hostname = s.server.name
    }
  }) # Converts variables to JSON
  filename        = var.nixos_vars_file
  file_permission = "600"

  # Automatically adds the generated file to Git
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "git add -f '${var.nixos_vars_file}'"
  }
}

# Call nixos-anywhere module for each server
module "nixos_install" {
  source = "github.com/numtide/nixos-anywhere//terraform/all-in-one"

  for_each                   = { for s in local.servers : s.server.name => s }
  target_host                = each.value.server.ipv4_address
  nixos_system_attr          = "..#nixosConfigurations.${each.key}.config.system.build.toplevel"
  nixos_partitioner_attr     = "..#nixosConfigurations.${each.key}.config.system.build.diskoScriptNoDeps"
  nixos_generate_config_path = "${path.module}/../nix/machines/${each.key}/hardware-configuration.nix"
  instance_id                = each.value.server.id
  debug_logging              = true
}
