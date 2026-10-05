{
  config,
  infra,
  ...
}: {
  services.keycloak = {
    enable = true;

    database = {
      type = "postgresql";
      username = "keycloak";
      passwordFile = config.sops.secrets."postgresql/keycloak".path;
      name = "keycloak";
      # Address of freeman through the VPN
      host = infra.ips.freeman;
      useSSL = false;
      createLocally = false;
    };

    settings = {
      hostname = "https://id.cpluspatch.com";
      http-host = "localhost";
      http-port = 6000;
      http-enabled = true;
      proxy-headers = "xforwarded";
    };
  };

  systemd.services.keycloak.serviceConfig = {
    Restart = "always";
    TimeoutSec = 60;
  };

  modules.haproxy.vhosts.keycloak = {
    domain = "id.cpluspatch.com";
    server = "127.0.0.1:${toString config.services.keycloak.settings.http-port}";
    extraRules = ''
      http-request redirect location /realms/default/account/ if { hdr(host) -i id.cpluspatch.com } { path / }
    '';
  };
}
