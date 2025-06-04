{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "keycloak/synapse/client_secret" = {
      sopsFile = secretsDir + /keycloak/synapse.yaml;
      key = "client_secret";
    };
  };
}
