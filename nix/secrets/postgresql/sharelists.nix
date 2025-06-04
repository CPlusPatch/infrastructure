{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "postgresql/sharelists" = {
      sopsFile = secretsDir + /postgresql/sharelists.yaml;
      key = "password";
    };
  };
}
