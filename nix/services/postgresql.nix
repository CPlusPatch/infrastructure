{config, ...}: {
  imports = [
    ../modules/postgresql.nix
    ../secrets/postgresql.nix
    ../secrets/s3/backups.nix
  ];

  modules.postgresql = {
    enable = true;

    root = {
      user = "admin";
      password = config.sops.placeholder."postgresql/root";
    };
  };

  modules.pgbackrest = {
    repositories = [
      {
        s3_bucket = "backups";
        s3_region = "eu-central";
        s3_backups_path = "/postgresql";
        s3_endpoint = "eu-central.object.fastlystorage.app";
        s3_access_key = config.sops.placeholder."s3/backups/key_id";
        s3_secret_key = config.sops.placeholder."s3/backups/secret_key";
      }
    ];

    retention = {
      full = 10;
    };

    schedule = {
      full = "daily";
    };
  };
}
