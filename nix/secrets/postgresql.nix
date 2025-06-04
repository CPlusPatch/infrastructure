{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "postgresql/root" = {
      sopsFile = secretsDir + /postgresql/root.yaml;
      key = "password";
    };
  };
}
