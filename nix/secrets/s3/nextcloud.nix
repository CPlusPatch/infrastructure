{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "s3/nextcloud/secret_key" = {
      sopsFile = secretsDir + /s3/nextcloud.yaml;
      key = "key_secret";
    };
  };
}
