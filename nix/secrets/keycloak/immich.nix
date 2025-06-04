{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "keycloak/immich/client_secret" = {
      sopsFile = secretsDir + /keycloak/immich.yaml;
      key = "client_secret";
    };
  };
}
