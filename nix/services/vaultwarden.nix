{
  config,
  infra,
  ...
}: {
  sops.templates."vaultwarden.env" = {
    content = ''
      DATABASE_URL=postgresql://vaultwarden:${config.sops.placeholder."postgresql/vaultwarden"}@${infra.ips.freeman}/vaultwarden
    '';
    owner = "vaultwarden";
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "postgresql";
    environmentFile = config.sops.templates."vaultwarden.env".path;
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      DOMAIN = "https://vault.cpluspatch.com";
      SIGNUPS_ALLOWED = false;
    };
  };

  services.backups.jobs.vaultwarden.source = "/var/lib/vaultwarden";

  modules.haproxy.vhosts.vaultwarden = {
    domain = "vault.cpluspatch.com";
    server = "127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
  };
}
