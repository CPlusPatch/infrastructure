{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "postgresql/plausible" = {
      sopsFile = secretsDir + /postgresql/plausible.yaml;
      key = "password";
    };
  };
}
