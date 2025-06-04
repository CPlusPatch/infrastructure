{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "redis/bitchbot" = {
      sopsFile = secretsDir + /redis/bitchbot.yaml;
      key = "password";
    };
  };
}
