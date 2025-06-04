{config, ...}: {
  imports = [
    ../modules/backups.nix
  ];

  services.uptime-kuma = {
    enable = true;
    settings = {
      UPTIME_KUMA_PORT = "6001";
    };
  };

  modules.haproxy.acls.uptime-kuma = ''
    acl is_uptime_kuma hdr(host) -i status.cpluspatch.com
    use_backend uptime_kuma if is_uptime_kuma
  '';

  modules.haproxy.backends.uptime-kuma = ''
    backend uptime_kuma
      server uptime_kuma 127.0.0.1:${toString config.services.uptime-kuma.settings.UPTIME_KUMA_PORT}
  '';

  security.acme.certs."status.cpluspatch.com" = {};

  services.backups.jobs.uptime_kuma.source = "/var/lib/uptime-kuma";
}
