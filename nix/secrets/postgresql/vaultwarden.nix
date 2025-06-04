{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "postgresql/vaultwarden" = {
      sopsFile = secretsDir + /postgresql/vaultwarden.yaml;
      key = "password";
    };
  };
}
