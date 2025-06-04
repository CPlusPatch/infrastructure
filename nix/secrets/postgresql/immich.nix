{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "postgresql/immich" = {
      sopsFile = secretsDir + /postgresql/immich.yaml;
      key = "password";
    };
  };
}
