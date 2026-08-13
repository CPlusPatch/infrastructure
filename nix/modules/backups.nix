{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.backups;
  s3Endpoint = "https://eu-central.object.fastlystorage.app";
  bucket = "backups";
in {
  imports = [
    ../lib/secrets.nix
  ];

  options.services.backups = {
    jobs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          source = mkOption {
            type = types.str;
          };
        };
      });
      default = {};
    };
  };

  config = mkIf (builtins.length (builtins.attrNames cfg.jobs) != 0) {
    sops.templates."restic-env" = {
      content = ''
        AWS_ACCESS_KEY_ID=${config.sops.placeholder."s3/backups/access_key_id"}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."s3/backups/secret_key"}
        RESTIC_PASSWORD=${config.sops.placeholder."backups/passphrase"}
        AWS_DEFAULT_REGION=eu-central
      '';
    };

    services.restic.backups =
      let
        commonSettings = name: job: {
          paths = [job.source];
          initialize = true;
          timerConfig = {
            OnCalendar = "daily";
            RandomizedDelaySec = "3h";
            Persistent = true;
          };
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 5"
            "--keep-monthly 12"
          ];
          extraBackupArgs = [
            "--compression=auto"
            "--cleanup-cache"
          ];
        };
        s3Jobs = mapAttrs' (name: job:
          nameValuePair "s3-${name}" (commonSettings name job // {
            repository = "s3:${s3Endpoint}/${bucket}/directories/${name}";
            environmentFile = config.sops.templates."restic-env".path;
            initialize = true;
          })
        ) cfg.jobs;
        sftpJobs = mapAttrs' (name: job:
          nameValuePair "sftp-${name}" (commonSettings name job // {
            repository = "sftp:jessew@kleiner:/mnt/HDD1/Backups/Infra/${name}";
            environmentFile = config.sops.templates."restic-env".path;
            initialize = true;
            extraOptions = [
              "sftp.args='-i ${config.sops.secrets."sftp/backup_private_key".path}'"
            ];
          })
        ) cfg.jobs;
      in
        s3Jobs // sftpJobs;
  };
}
