{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "postgresql/versia" = {
      sopsFile = secretsDir + /postgresql/versia.yaml;
      key = "password";
    };
  };
}
