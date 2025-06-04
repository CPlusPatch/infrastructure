{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "redis/sharkey" = {
      sopsFile = secretsDir + /redis/sharkey.yaml;
      key = "password";
    };
  };
}
