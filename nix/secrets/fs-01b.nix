{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "fs-01b/password" = {
      sopsFile = secretsDir + /fs-01b.yaml;
      key = "password";
    };
  };
}
