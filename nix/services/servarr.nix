{config, ...}: {
  imports = [
    ../secrets/servarr.nix

    ../modules/backups.nix
  ];

  services.radarr = {
    enable = true;
  };

  services.prometheus.exporters.exportarr-radarr = {
    enable = true;
    port = 9708;
    url = "https://radarr.lgs.cpluspatch.com";
    apiKeyFile = config.sops.secrets."radarr/key".path;
  };

  modules.haproxy.acls.radarr = ''
    acl is_radarr hdr(host) -i radarr.lgs.cpluspatch.com
    use_backend radarr if is_radarr
  '';

  modules.haproxy.backends.radarr = ''
    backend radarr
      server radarr 127.0.0.1:7878
  '';

  security.acme.certs."radarr.lgs.cpluspatch.com" = {};

  services.backups.jobs.radarr.source = "/var/lib/radarr";

  services.prowlarr = {
    enable = true;
  };

  services.prometheus.exporters.exportarr-prowlarr = {
    enable = true;
    port = 9709;
    url = "https://prowlarr.lgs.cpluspatch.com";
    apiKeyFile = config.sops.secrets."prowlarr/key".path;
  };

  modules.haproxy.acls.prowlarr = ''
    acl is_prowlarr hdr(host) -i prowlarr.lgs.cpluspatch.com
    use_backend prowlarr if is_prowlarr
  '';

  modules.haproxy.backends.prowlarr = ''
    backend prowlarr
      server prowlarr 127.0.0.1:9696
  '';

  security.acme.certs."prowlarr.lgs.cpluspatch.com" = {};

  services.backups.jobs.prowlarr.source = "/var/lib/prowlarr";

  services.sonarr = {
    enable = true;
  };

  services.prometheus.exporters.exportarr-sonarr = {
    enable = true;
    port = 9710;
    url = "https://sonarr.lgs.cpluspatch.com";
    apiKeyFile = config.sops.secrets."sonarr/key".path;
  };

  modules.haproxy.acls.sonarr = ''
    acl is_sonarr hdr(host) -i sonarr.lgs.cpluspatch.com
    use_backend sonarr if is_sonarr
  '';

  modules.haproxy.backends.sonarr = ''
    backend sonarr
      server sonarr 127.0.0.1:8989
  '';

  security.acme.certs."sonarr.lgs.cpluspatch.com" = {};

  services.backups.jobs.sonarr.source = "/var/lib/sonarr";

  services.flaresolverr = {
    enable = false;
    port = 8191;
  };
}
