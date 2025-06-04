{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "redis/versia2" = {
      sopsFile = secretsDir + /redis/versia2.yaml;
      key = "password";
    };
  };
}
