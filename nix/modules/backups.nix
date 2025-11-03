{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.backups;
in {
  imports = [
    ../secrets/s3/backups.nix
    ../secrets/backups.nix

    ./s3fs.nix
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

  config = mkIf (builtins.length (builtins.attrNames cfg.jobs)
    != 0) {
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

    services.borgbackup = {
      jobs =
        mapAttrs (name: job: {
          paths = [job.source];
          startAt = "daily";
          repo = "${config.services.s3fs.mountPath}/directories/${name}";
          failOnWarnings = false; # Don't fail if file changes during backup
          prune.keep = {
            within = "1d";
            daily = 7;
            weekly = 4;
            monthly = -1;
          };
          removableDevice = true;
          encryption = {
            passCommand = "cat ${config.sops.secrets."backups/passphrase".path}";
            mode = "repokey";
          };
          compression = "auto,zstd,7";
        })
        cfg.jobs;

      repos =
        mapAttrs (name: job: {
          path = "${config.services.s3fs.mountPath}/directories/${name}";
          authorizedKeys = config.users.users.jessew.openssh.authorizedKeys.keys;
        })
        cfg.jobs;
    };

    # For each borg backup job foo at systemd.services.borgbackup-job-foo
    # override and dependency on s3fs.mount
    systemd.services =
      mapAttrs' (name: job:
        lib.nameValuePair "borgbackup-job-${name}" {
          after = ["s3fs.service"];
          wants = ["s3fs.service"];
        })
      cfg.jobs
      // mapAttrs' (name: job:
        lib.nameValuePair "borgbackup-repo-${name}" {
          after = ["s3fs.service"];
          wants = ["s3fs.service"];
        })
      cfg.jobs;
  };
}
