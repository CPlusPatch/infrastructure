{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "backups/passphrase" = {
      sopsFile = secretsDir + /backups.yaml;
      key = "passphrase";
    };
  };
}
