# Domains pointing to each host, exported to Terraform through the flake's `domains` output
{lib, ...}: {
  options.modules.dns.domains = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "Domains pointing to this host. Services add the domains they serve";
  };
}
