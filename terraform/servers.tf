resource "hcloud_server" "test1" {
  name                     = "test4"
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
    #"test01.cpluspatch.com" = hcloud_server.test1
    #"test02.cpluspatch.com" = hcloud_server.test1
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
  target_host                = "${each.key}.infra.cpluspatch.com"
  nixos_system_attr          = "${path.module}/..#colmena.${each.key}.base.config.system.build.toplevel"
  nixos_partitioner_attr     = "${path.module}/..#colmena.${each.key}.base.config.system.build.diskoScript"
  nixos_generate_config_path = "${path.module}/../nix/machines/${each.key}"
  instance_id                = each.value.server.id
  extra_files_script         = "${path.module}/decrypt-age-keys.sh"
  extra_environment = {
    SOPS_FILE = var.sops_file
  }
}
