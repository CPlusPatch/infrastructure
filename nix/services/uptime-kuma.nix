{config, ...}: {
  services.uptime-kuma = {
    enable = true;
    settings = {
      UPTIME_KUMA_PORT = "6001";
    };
  };

  # /var/lib/uptime-kuma is a symlink (DynamicUser), which restic would store as-is
  services.backups.jobs.uptime_kuma.source = "/var/lib/private/uptime-kuma";

  modules.haproxy.vhosts.uptime_kuma = {
    domain = "status.cpluspatch.com";
    server = "127.0.0.1:${toString config.services.uptime-kuma.settings.UPTIME_KUMA_PORT}";
  };
}
