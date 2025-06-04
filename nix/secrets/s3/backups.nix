{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "s3/backups/key_id" = {
      sopsFile = secretsDir + /s3/backups.yaml;
      key = "key_id";
    };
    "s3/backups/secret_key" = {
      sopsFile = secretsDir + /s3/backups.yaml;
      key = "key_secret";
    };
  };
}
