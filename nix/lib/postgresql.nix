{
  pkgs,
  config,
  lib,
  ...
}: {
  # Need to use the "options" namespace to declare options
  options = {
    modules.postgresql = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable PostgreSQL service";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.postgresql_17;
        description = "PostgreSQL package to use";
      };

      root = {
        user = lib.mkOption {
          type = lib.types.str;
          description = "User to create for the root database";
        };
        password = lib.mkOption {
          type = lib.types.str;
          description = "Password for the root user";
        };
      };

      # Array of { name, user } objects
      databases = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Name of the database";
            };
            user = lib.mkOption {
              type = lib.types.str;
              description = "User to create for the database";
            };
            password = lib.mkOption {
              type = lib.types.str;
              description = "Password for the user";
            };
          };
        });
        default = [];
        description = ''
          List of databases/user combos to create on PostgreSQL startup.
        '';
      };
    };

    modules.pgbackrest = {
      repositories = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            repo_index = lib.mkOption {
              type = lib.types.int;
              description = "Index of the repository";
              default = 1;
            };
            s3_bucket = lib.mkOption {
              type = lib.types.str;
              description = "S3 bucket to use for pgbackrest backups";
            };
            s3_backups_path = lib.mkOption {
              type = lib.types.str;
              default = "backups";
              description = "Path in the S3 bucket to use for pgbackrest backups";
            };
            s3_region = lib.mkOption {
              type = lib.types.str;
              description = "Region of the S3 bucket";
            };
            s3_endpoint = lib.mkOption {
              type = lib.types.str;
              description = "Endpoint of the S3 bucket";
            };
            s3_access_key = lib.mkOption {
              type = lib.types.str;
              description = "Access key for the S3 bucket";
            };
            s3_secret_key = lib.mkOption {
              type = lib.types.str;
              description = "Secret key for the S3 bucket";
            };
          };
        });
        default = [];
        description = "S3 repositories configuration for pgbackrest backups";
      };

      retention = {
        full = lib.mkOption {
          type = lib.types.int;
          description = "Number of full backups to keep";
          default = 2;
        };
      };

      schedule = {
        full = lib.mkOption {
          type = lib.types.str;
          description = "Schedule for full backups (systemd calendar format)";
          default = "weekly";
        };
      };
    };
  };

  # Nix makes us use this namespace since we are also using the "options" namespace
  config = {
    sops.templates."init-db.sql" = {
      content = ''
        ${lib.concatMapStringsSep "\n" (db: ''
            CREATE DATABASE ${db.name};
            CREATE USER ${db.user} WITH PASSWORD '${db.password}';
            GRANT ALL PRIVILEGES ON DATABASE ${db.name} TO ${db.user};
            ALTER DATABASE ${db.name} OWNER TO ${db.user};
          '')
          config.modules.postgresql.databases}
        CREATE USER ${config.modules.postgresql.root.user} WITH SUPERUSER PASSWORD '${config.modules.postgresql.root.password}';
      '';
      owner = "postgres";
    };

    services.postgresql = {
      enable = config.modules.postgresql.enable;
      package = config.modules.postgresql.package;
      initialScript = config.sops.templates."init-db.sql".path;

      # Allow all local connections and password authentication on the network
      authentication = ''
        # Managed by a Nix modules
        # Only allow connections from localhost
        host  all       all      127.0.0.1/32     scram-sha-256
        host  all       all      ::1/128          scram-sha-256
        # Zerotier One network
        host  all       all      10.147.19.0/24   scram-sha-256
      '';

      settings = {
        # Enable WAL archiving (required for backups)
        archive_mode = "on";
        port = 5432;

        # We use pgbackrest to push the WAL files to the S3 bucket
        archive_command = "${pkgs.pgbackrest}/bin/pgbackrest --stanza=main archive-push %p";
        archive_timeout = "300";

        # Also add zerotier-one network to listen_addresses
        listen_addresses = lib.mkForce "localhost,10.147.19.243";

        # The following is generated by https://pgtune.leopard.in.ua
        # DB Version: 17
        # OS Type: linux
        # DB Type: web
        # Total Memory (RAM): 4 GB
        # CPUs num: 2
        # Connections num: 100
        # Data Storage: ssd
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

    sops.templates."pgbackrest.conf" = {
      owner = "postgres";

      content = let
        # Generates config for each repository
        mkRepoConfig = repo: ''
          repo${toString repo.repo_index}-type=s3
          repo${toString repo.repo_index}-s3-bucket=${repo.s3_bucket}
          repo${toString repo.repo_index}-s3-region=${repo.s3_region}
          repo${toString repo.repo_index}-path=${repo.s3_backups_path}
          repo${toString repo.repo_index}-s3-endpoint=${repo.s3_endpoint}
          repo${toString repo.repo_index}-s3-key=${repo.s3_access_key}
          repo${toString repo.repo_index}-s3-key-secret=${repo.s3_secret_key}
          repo${toString repo.repo_index}-s3-uri-style=path
        '';
        repos_config = lib.strings.concatMapStringsSep "\n" mkRepoConfig config.modules.pgbackrest.repositories;
      in ''
        [global]
        ${repos_config}
        process-max=4
        log-level-console=warn
        log-level-file=debug

        [main]
        pg1-path=/var/lib/postgresql/${config.services.postgresql.package.psqlSchema}
        pg1-port=${toString config.services.postgresql.settings.port}

        archive-async=y
        archive-push-queue-max=4GB
        retention-full=${toString config.modules.pgbackrest.retention.full}
        start-fast=y
      '';
    };

    # Pgbackrest doesn't have proper NixOS support, so we need to configure it manually
    environment.systemPackages = [pkgs.pgbackrest];

    environment.etc."pgbackrest/pgbackrest.conf" = {
      source = config.sops.templates."pgbackrest.conf".path;
      user = "postgres";
      mode = "0600";
    };

    systemd.services.pgbackrest-full-backup = {
      description = "pgBackRest Full Backup Service";
      after = ["postgresql.service"];
      requires = ["postgresql.service"];
      path = [pkgs.pgbackrest];

      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        Group = "postgres";
      };

      script = ''
        if ! pgbackrest info; then
            pgbackrest --stanza=main stanza-create
        fi
        pgbackrest --stanza=main --type=full backup
      '';
    };

    systemd.timers.pgbackrest-full-backup = {
      description = "Timer for pgBackRest Full Backup";
      wantedBy = ["timers.target"];

      timerConfig = {
        OnCalendar = config.modules.pgbackrest.schedule.full;
        Persistent = true;
      };
    };

    # Create a couple of directories for pgbackrest to work
    systemd.tmpfiles.rules = [
      # pgbackrest logs
      "d /var/log/pgbackrest 0700 postgres postgres -"
      # pgbackrest transient data
      "d /var/spool/pgbackrest 0700 postgres postgres -"
    ];
  };
}
