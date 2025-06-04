{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "keycloak/grafana/client_id" = {
      sopsFile = secretsDir + /keycloak/grafana.yaml;
      key = "client_id";
    };
    "keycloak/grafana/client_secret" = {
      sopsFile = secretsDir + /keycloak/grafana.yaml;
      key = "client_secret";
    };
  };
}
