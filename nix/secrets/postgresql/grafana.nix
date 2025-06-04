{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "postgresql/grafana" = {
      sopsFile = secretsDir + /postgresql/grafana.yaml;
      key = "password";
    };
  };
}
