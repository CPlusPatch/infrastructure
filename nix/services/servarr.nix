{
  services.prowlarr = {
    enable = true;
  };

  # /var/lib/prowlarr is a symlink (DynamicUser), which restic would store as-is
  services.backups.jobs.prowlarr.source = "/var/lib/private/prowlarr";

  modules.haproxy.vhosts.prowlarr = {
    domain = "prowlarr.lgs.cpluspatch.com";
    server = "127.0.0.1:9696";
  };
}
