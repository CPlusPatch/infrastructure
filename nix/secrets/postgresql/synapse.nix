{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "postgresql/synapse" = {
      sopsFile = secretsDir + /postgresql/synapse.yaml;
      key = "password";
    };
  };
}
