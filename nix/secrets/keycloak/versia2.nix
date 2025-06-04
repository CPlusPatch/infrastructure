{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "keycloak/versia2/client_secret" = {
      sopsFile = secretsDir + /keycloak/versia2.yaml;
      key = "client_secret";
    };
  };
}
