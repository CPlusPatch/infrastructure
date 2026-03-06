{...}: {
  services.influxdb = {
    enable = true;
    settings = {
      index-version = "tsi1";
    };
  };
}
