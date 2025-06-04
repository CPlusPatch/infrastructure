{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "postgresql/versia2" = {
      sopsFile = secretsDir + /postgresql/versia2.yaml;
      key = "password";
    };
  };
}
