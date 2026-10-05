locals {
  # Never change server_type: the servers are on grandfathered prices, and resizing moves
  # them to current pricing for good. Servers without IPv4 are IPv6-only
  servers = {
    faithplate = { server_type = "cx33", ipv4 = true }
    freeman    = { server_type = "cx23", ipv4 = false }
    eli        = { server_type = "cx33", ipv4 = true }
  }

  # Domain => server name, generated from the NixOS configuration (see flake.nix)
  domains = merge([
    for host, names in jsondecode(file("${path.module}/domains.json")) : { for d in names : d => host }
  ]...)

  domain_zone_mappings = {
    "cpluspatch.com" = var.cpluspatch-com-zone_id
    "cpluspatch.dev" = var.cpluspatch-dev-zone_id
  }

  final_domains = {
    for d, host in local.domains : d => {
      name = host
      zone = one([for z, id in local.domain_zone_mappings : id if d == z || endswith(d, ".${z}")])
    }
  }
}

resource "hcloud_server" "servers" {
  for_each = local.servers

  name                     = each.key
  image                    = "ubuntu-24.04"
  server_type              = each.value.server_type
  location                 = "fsn1"
  ssh_keys                 = [hcloud_ssh_key.jesse.id]
  delete_protection        = true
  rebuild_protection       = true
  shutdown_before_deletion = true

  public_net {
    ipv4_enabled = each.value.ipv4
    ipv6_enabled = true
  }

  lifecycle {
    ignore_changes = [ssh_keys]
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
  for_each  = local.servers
  server_id = hcloud_server.servers[each.key].id
  subnet_id = hcloud_network_subnet.main_network_subnet.id
}

# Save JSON file to be imported in the NixOS installation
resource "local_file" "nixos_vars" {
  content = jsonencode({
    for name, server in local.servers : name => {
      ipv4         = hcloud_server.servers[name].ipv4_address
      ipv6         = hcloud_server.servers[name].ipv6_address
      hostname     = name
      network_ipv4 = hcloud_server_network.main_network_server[name].ip
    }
  })
  filename        = var.nixos_vars_file
  file_permission = "600"

  # Automatically adds the generated file to Git
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "git add -f '${var.nixos_vars_file}'"
  }
}
