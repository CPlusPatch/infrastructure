{config, ...}: {
  imports = [
    ../../modules/s3fs.nix
    ../../secrets/s3/backups.nix
  ];

  sops.templates."s3fs-passwd" = {
    content = ''
      ${config.sops.placeholder."s3/backups/key_id"}:${config.sops.placeholder."s3/backups/secret_key"}
    '';
  };

  services.s3fs = {
    enable = true;
    keyPath = config.sops.templates."s3fs-passwd".path;
    mountPath = "/mnt/backups";
    bucket = "backups";
    region = "eu-central";
    url = "https://eu-central.object.fastlystorage.app";
  };
}
