{
  services.prowlarr = {
    enable = true;
  };

  services.backups.jobs.prowlarr.source = "/var/lib/prowlarr";

  modules.haproxy.vhosts.prowlarr = {
    domain = "prowlarr.lgs.cpluspatch.com";
    server = "127.0.0.1:9696";
  };
}
