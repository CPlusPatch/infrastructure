{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "postgresql/sharkey" = {
      sopsFile = secretsDir + /postgresql/sharkey.yaml;
      key = "password";
    };
  };
}
