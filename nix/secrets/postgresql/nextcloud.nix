{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "postgresql/nextcloud" = {
      sopsFile = secretsDir + /postgresql/nextcloud.yaml;
      key = "password";
    };
  };
}
