# Domains pointing to each host, exported to Terraform through the flake's `domains` output
{
  config,
  lib,
  ...
}: let
  cfg = config.modules.dns;
  # Has its own A/AAAA records in Terraform
  hostDomain = "${config.networking.hostName}.infra.cpluspatch.com";
in {
  options.modules.dns = {
    extraDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Domains pointing to this host that don't have a certificate";
    };

    domains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "All domains pointing to this host: its certificates and extraDomains";
    };
  };

  config.modules.dns.domains = lib.sort lib.lessThan (lib.unique (
    lib.filter (domain: domain != hostDomain) (lib.attrNames config.security.acme.certs)
    ++ cfg.extraDomains
  ));
}
