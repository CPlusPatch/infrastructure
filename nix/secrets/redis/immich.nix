{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "redis/immich" = {
      sopsFile = secretsDir + /redis/immich.yaml;
      key = "password";
    };
  };
}
