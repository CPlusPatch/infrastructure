{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "s3/versia2/key_id" = {
      sopsFile = secretsDir + /s3/versia2.yaml;
      key = "key_id";
    };
    "s3/versia2/secret_key" = {
      sopsFile = secretsDir + /s3/versia2.yaml;
      key = "key_secret";
    };
  };
}
