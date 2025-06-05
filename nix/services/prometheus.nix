{config, ...}: let
  inherit (import ../lib/ips.nix) ips;
in {
  imports = [
    ../modules/backups.nix
  ];

  services.prometheus = {
    enable = true;

    globalConfig = {
      scrape_interval = "15s";
    };

    scrapeConfigs = [
      {
        job_name = "haproxy";
        static_configs = [
          {targets = ["${ips.faithplate}:8899"];}
        ];
      }
      {
        job_name = "postgres";
        static_configs = [
          {targets = ["localhost:${toString config.services.prometheus.exporters.postgres.port}"];}
        ];
      }
      {
        job_name = "zfs";
        static_configs = [
          {targets = ["localhost:${toString config.services.prometheus.exporters.zfs.port}"];}
        ];
      }
      {
        job_name = "node";
        static_configs = [
          {targets = ["localhost:${toString config.services.prometheus.exporters.node.port}"];}
        ];
      }
      {
        job_name = "sonarr";
        static_configs = [
          {targets = ["${ips.faithplate}:${toString config.services.prometheus.exporters.exportarr-sonarr.port}"];}
        ];
      }
      {
        job_name = "radarr";
        static_configs = [
          {targets = ["${ips.faithplate}:${toString config.services.prometheus.exporters.exportarr-radarr.port}"];}
        ];
      }
      {
        job_name = "prowlarr";
        static_configs = [
          {targets = ["${ips.faithplate}:${toString config.services.prometheus.exporters.exportarr-prowlarr.port}"];}
        ];
      }
      {
        job_name = "synapse";
        static_configs = [
          {
            targets = ["${ips.faithplate}:9000"];
            labels = {
              instance = "cpluspatch.dev";
              job = "master";
              index = "1";
            };
          }
          {
            targets = ["${ips.faithplate}:9001"];
            labels = {
              instance = "cpluspatch.dev";
              job = "generic_worker";
              index = "1";
            };
          }
          {
            targets = ["${ips.faithplate}:9002"];
            labels = {
              instance = "cpluspatch.dev";
              job = "generic_worker";
              index = "2";
            };
          }
        ];
      }
      {
        job_name = "nextcloud";
        static_configs = [
          {targets = ["${ips.faithplate}:${toString config.services.prometheus.exporters.nextcloud.port}"];}
        ];
      }
      {
        job_name = "varnish";
        static_configs = [
          {targets = ["${ips.faithplate}:${toString config.services.prometheus.exporters.varnish.port}"];}
        ];
      }
    ];

    exporters = {
      node = {
        enable = true;
        disabledCollectors = [
          "textfile"
        ];
      };

      postgres = {
        enable = true;
        runAsLocalSuperUser = true;
      };

      zfs = {
        enable = true;
      };
    };
  };

  services.backups.jobs.prometheus.source = "/var/lib/prometheus2";
}
