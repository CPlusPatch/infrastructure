{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "fitbit-fetch/client_id" = {
      sopsFile = secretsDir + /fitbit-fetch.yaml;
      key = "client_id";
    };
    "fitbit-fetch/client_secret" = {
      sopsFile = secretsDir + /fitbit-fetch.yaml;
      key = "client_secret";
    };
    "fitbit-fetch/influxdb_password" = {
      sopsFile = secretsDir + /fitbit-fetch.yaml;
      key = "influxdb_password";
    };
  };
}
