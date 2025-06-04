{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "nextcloud/secret" = {
      sopsFile = secretsDir + /nextcloud.yaml;
      key = "secret";
    };
    "nextcloud/exporter_password" = {
      sopsFile = secretsDir + /nextcloud.yaml;
      key = "exporter_password";
    };
  };
}
