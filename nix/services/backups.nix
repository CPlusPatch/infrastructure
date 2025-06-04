{config, ...}: {
  imports = [
    ../../modules/s3fs.nix
  ];

  sops.templates."s3fs-passwd" = {
    content = ''
      ${config.sops.placeholder."s3/backups/keyid"}:${config.sops.placeholder."s3/backups/secret"}
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
