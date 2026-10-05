{
  pkgs,
  config,
  lib,
  infra,
  ...
}: let
  # Roles for the services on faithplate, each owning the database of the same name, with
  # the sops secret holding its password
  roles = {
    grafana = "postgresql/grafana";
    keycloak = "postgresql/keycloak";
    mautrixsignal = "postgresql/mautrix-signal";
    misskey = "postgresql/sharkey";
    nextcloud = "postgresql/nextcloud";
    plausible = "postgresql/plausible";
    synapse = "postgresql/synapse";
    vaultwarden = "postgresql/vaultwarden";
    versia = "postgresql/versia";
  };

  # pgbackrest backs up to a single repo per run (repo1 unless --repo is given), so each
  # repo needs its own jobs. Repos are numbered alphabetically: fastly=1, kleiner=2.
  # Weekly full backups and daily incremental ones. kleiner's are offset from fastly's, as
  # only one backup per stanza can run at a time
  backupJobs = {
    full = {
      repo = 1;
      schedule = "Sun 00:00";
      type = "full";
    };
    incr = {
      repo = 1;
      schedule = "Mon..Sat 00:00";
      type = "incr";
    };
    full-kleiner = {
      repo = 2;
      schedule = "Sun 03:00";
      type = "full";
    };
    incr-kleiner = {
      repo = 2;
      schedule = "Mon..Sat 03:00";
      type = "incr";
    };
  };
in {
  sops.templates."init-db.sql" = {
    content = ''
      CREATE USER admin WITH SUPERUSER PASSWORD '${config.sops.placeholder."postgresql/root"}';
      -- Synapse refuses databases that aren't C collated, which ensureDatabases can't create
      CREATE DATABASE synapse LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;
    '';
    owner = "postgres";
  };

  # The module disallows s3-key/s3-key-secret in the Nix config (would land in the store).
  # Credentials are injected at runtime via systemd EnvironmentFile instead.
  # postgres reads this file via its membership in the pgbackrest group (added by the module).
  # archive_command (postgres user) and the backup service (pgbackrest user) both read this key.
  # postgres is a member of the pgbackrest group, so 0440 gives both users access.
  sops.secrets."sftp/backup_private_key" = {
    owner = "pgbackrest";
    mode = "0440";
  };

  sops.templates."pgbackrest-s3-env" = {
    owner = "pgbackrest";
    group = "pgbackrest";
    mode = "0440";
    content = ''
      PGBACKREST_REPO1_S3_KEY=${config.sops.placeholder."s3/backups/access_key_id"}
      PGBACKREST_REPO1_S3_KEY_SECRET=${config.sops.placeholder."s3/backups/secret_key"}
    '';
  };

  services.pgbackrest = {
    enable = true;

    repos = {
      # Primary S3 backup on Fastly eu-central
      fastly = {
        type = "s3";
        path = "/postgresql";
        s3-bucket = "backups";
        s3-region = "eu-central";
        s3-endpoint = "eu-central.object.fastlystorage.app";
        s3-uri-style = "path";
        # Retention is per repository, an unindexed retention-full only applies to repo1
        retention-full = 4;
      };

      # Secondary SFTP backup on kleiner
      kleiner = {
        type = "sftp";
        sftp-host = infra.kleiner.address;
        sftp-host-user = "jessew";
        path = "/mnt/HDD1/Backups/Infra/postgresql";
        sftp-private-key-file = config.sops.secrets."sftp/backup_private_key".path;
        sftp-host-key-check-type = "fingerprint";
        sftp-host-key-hash-type = "sha256";
        # SHA-256 of kleiner's ECDSA host key, in hex:
        # ssh-keyscan -t ecdsa kleiner 2>/dev/null | awk '{print $3}' | base64 -d | sha256sum
        sftp-host-fingerprint = "7750d245a9dbf20611239c9a97c7aeca229058eb44d77f869fa57a1a88361bc5";
        retention-full = 4;
      };
    };

    stanzas.main = {
      instances.localhost = {
        path = config.services.postgresql.dataDir;
        user = "postgres";
      };

      jobs = lib.mapAttrs (name: job: {inherit (job) schedule type;}) backupJobs;

      settings = {
        start-fast = true;
      };
    };

    settings = {
      process-max = 4;
      log-level-console = "warn";
      log-level-file = "off"; # journald captures all output
    };
  };

  systemd.services =
    lib.mapAttrs' (name: job:
      lib.nameValuePair "pgbackrest-main-${name}" {
        serviceConfig = {
          # S3 credentials, which the module doesn't allow in the Nix store
          EnvironmentFile = config.sops.templates."pgbackrest-s3-env".path;
          ExecStart = lib.mkForce "${lib.getExe pkgs.pgbackrest} --stanza=main --repo=${toString job.repo} backup --type=${job.type}";
        };
      })
    backupJobs
    // {
      # S3 credentials for archive-push, through archive_command
      postgresql.serviceConfig.EnvironmentFile = config.sops.templates."pgbackrest-s3-env".path;

      # Sets each role's password from its secret, so the databases can be recreated from
      # this file alone. Runs on every boot and deploy, which also undoes manual changes
      postgresql-set-passwords = {
        description = "Set PostgreSQL role passwords";
        wantedBy = ["multi-user.target"];
        requires = ["postgresql-setup.service"];
        after = ["postgresql-setup.service"];
        restartTriggers = [(builtins.toJSON roles)];
        path = [config.services.postgresql.finalPackage];
        environment.PGPORT = toString config.services.postgresql.settings.port;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "postgres";
          Group = "postgres";
          # Read as root, so the secrets can keep their default owner
          LoadCredential = lib.mapAttrsToList (role: secret: "${role}:${config.sops.secrets.${secret}.path}") roles;
        };
        script = lib.concatMapStrings (role: ''
          psql -d postgres -v ON_ERROR_STOP=1 -v password="$(< "$CREDENTIALS_DIRECTORY/${role}")" <<'EOF'
            ALTER ROLE "${role}" WITH PASSWORD :'password';
          EOF
        '') (lib.attrNames roles);
      };
    };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    initialScript = config.sops.templates."init-db.sql".path;

    ensureDatabases = lib.attrNames roles;
    ensureUsers =
      map (role: {
        name = role;
        ensureDBOwnership = true;
      })
      (lib.attrNames roles);

    authentication = ''
      # Managed by a Nix module
      host  all       all      127.0.0.1/32     scram-sha-256
      host  all       all      ::1/128          scram-sha-256
      # LAN network
      host  all       all      10.0.0.0/8        scram-sha-256
      # Tailscale
      host  all       all      100.64.0.0/10     scram-sha-256
    '';

    settings = {
      port = 5432;

      # Override stanza name to main for legacy compat with old backup scripts
      archive_command = lib.mkForce ''${lib.getExe pkgs.pgbackrest} --stanza=main archive-push "%p"'';
      archive_mode = "on";
      archive_timeout = "300";

      # Every address, including Tailscale's whenever it comes up. The firewall only lets in
      # the private network and Tailscale, and the rules above only accept those too
      listen_addresses = lib.mkForce "*";

      # pgtune: 4 GB RAM, 2 CPUs, 100 connections, web workload, SSD. The cache size is
      # shared_buffers plus ZFS' cache, which is capped at 1 GiB on freeman
      max_connections = "100";
      shared_buffers = "1GB";
      effective_cache_size = "2GB";
      maintenance_work_mem = "256MB";
      checkpoint_completion_target = "0.9";
      wal_buffers = "16MB";
      default_statistics_target = "100";
      random_page_cost = "1.1";
      effective_io_concurrency = "200";
      work_mem = "5242kB";
      huge_pages = "off";
      min_wal_size = "1GB";
      max_wal_size = "4GB";
    };
  };

  systemd.tmpfiles.rules = [
    # Lock directory shared between the pgbackrest (backup) and postgres (archive-push) users.
    # Mode 1777 (sticky + world-writable, like /tmp) lets both users create and flock files
    # without one user's files blocking the other.
    "d /tmp/pgbackrest 1777 root root -"
  ];
}
