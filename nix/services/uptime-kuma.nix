{config, ...}: {
  services.uptime-kuma = {
    enable = true;
    settings = {
      UPTIME_KUMA_PORT = "6001";
    };
  };

  services.backups.jobs.uptime_kuma.source = "/var/lib/uptime-kuma";

  modules.haproxy.vhosts.uptime_kuma = {
    domain = "status.cpluspatch.com";
    server = "127.0.0.1:${toString config.services.uptime-kuma.settings.UPTIME_KUMA_PORT}";
  };
}
