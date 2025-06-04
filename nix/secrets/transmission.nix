{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "transmission/password" = {
      sopsFile = secretsDir + /transmission.yaml;
      key = "password";
    };
  };
}
