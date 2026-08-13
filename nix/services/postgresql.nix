{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (import ../lib/ips.nix) ips;
in {
  imports = [../lib/secrets.nix];

  sops.templates."init-db.sql" = {
    content = ''
      CREATE USER admin WITH SUPERUSER PASSWORD '${config.sops.placeholder."postgresql/root"}';
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
      };

      # Secondary SFTP backup on kleiner
      kleiner = {
        type = "sftp";
        sftp-host-user = "jessew";
        path = "/mnt/HDD1/Backups/Infra/postgresql";
        sftp-private-key-file = config.sops.secrets."sftp/backup_private_key".path;
        sftp-host-key-check-type = "fingerprint";
        sftp-host-key-hash-type = "sha256";
        # ssh-keyscan -t ed25519 kleiner 2>/dev/null | ssh-keygen -lf - -E sha256
        # Use only the base64 part after "SHA256:"
        sftp-host-fingerprint = "7750d245a9dbf20611239c9a97c7aeca229058eb44d77f869fa57a1a88361bc5";
      };
    };

    stanzas.main = {
      instances.localhost = {
        path = config.services.postgresql.dataDir;
        user = "postgres";
      };

      jobs.full = {
        schedule = "daily";
        type = "full";
      };

      settings = {
        retention-full = 10;
        start-fast = true;
      };
    };

    settings = {
      process-max = 4;
      log-level-console = "warn";
      log-level-file = "off"; # journald captures all output
    };
  };

  # Inject S3 credentials into the scheduled backup service (runs as pgbackrest user).
  systemd.services.pgbackrest-main-full.serviceConfig.EnvironmentFile =
    config.sops.templates."pgbackrest-s3-env".path;

  # Inject S3 credentials into the postgresql service for archive-push via archive_command.
  systemd.services.postgresql.serviceConfig.EnvironmentFile =
    config.sops.templates."pgbackrest-s3-env".path;

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    initialScript = config.sops.templates."init-db.sql".path;

    authentication = ''
      # Managed by a Nix module
      host  all       all      127.0.0.1/32     scram-sha-256
      host  all       all      ::1/128          scram-sha-256
      # LAN network
      host  all       all      10.0.0.0/8        scram-sha-256
      host  all       all      10.147.19.243/32  scram-sha-256
      host  all       all      100.0.0.0/8  scram-sha-256
    '';

    settings = {
      port = 5432;

      # Override stanza name to main for legacy compat with old backup scripts
      archive_command = lib.mkForce ''${lib.getExe pkgs.pgbackrest} --stanza=main archive-push "%p"'';
      archive_mode = "on";
      archive_timeout = "300";

      # 10.147.19.243 is the zerotier IP; 100.111.130.114 is the tailscale IP
      listen_addresses = lib.mkForce "localhost,${ips.freeman},10.147.19.243,100.111.130.114";

      # pgtune: 4 GB RAM, 2 CPUs, 100 connections, web workload, SSD
      max_connections = "100";
      shared_buffers = "1GB";
      effective_cache_size = "3GB";
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
