{
  config,
  lib,
  pkgs,
  infra,
  ...
}:
with lib; let
  cfg = config.services.backups;
  s3Endpoint = "https://eu-central.object.fastlystorage.app";
  bucket = "backups";
  zfs = "${config.boot.zfs.package}/bin/zfs";
  restic = getExe pkgs.restic;

  s3Repo = name: "s3:${s3Endpoint}/${bucket}/directories/${name}";
  sftpRepo = name: "sftp:jessew@${infra.kleiner.address}:/mnt/HDD1/Backups/Infra/${name}";
  sftpOption = "sftp.args=-i ${config.sops.secrets."sftp/backup_private_key".path}";
  envFile = config.sops.templates."restic-env".path;
  # Shared by every unit of a job. restic keeps each repository's cache in its own subdirectory
  cacheDir = name: "restic-backups-s3-${name}";

  pruneOpts = [
    "--keep-daily 7"
    "--keep-weekly 5"
    "--keep-monthly 12"
  ];

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

    schedule = mkOption {
      type = types.str;
      default = "daily";
      description = "When the backups start (systemd calendar event), each at a random delay after it";
    };

    randomizedDelay = mkOption {
      type = types.str;
      default = "3h";
      description = "Maximum random delay after the schedule, spreading the jobs out";
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
        RESTIC_FROM_PASSWORD=${config.sops.placeholder."backups/passphrase"}
        AWS_DEFAULT_REGION=eu-central
      '';
    };

    # Each job backs up to S3 (s3-<name>), then copies the new snapshots to kleiner, so the
    # source is only read once and kleiner being off doesn't hold back the S3 backups
    services.restic.backups = mapAttrs' (name: job: let
      snapshotName = "restic-s3-${name}";
      fs = filesystemOf job.source;
      mount =
        if fs.mountPoint == "/"
        then ""
        else fs.mountPoint;
      snapshot = "${fs.device}@${snapshotName}";
    in
      nameValuePair "s3-${name}" ({
          repository = s3Repo name;
          paths = [
            (
              if job.zfsSnapshot
              then "${mount}/.zfs/snapshot/${snapshotName}${removePrefix mount job.source}"
              else job.source
            )
          ];
          initialize = true;
          environmentFile = envFile;
          timerConfig = {
            OnCalendar = cfg.schedule;
            RandomizedDelaySec = cfg.randomizedDelay;
            Persistent = true;
          };
          # Pruning and checking are weekly, in restic-maintenance-<name>
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
        }))
    cfg.jobs;

    systemd.services = mkMerge (mapAttrsToList (name: job: let
        common = {
          wants = ["network-online.target"];
          after = ["network-online.target"];
          # The SFTP backend runs ssh
          path = [config.programs.ssh.package];
          environment.RESTIC_CACHE_DIR = "/var/cache/${cacheDir name}";
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = envFile;
            CacheDirectory = cacheDir name;
            CacheDirectoryMode = "0700";
            PrivateTmp = true;
          };
        };
      in {
        "restic-backups-s3-${name}".unitConfig.OnSuccess = ["restic-copy-${name}.service"];

        "restic-copy-${name}" = recursiveUpdate common {
          description = "Copy the ${name} backups to kleiner";
          environment = {
            RESTIC_REPOSITORY = sftpRepo name;
            RESTIC_FROM_REPOSITORY = s3Repo name;
          };
          script = ''
            restic() { ${restic} --option ${escapeShellArg sftpOption} "$@"; }

            # Created with the same chunker parameters as the S3 repository, so that both split
            # files the same way
            restic cat config --no-lock > /dev/null || {
              status=$?
              if [ "$status" -eq 10 ]; then
                restic init --copy-chunker-params
              else
                exit "$status"
              fi
            }

            # Every snapshot kleiner doesn't have yet, e.g. after it was off for a few days
            restic copy
          '';
        };

        # Pruning lists every pack in the repository, and checking downloads a sample of them,
        # so they run weekly rather than after every backup
        "restic-maintenance-${name}" = recursiveUpdate common {
          description = "Prune and check the ${name} backups";
          script = concatMapStrings (repo: ''
            ${restic} --repo ${repo} --option ${escapeShellArg sftpOption} unlock
            ${restic} --repo ${repo} --option ${escapeShellArg sftpOption} forget --prune ${concatStringsSep " " pruneOpts}
            ${restic} --repo ${repo} --option ${escapeShellArg sftpOption} check --read-data-subset=10%
          '') [(s3Repo name) (sftpRepo name)];
        };
      })
      cfg.jobs);

    systemd.timers = mapAttrs' (name: job:
      nameValuePair "restic-maintenance-${name}" {
        wantedBy = ["timers.target"];
        timerConfig = {
          # After the night's backups
          OnCalendar = "Sun 05:00";
          RandomizedDelaySec = "1h";
          Persistent = true;
        };
      })
    cfg.jobs;

    # restic with kleiner's repository and the credentials loaded, like the restic module's
    # restic-s3-<name> wrappers
    environment.systemPackages = mapAttrsToList (name: job:
      pkgs.writeShellScriptBin "restic-sftp-${name}" ''
        set -a
        source ${envFile}
        set +a
        export RESTIC_CACHE_DIR=/var/cache/${cacheDir name}
        exec ${restic} --repo ${sftpRepo name} --option ${escapeShellArg sftpOption} "$@"
      '')
    cfg.jobs;
  };
}
