# Monitoring: Prometheus, blackbox probes and Alertmanager, alerting to ntfy
{
  config,
  lib,
  infra,
  nodes,
  ...
}: let
  inherit (infra) ips;
  cfg = config.services.prometheus;
  faithplate = nodes.faithplate.config;
  minecraftPort = nodes.eli.config.services.minecraft-servers.servers.wiki.serverProperties.server-port;
  synapseMetricsPort = (lib.findFirst (listener: listener.type == "metrics") null faithplate.services.matrix-synapse.settings.listeners).port;
  mailHost = faithplate.mailserver.fqdn;

  # Each probe opens a connection (most with a TLS handshake), so probe less often than the
  # default 15s scrape interval
  probeInterval = "20s";

  # Probes through the blackbox exporter, labelled by target
  blackboxRelabel = [
    {
      source_labels = ["__address__"];
      target_label = "__param_target";
    }
    {
      source_labels = ["__param_target"];
      target_label = "instance";
      regex = "(?:https://)?(.*)";
    }
    {
      target_label = "__address__";
      replacement = "127.0.0.1:${toString cfg.exporters.blackbox.port}";
    }
  ];

  # Redis servers, scraped through the exporter's multi-target endpoint
  redisTargets = lib.mapAttrsToList (name: server: "redis://${server.bind}:${toString server.port}") (
    lib.filterAttrs (name: server: server.enable) config.services.redis.servers
  );

  # HTTPS services on faithplate, from its HAProxy vhosts
  probedDomains = lib.sort lib.lessThan (
    lib.mapAttrsToList (name: vhost: vhost.domain) faithplate.modules.haproxy.vhosts
    ++ ["matrix.cpluspatch.dev"]
  );

  # ntfy formats Alertmanager's webhook payload with these templates. The topic is secret
  ntfyTemplates = {
    tpl = "yes";
    t = ''{{if eq .status "resolved"}}✅ Resolved: {{.commonLabels.alertname}}{{else}}{{if eq .commonLabels.severity "critical"}}🚨{{else}}⚠️{{end}} {{.commonLabels.alertname}}{{if gt (len .alerts) 1}} ({{len .alerts}}){{end}}{{end}}'';
    m =
      ''{{range .alerts}}{{if eq .status "resolved"}}✓{{else}}•{{end}} {{.annotations.summary}}{{if .annotations.description}}''
      + "\n  "
      + ''{{.annotations.description}}{{end}}''
      + "\n"
      + ''{{end}}'';
    p = ''{{if eq .status "resolved"}}2{{else if eq .commonLabels.severity "critical"}}5{{else}}3{{end}}'';
  };
  ntfyQuery = lib.concatStringsSep "&" (lib.mapAttrsToList (k: v: "${k}=${lib.escapeURL v}") ntfyTemplates);

  # Available memory including ZFS' cache above its minimum, which ZFS frees under pressure
  # but the kernel doesn't count in MemAvailable
  memAvailable = "(node_memory_MemAvailable_bytes + clamp_min(node_zfs_arc_size - node_zfs_arc_c_min, 0))";

  # Excludes pseudo and network filesystems that come and go
  realFs = ''fstype!~"tmpfs|ramfs|squashfs|overlay|autofs|cifs|fuse.*",mountpoint!~"/run.*|/var/lib/docker.*|/nix/store|/[.]zfs/.*"'';

  rules = [
    {
      name = "hosts";
      rules = [
        {
          alert = "HostDown";
          expr = ''up{job="node"} == 0'';
          for = "3m";
          labels.severity = "critical";
          annotations.summary = "{{ $labels.instance }} is unreachable";
          annotations.description = "Prometheus can't scrape its node exporter";
        }
        {
          alert = "ScrapeTargetDown";
          expr = ''up{job!="node"} == 0'';
          for = "10m";
          labels.severity = "warning";
          annotations.summary = "{{ $labels.job }} metrics unavailable ({{ $labels.instance }})";
        }
        {
          alert = "DiskSpaceLow";
          expr = "node_filesystem_avail_bytes{${realFs}} / node_filesystem_size_bytes < 0.15";
          for = "10m";
          labels.severity = "warning";
          annotations.summary = "{{ $labels.instance }}: {{ $labels.mountpoint }} is almost full";
          annotations.description = "{{ $value | humanizePercentage }} free";
        }
        {
          alert = "DiskSpaceCritical";
          expr = "node_filesystem_avail_bytes{${realFs}} / node_filesystem_size_bytes < 0.05";
          for = "5m";
          labels.severity = "critical";
          annotations.summary = "{{ $labels.instance }}: {{ $labels.mountpoint }} is full";
          annotations.description = "{{ $value | humanizePercentage }} free";
        }
        {
          alert = "DiskFillsWithin24h";
          expr = "predict_linear(node_filesystem_avail_bytes{${realFs}}[6h], 86400) < 0 and node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.3";
          for = "1h";
          labels.severity = "warning";
          annotations.summary = "{{ $labels.instance }}: {{ $labels.mountpoint }} will be full within a day at its current rate";
        }
        {
          # Processes are spending time waiting for memory (pressure stall information).
          # Low available memory or full swap alone are normal, e.g. with Minecraft's fixed heap
          alert = "MemoryPressure";
          expr = "rate(node_pressure_memory_waiting_seconds_total[5m]) > 0.1";
          for = "15m";
          labels.severity = "warning";
          annotations.summary = "{{ $labels.instance }} is short on memory";
          annotations.description = "Processes spent {{ $value | humanizePercentage }} of their time waiting for memory";
        }
        {
          alert = "MemoryAlmostExhausted";
          expr = "${memAvailable} / node_memory_MemTotal_bytes < 0.02";
          for = "5m";
          labels.severity = "critical";
          annotations.summary = "{{ $labels.instance }} is about to run out of memory";
          annotations.description = "{{ $value | humanizePercentage }} available";
        }
        {
          alert = "HighCpu";
          expr = ''1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) > 0.9'';
          for = "30m";
          labels.severity = "warning";
          annotations.summary = "{{ $labels.instance }} CPU busy for 30 minutes";
          annotations.description = "{{ $value | humanizePercentage }} used";
        }
        {
          alert = "ZfsPoolUnhealthy";
          expr = ''node_zfs_zpool_state{state!="online"} == 1'';
          labels.severity = "critical";
          annotations.summary = "{{ $labels.instance }}: ZFS pool {{ $labels.zpool }} is {{ $labels.state }}";
        }
      ];
    }
    {
      name = "services";
      rules = [
        {
          alert = "UnitFailed";
          expr = ''node_systemd_unit_state{state="failed"} == 1'';
          for = "1m";
          labels.severity = "warning";
          annotations.summary = "{{ $labels.name }} failed on {{ $labels.instance }}";
          annotations.description = "journalctl -u {{ $labels.name }}";
        }
        {
          alert = "BackupStale";
          # Timers that never ran report 0. Full PostgreSQL backups are weekly, the rest daily
          expr = ''
            (time() - node_systemd_timer_last_trigger_seconds{name=~"(restic-backups-|pgbackrest-main-incr|postgresqlBackup).*"} > 36 * 3600
              or time() - node_systemd_timer_last_trigger_seconds{name=~"pgbackrest-main-full.*"} > 8 * 86400)
            and node_systemd_timer_last_trigger_seconds > 0
          '';
          labels.severity = "warning";
          annotations.summary = "{{ $labels.name }} hasn't run for {{ $value | humanizeDuration }} on {{ $labels.instance }}";
        }
        {
          alert = "RedisDown";
          expr = "redis_up == 0";
          for = "2m";
          labels.severity = "critical";
          annotations.summary = "Redis {{ $labels.instance }} is down";
        }
        {
          # A segment is archived at least every 5 minutes (archive_timeout). Usually means a
          # pgbackrest repo is unreachable: PostgreSQL keeps the WAL meanwhile, and drops it
          # for that repo after archive-push-queue-max
          alert = "WalArchivingStalled";
          expr = "pg_stat_archiver_last_archive_age > 1800";
          labels.severity = "warning";
          annotations.summary = "PostgreSQL hasn't archived WAL for {{ $value | humanizeDuration }} on {{ $labels.instance }}";
          annotations.description = "journalctl -u postgresql | grep -A1 'archive-push command encountered'";
        }
        {
          alert = "PostgresDown";
          expr = "pg_up == 0";
          for = "2m";
          labels.severity = "critical";
          annotations.summary = "PostgreSQL is down on {{ $labels.instance }}";
        }
      ];
    }
    {
      name = "endpoints";
      rules = [
        {
          alert = "EndpointDown";
          expr = "probe_success == 0";
          for = "5m";
          labels.severity = "critical";
          annotations.summary = "{{ $labels.instance }} is down";
          annotations.description = "Probed from freeman";
        }
        {
          alert = "CertificateExpiringSoon";
          expr = "(probe_ssl_earliest_cert_expiry - time()) / 86400 < 14";
          for = "1h";
          labels.severity = "warning";
          annotations.summary = "Certificate for {{ $labels.instance }} expires in {{ $value | humanize }} days";
          annotations.description = "ACME renews certificates 30 days before expiry, so renewal is failing";
        }
      ];
    }
  ];
in {
  sops.templates."alertmanager.env".content = ''
    NTFY_TOPIC=${config.sops.placeholder."ntfy/topic"}
  '';

  services.prometheus = {
    enable = true;

    globalConfig = {
      scrape_interval = "15s";
      evaluation_interval = "15s";
    };

    retentionTime = "90d";
    extraFlags = ["--storage.tsdb.retention.size=5GB"];

    scrapeConfigs = [
      {
        job_name = "node";
        # Labelled by hostname instead of address
        static_configs =
          lib.mapAttrsToList (host: ip: {
            targets = ["${ip}:${toString cfg.exporters.node.port}"];
            labels.instance = host;
          })
          ips;
      }
      {
        job_name = "haproxy";
        static_configs = [
          {
            targets = ["${ips.faithplate}:${toString faithplate.modules.haproxy.metrics.port}"];
            labels.instance = "faithplate";
          }
        ];
      }
      {
        job_name = "postgres";
        static_configs = [
          {
            targets = ["localhost:${toString cfg.exporters.postgres.port}"];
            labels.instance = "freeman";
          }
        ];
      }
      {
        # Labels expected by Synapse's official dashboard
        job_name = "synapse";
        static_configs = [
          {
            targets = ["${ips.faithplate}:${toString synapseMetricsPort}"];
            labels = {
              instance = "cpluspatch.dev";
              job = "master";
              index = "1";
            };
          }
        ];
      }
      {
        job_name = "clickhouse";
        static_configs = [
          {
            targets = ["${ips.freeman}:${toString config.services.clickhouse.serverConfig.prometheus.port}"];
            labels.instance = "freeman";
          }
        ];
      }
      {
        job_name = "redis";
        metrics_path = "/scrape";
        static_configs = [{targets = redisTargets;}];
        relabel_configs = [
          {
            source_labels = ["__address__"];
            target_label = "__param_target";
          }
          {
            source_labels = ["__param_target"];
            target_label = "instance";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:${toString cfg.exporters.redis.port}";
          }
        ];
      }
      {
        job_name = "blackbox-https";
        scrape_interval = probeInterval;
        metrics_path = "/probe";
        params.module = ["https"];
        static_configs = [{targets = map (domain: "https://${domain}") probedDomains;}];
        relabel_configs = blackboxRelabel;
      }
      {
        job_name = "blackbox-tcp";
        scrape_interval = probeInterval;
        metrics_path = "/probe";
        params.module = ["tcp"];
        static_configs = [{targets = ["mc.cpluspatch.com:${toString minecraftPort}"];}];
        relabel_configs = blackboxRelabel;
      }
      {
        # Submission and IMAP over TLS, which also checks the mail certificate
        job_name = "blackbox-tls";
        scrape_interval = probeInterval;
        metrics_path = "/probe";
        params.module = ["tls"];
        static_configs = [{targets = ["${mailHost}:465" "${mailHost}:993"];}];
        relabel_configs = blackboxRelabel;
      }
      {
        # Incoming mail. Over the private network, as Hetzner can block outgoing port 25
        job_name = "blackbox-smtp";
        scrape_interval = probeInterval;
        metrics_path = "/probe";
        params.module = ["smtp_starttls"];
        static_configs = [
          {
            targets = ["${ips.faithplate}:25"];
            labels.instance = "${mailHost}:25";
          }
        ];
        relabel_configs = [
          {
            source_labels = ["__address__"];
            target_label = "__param_target";
          }
          {
            target_label = "__address__";
            replacement = "127.0.0.1:${toString cfg.exporters.blackbox.port}";
          }
        ];
      }
    ];

    rules = [(builtins.toJSON {groups = rules;})];

    alertmanagers = [
      {
        static_configs = [{targets = ["127.0.0.1:${toString cfg.alertmanager.port}"];}];
      }
    ];

    alertmanager = {
      enable = true;
      listenAddress = "127.0.0.1";
      environmentFile = config.sops.templates."alertmanager.env".path;

      configuration = {
        route = {
          receiver = "ntfy";
          group_by = ["alertname"];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "12h";
        };

        # Don't report everything else on a host that is down
        inhibit_rules = [
          {
            source_matchers = [''alertname="HostDown"''];
            target_matchers = [''alertname!="HostDown"''];
            equal = ["instance"];
          }
        ];

        receivers = [
          {
            name = "ntfy";
            webhook_configs = [
              {
                # Substituted by envsubst when Alertmanager starts
                url = "https://ntfy.sh/\${NTFY_TOPIC}?${ntfyQuery}";
                send_resolved = true;
              }
            ];
          }
        ];
      };
    };

    exporters = {
      redis = {
        enable = true;
        listenAddress = "127.0.0.1";
        # Passwords by Redis URL, for the multi-target endpoint
        extraFlags = ["--redis.password-file=%d/passwords"];
      };

      postgres = {
        enable = true;
        runAsLocalSuperUser = true;
        # The 50 most expensive queries, from pg_stat_statements (see postgresql.nix)
        extraFlags = [
          "--collector.stat_statements"
          "--collector.stat_statements.include_query"
          "--collector.stat_statements.limit=50"
        ];
      };

      blackbox = {
        enable = true;
        listenAddress = "127.0.0.1";
        configFile = builtins.toFile "blackbox.yml" (builtins.toJSON {
          modules = {
            https = {
              prober = "http";
              timeout = "10s";
              http = {
                # Only checks that the service answers: redirects and auth prompts are fine,
                # HAProxy errors (5xx) and connection failures are not
                no_follow_redirects = true;
                valid_status_codes = [200 201 204 301 302 303 307 308 401 403 404 405];
                fail_if_not_ssl = true;
              };
            };
            tcp = {
              prober = "tcp";
              timeout = "10s";
            };
            tls = {
              prober = "tcp";
              timeout = "10s";
              tcp.tls = true;
            };
            smtp_starttls = {
              prober = "tcp";
              timeout = "10s";
              tcp = {
                tls_config.server_name = mailHost;
                query_response = [
                  {expect = "^220 ";}
                  {send = "EHLO prober\r";}
                  {expect = "^250[ -]STARTTLS";}
                  {send = "STARTTLS\r";}
                  {expect = "^220 ";}
                  {starttls = true;}
                  {send = "EHLO prober\r";}
                  {expect = "^250 ";}
                  {send = "QUIT\r";}
                ];
              };
            };
          };
        });
      };
    };
  };

  sops.templates."redis-exporter-passwords.json".content = builtins.toJSON (
    lib.mapAttrs' (name: server: {
      name = "redis://${server.bind}:${toString server.port}";
      value = config.sops.placeholder."redis/${name}";
    })
    (lib.filterAttrs (name: server: server.enable) config.services.redis.servers)
  );

  # The exporter runs with a dynamic user, so it gets the file as a credential
  systemd.services.prometheus-redis-exporter.serviceConfig.LoadCredential = "passwords:${config.sops.templates."redis-exporter-passwords.json".path}";

  # Prometheus' data isn't backed up: compaction rewrites its blocks every day, which would add
  # ~300 MB per repository per day of metrics that are only useful while recent
}
