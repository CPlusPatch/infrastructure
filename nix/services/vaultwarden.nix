{config, ...}: let
  ips = import ../lib/zerotier-ips.nix;
in {
  sops.templates."vaultwarden.env" = {
    content = ''
      DATABASE_URL=postgresql://vaultwarden:${config.sops.placeholder."postgresql/vaultwarden"}@${ips.zerotier-ips.freeman}/vaultwarden
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

  modules.haproxy.acls.vaultwarden = ''
    acl is_vaultwarden hdr(host) -i vault.cpluspatch.com
    use_backend vaultwarden if is_vaultwarden
  '';

  modules.haproxy.backends.vaultwarden = ''
    backend vaultwarden
      server vaultwarden 127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}
  '';

  security.acme.certs."vault.cpluspatch.com" = {};
}
