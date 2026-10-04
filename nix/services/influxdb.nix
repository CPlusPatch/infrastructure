{config, ...}: {
  services.influxdb = {
    enable = true;
    settings = {
      index-version = "tsi1";
    };
  };

  services.backups.jobs.influxdb.source = config.services.influxdb.dataDir;
}
