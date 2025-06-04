{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "redis/synapse" = {
      sopsFile = secretsDir + /redis/synapse.yaml;
      key = "password";
    };
  };
}
