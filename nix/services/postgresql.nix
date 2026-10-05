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
    immich = "postgresql/immich";
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

  # Major upgrades go through upgrade-postgresql (see DOCS.md): set `upgradeTo` to the next
  # version and deploy, run the script, then set services.postgresql.package to the same
  # version and deploy again. The script refuses to run once both match
  upgradeTo = pkgs.postgresql_18;
  upgradeExtensions = ps: [ps.vectorchord ps.pgvector];

  upgradePostgresql = let
    cfg = config.services.postgresql;
    # Built like the module's finalPackage, so the upgraded cluster runs the same binaries
    new = upgradeTo.withoutJIT.withPackages upgradeExtensions;
  in
    pkgs.writeShellApplication {
      name = "upgrade-postgresql";
      runtimeInputs = [pkgs.util-linux pkgs.systemd pkgs.coreutils];
      text = ''
        # upgrade-postgresql --check: dry run against the live cluster, changes nothing
        # upgrade-postgresql:         stops PostgreSQL and upgrades it with pg_upgrade --link
        old_data=${cfg.dataDir}
        old_bin=${cfg.finalPackage}/bin
        new_data=/var/lib/postgresql/${upgradeTo.psqlSchema}
        new_bin=${new}/bin

        if [ "$old_data" = "$new_data" ]; then
          echo "Already running PostgreSQL ${upgradeTo.psqlSchema}" >&2
          exit 1
        fi

        check=false
        if [ "''${1:-}" = --check ]; then
          check=true
          new_data=$(mktemp -d /var/lib/postgresql/upgrade-check.XXXXXX)
          trap 'rm -rf "$new_data"' EXIT
        else
          if [ -e "$new_data" ]; then
            echo "$new_data already exists" >&2
            exit 1
          fi
          systemctl stop postgresql.service
          mkdir "$new_data"
        fi
        chown postgres:postgres "$new_data"
        chmod 0750 "$new_data"

        as_postgres() {
          runuser -u postgres -- env LOCALE_ARCHIVE=/run/current-system/sw/lib/locale/locale-archive "$@"
        }

        # pg_upgrade needs the new cluster to match the old one's encoding, locale and
        # checksums (off here, while PostgreSQL 18 turns them on by default)
        as_postgres "$new_bin/initdb" -D "$new_data" -U ${cfg.superUser} \
          --encoding=UTF8 --locale=en_GB.UTF-8 --locale-provider=libc \
          --no-data-checksums ${lib.escapeShellArgs cfg.initdbArgs}

        cd "$new_data"
        if $check; then
          as_postgres "$new_bin/pg_upgrade" --check \
            -d "$old_data" -D "$new_data" -b "$old_bin" -B "$new_bin" \
            -p ${toString cfg.settings.port} -s /run/postgresql -U ${cfg.superUser}
        else
          as_postgres "$new_bin/pg_upgrade" --link \
            -d "$old_data" -D "$new_data" -b "$old_bin" -B "$new_bin" -U ${cfg.superUser}
        fi
      '';
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

      # archive-push fails whenever any repo fails, so that PostgreSQL keeps the WAL until
      # every repo has it. Synchronously, that also stops WAL from reaching the other repos:
      # kleiner being off for two weeks once left Fastly without WAL for two weeks. Async
      # pushes every pending segment to each repo independently, so only kleiner falls behind
      archive-async = true;
      spool-path = "/var/spool/pgbackrest";
      # Meanwhile PostgreSQL keeps the WAL. Past this much, pgbackrest drops it so the disk
      # doesn't fill up, and kleiner can't restore past that point until its next full backup.
      # Idle segments compress ~10x on ZFS, but busy ones don't, so it has to fit uncompressed
      archive-push-queue-max = "8GiB";
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
          # stanza-create checks every repo and can't be limited to one, so don't let an
          # unreachable kleiner stop the backups to Fastly ("-" ignores failures)
          ExecStartPre = lib.mkForce "-${lib.getExe pkgs.pgbackrest} --stanza=main stanza-create";
          ExecStart = lib.mkForce "${lib.getExe pkgs.pgbackrest} --stanza=main --repo=${toString job.repo} backup --type=${job.type}";
        };
      })
    backupJobs
    // {
      # S3 credentials for archive-push, through archive_command
      postgresql = {
        serviceConfig = {
          EnvironmentFile = config.sops.templates."pgbackrest-s3-env".path;
          # Async archive-push runs inside the service's sandbox
          ReadWritePaths = ["/var/spool/pgbackrest"];
        };
        # Stop before Tailscale on shutdown, so the last WAL can still reach kleiner
        after = ["tailscaled.service"];
      };

      # What the NixOS Immich module does for a local database: Immich's extensions, which
      # need a superuser, and reindexing its vector indexes when VectorChord changes version
      # (https://docs.immich.app/administration/postgres-standalone/#updating-vectorchord)
      immich-database-setup = let
        extensions = ["unaccent" "uuid-ossp" "cube" "earthdistance" "pg_trgm" "vector" "vchord"];
      in {
        description = "Set up Immich's PostgreSQL extensions";
        wantedBy = ["multi-user.target"];
        requires = ["postgresql-setup.service"];
        after = ["postgresql-setup.service"];
        path = [config.services.postgresql.finalPackage];
        environment.PGPORT = toString config.services.postgresql.settings.port;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "postgres";
          Group = "postgres";
        };
        script = ''
          psql -d immich -v ON_ERROR_STOP=1 <<'EOF'
            SELECT COALESCE(installed_version, ''') AS vchord_before FROM pg_available_extensions WHERE name = 'vchord' \gset
            ${lib.concatMapStringsSep "\n" (ext: "CREATE EXTENSION IF NOT EXISTS \"${ext}\";") extensions}
            ${lib.concatMapStringsSep "\n" (ext: "ALTER EXTENSION \"${ext}\" UPDATE;") extensions}
            ALTER SCHEMA public OWNER TO immich;
            SELECT COALESCE(installed_version, ''') AS vchord_after FROM pg_available_extensions WHERE name = 'vchord' \gset
            SELECT (:'vchord_before' != ''' AND :'vchord_before' != :'vchord_after') AS vchord_updated \gset
            \if :vchord_updated
              REINDEX INDEX face_index;
              REINDEX INDEX clip_index;
            \endif
          EOF
        '';
      };

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
    package = pkgs.postgresql_18;
    # Immich's vector search
    extensions = upgradeExtensions;
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

      # VectorChord has to be loaded at startup
      shared_preload_libraries = ["vchord"];

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

  environment.systemPackages = [upgradePostgresql];

  systemd.tmpfiles.rules = [
    # Lock directory for the backup jobs. PostgreSQL has a private /tmp, so archive-push uses
    # its own, which is fine as archiving and backups take different locks
    "d /tmp/pgbackrest 1777 root root -"
    # Spool for async archive-push, which runs as postgres
    "d /var/spool/pgbackrest 0750 postgres postgres -"
  ];
}
