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

resource "hcloud_server" "freeman" {
  name                     = "freeman"
  image                    = "ubuntu-24.04"
  server_type              = "cx22"
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

resource "hcloud_server" "eli" {
  name                     = "eli"
  image                    = "ubuntu-24.04"
  server_type              = "cx22"
  location                 = "fsn1"
  ssh_keys                 = [hcloud_ssh_key.jesse.id]
  delete_protection        = false
  rebuild_protection       = false
  shutdown_before_deletion = true

  public_net {
    ipv4_enabled = false
    ipv6_enabled = true
  }

  lifecycle {
    ignore_changes = [ssh_keys]
  }
}

locals {
  servers = [
    {
      server = hcloud_server.faithplate
      ipv4   = true
      ipv6   = true
    },
    {
      server = hcloud_server.eli
      ipv4   = false
      ipv6   = true
    },
    {
      server = hcloud_server.freeman
      ipv4   = true
      ipv6   = true
    }
  ]

  # DNS configuration to be applied to Cloudflare
  domains = {
    "id.cpluspatch.com"           = hcloud_server.faithplate
    "prowlarr.lgs.cpluspatch.com" = hcloud_server.faithplate
    "radarr.lgs.cpluspatch.com"   = hcloud_server.faithplate
    "sonarr.lgs.cpluspatch.com"   = hcloud_server.faithplate
    "dl.lgs.cpluspatch.com"       = hcloud_server.faithplate
    "status.cpluspatch.com"       = hcloud_server.faithplate
    "rspamd.cpluspatch.com"       = hcloud_server.faithplate
    "matrix.cpluspatch.dev"       = hcloud_server.faithplate
    "cpluspatch.dev"              = hcloud_server.faithplate
    "vault.cpluspatch.com"        = hcloud_server.faithplate
    "logs.cpluspatch.com"         = hcloud_server.faithplate
    "mail.cpluspatch.com"         = hcloud_server.faithplate
    "stats.cpluspatch.com"        = hcloud_server.faithplate
    "stream.cpluspatch.com"       = hcloud_server.faithplate
    "cloud.cpluspatch.com"        = hcloud_server.faithplate
    "mk.cpluspatch.com"           = hcloud_server.faithplate
    "photos.cpluspatch.com"       = hcloud_server.faithplate
    "api.sl.cpluspatch.dev"       = hcloud_server.faithplate
    "social.lysand.org"           = hcloud_server.faithplate
    "mc.cpluspatch.com"           = hcloud_server.faithplate
    "vs.cpluspatch.com"           = hcloud_server.faithplate
  }

  domain_zone_mappings = {
    "cpluspatch.com" = var.cpluspatch-com-zone_id
    "cpluspatch.dev" = var.cpluspatch-dev-zone_id
    "lysand.org"     = var.lysand-org-zone_id
  }

  final_domains = {
    for d, s in local.domains : d => {
      name = s.name
      zone = [for z, id in local.domain_zone_mappings : id if endswith(d, z)][0]
    }
  }
}

# Create a Hetzner Network for the servers
resource "hcloud_network" "main_network" {
  name     = "main-network"
  ip_range = "10.0.0.0/8"
}

resource "hcloud_network_subnet" "main_network_subnet" {
  network_id   = hcloud_network.main_network.id
  type         = "server"
  ip_range     = "10.0.1.0/24"
  network_zone = "eu-central"
}

resource "hcloud_server_network" "main_network_server" {
  for_each  = { for s in local.servers : s.server.id => s.server }
  server_id = each.value.id
  subnet_id = hcloud_network_subnet.main_network_subnet.id
}

# Save JSON file to be imported in the NixOS installation
resource "local_file" "nixos_vars" {
  content = jsonencode({
    for s in local.servers : s.server.name => {
      ipv4         = s.server.ipv4_address
      ipv6         = s.server.ipv6_address
      hostname     = s.server.name
      network_ipv4 = hcloud_server_network.main_network_server[s.server.id].ip
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
  source = "github.com/numtide/nixos-anywhere/terraform/all-in-one"

  for_each = { for s in local.servers : s.server.name => s }
  # Warning: IPv6 will not work until the first rebuild
  # (which will configure the network interfaces), which
  # means an IPv4 address has to be used here
  target_host                = coalesce(each.value.server.ipv4_address, each.value.server.ipv6_address)
  nixos_system_attr          = "..#nixosConfigurations.${each.key}.config.system.build.toplevel"
  nixos_partitioner_attr     = "..#nixosConfigurations.${each.key}.config.system.build.diskoScriptNoDeps"
  nixos_generate_config_path = "${path.module}/../nix/machines/${each.key}/hardware-configuration.nix"
  instance_id                = each.value.server.id
  debug_logging              = true

  # Extract the age key from the SOPS file
  extra_files_script = "${path.module}/decrypt-age-keys.sh"
  extra_environment = {
    SOPS_FILE = var.sops_file
  }
}
