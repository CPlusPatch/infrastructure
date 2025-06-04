{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "keycloak/nextcloud/client_secret" = {
      sopsFile = secretsDir + /keycloak/nextcloud.yaml;
      key = "client_secret";
    };
  };
}
