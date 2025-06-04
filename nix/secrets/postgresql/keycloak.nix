{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "postgresql/keycloak" = {
      sopsFile = secretsDir + /postgresql/keycloak.yaml;
      key = "password";
    };
  };
}
