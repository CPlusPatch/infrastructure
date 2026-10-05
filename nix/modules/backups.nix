{
  config,
  lib,
  infra,
  ...
}:
with lib; let
  cfg = config.services.backups;
  s3Endpoint = "https://eu-central.object.fastlystorage.app";
  bucket = "backups";
  zfs = "${config.boot.zfs.package}/bin/zfs";

  # The filesystem holding a path: the one mounted closest to it
  filesystems = attrValues config.fileSystems;
  isUnder = mount: path: mount == "/" || path == mount || hasPrefix "${mount}/" path;
  filesystemOf = path:
    foldl' (best: fs:
      if isUnder fs.mountPoint path && (best == null || stringLength fs.mountPoint > stringLength best.mountPoint)
      then fs
      else best)
    null
    filesystems;
  # Filesystems mounted below a path, which a snapshot of the path's filesystem doesn't include
  nestedMounts = path: filter (fs: fs.mountPoint != path && isUnder path fs.mountPoint) filesystems;
in {
  options.services.backups = {
    jobs = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          source = mkOption {
            type = types.str;
          };

          zfsSnapshot = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Back up from an atomic snapshot of the ZFS dataset holding the source instead of
              the live directory, so databases and game saves are captured in a consistent state.
              No other dataset may be mounted inside the source, as the snapshot wouldn't
              include it.
            '';
          };
        };
      });
      default = {};
    };
  };

  config = mkIf (cfg.jobs != {}) {
    assertions = flatten (mapAttrsToList (name: job:
      optionals job.zfsSnapshot [
        {
          assertion = (filesystemOf job.source).fsType == "zfs";
          message = "services.backups.jobs.${name}: ${job.source} isn't on a ZFS filesystem, set zfsSnapshot = false";
        }
        {
          assertion = nestedMounts job.source == [];
          message = "services.backups.jobs.${name}: ${concatMapStringsSep ", " (fs: fs.mountPoint) (nestedMounts job.source)} would be missing from the snapshot of ${job.source}";
        }
      ])
    cfg.jobs);

    # The SFTP target. Pinned, as root has no known_hosts otherwise
    programs.ssh.knownHosts.kleiner = {
      hostNames = [infra.kleiner.address];
      publicKey = infra.kleiner.hostKey;
    };

    sops.templates."restic-env" = {
      content = ''
        AWS_ACCESS_KEY_ID=${config.sops.placeholder."s3/backups/access_key_id"}
        AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."s3/backups/secret_key"}
        RESTIC_PASSWORD=${config.sops.placeholder."backups/passphrase"}
        AWS_DEFAULT_REGION=eu-central
      '';
    };

    services.restic.backups = let
      # `name` is the full restic job name (s3-*, sftp-*), so each job gets its own
      # snapshot and the two targets can run concurrently
      commonSettings = name: job: let
        snapshotName = "restic-${name}";
        fs = filesystemOf job.source;
        mount =
          if fs.mountPoint == "/"
          then ""
          else fs.mountPoint;
        snapshot = "${fs.device}@${snapshotName}";
      in
        {
          paths = [
            (
              if job.zfsSnapshot
              then "${mount}/.zfs/snapshot/${snapshotName}${removePrefix mount job.source}"
              else job.source
            )
          ];
          initialize = true;
          environmentFile = config.sops.templates."restic-env".path;
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
          # Verify repository integrity, reading a random sample of pack data each run
          checkOpts = [
            "--read-data-subset=2%"
          ];
          extraBackupArgs = [
            "--compression=auto"
            "--cleanup-cache"
          ];
        }
        // optionalAttrs job.zfsSnapshot {
          backupPrepareCommand = ''
            ${zfs} destroy ${snapshot} 2>/dev/null || true
            ${zfs} snapshot ${snapshot}
          '';
          backupCleanupCommand = ''
            ${zfs} destroy ${snapshot}
          '';
        };
      s3Jobs =
        mapAttrs' (
          name: job:
            nameValuePair "s3-${name}" (commonSettings "s3-${name}" job
              // {
                repository = "s3:${s3Endpoint}/${bucket}/directories/${name}";
              })
        )
        cfg.jobs;
      sftpJobs =
        mapAttrs' (
          name: job:
            nameValuePair "sftp-${name}" (commonSettings "sftp-${name}" job
              // {
                repository = "sftp:jessew@${infra.kleiner.address}:/mnt/HDD1/Backups/Infra/${name}";
                extraOptions = [
                  "sftp.args='-i ${config.sops.secrets."sftp/backup_private_key".path}'"
                ];
              })
        )
        cfg.jobs;
    in
      s3Jobs // sftpJobs;
  };
}
