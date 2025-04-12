{
  ips = builtins.mapAttrs (name: value: value.network_ipv4) (builtins.fromJSON (builtins.readFile ../../terraform/nixos-vars.json));
}
