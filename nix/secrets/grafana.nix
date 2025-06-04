{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "grafana/secret_key" = {
      sopsFile = secretsDir + /grafana.yaml;
      key = "secret_key";
    };
  };
}
