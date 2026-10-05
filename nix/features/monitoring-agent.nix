# Exposes host metrics to Prometheus on freeman, over the private network
{
  config,
  infra,
  ...
}: {
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = infra.ips.${config.networking.hostName};
    # systemd: failed units and backup timers. zfs: pool health and ARC (enabled by default)
    enabledCollectors = ["systemd"];
  };

  # Cap logs, journald deletes the oldest entries when over the limits
  services.journald.settings.Journal = {
    SystemMaxUse = "500M";
    SystemKeepFree = "2G";
    MaxRetentionSec = "1month";
  };
}
