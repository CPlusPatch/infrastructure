{...}: {
  services.influxdb = {
    enable = true;
    extraConfig = {
      index-version = "tsi1";
    };
  };
}
