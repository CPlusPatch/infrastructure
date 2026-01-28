{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "factorio/password" = {
      sopsFile = secretsDir + /factorio.yaml;
      key = "password";
    };
  };
}
