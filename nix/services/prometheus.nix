{config, ...}: {
  services.prometheus = {
    enable = true;

    globalConfig = {
      scrape_interval = "15s";
    };

    scrapeConfigs = [
      {
        job_name = "traefik";
        static_configs = [
          {targets = ["10.147.19.130:8899"];}
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
          {targets = ["10.147.19.130:${toString config.services.prometheus.exporters.exportarr-sonarr.port}"];}
        ];
      }
      {
        job_name = "radarr";
        static_configs = [
          {targets = ["10.147.19.130:${toString config.services.prometheus.exporters.exportarr-radarr.port}"];}
        ];
      }
      {
        job_name = "prowlarr";
        static_configs = [
          {targets = ["10.147.19.130:${toString config.services.prometheus.exporters.exportarr-prowlarr.port}"];}
        ];
      }
      {
        job_name = "synapse";
        static_configs = [
          {targets = ["10.147.19.130:9000"];}
        ];
      }
      # TODO: Add synapse, docker and jellyfin
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
}
