{
  config,
  pkgs,
  ...
}: let
  inherit (import ../lib/ips.nix) ips;
in {
  imports = [
    ./keycloak-themes
    ../secrets/postgresql/keycloak.nix
  ];

  services.keycloak = {
    enable = true;

    database = {
      type = "postgresql";
      username = "keycloak";
      passwordFile = config.sops.secrets."postgresql/keycloak".path;
      name = "keycloak";
      # Address of freeman through the VPN
      host = ips.freeman;
      useSSL = false;
      createLocally = false;
    };

    themes = with pkgs; {
      keywind = custom_keycloak_themes.keywind;
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

  modules.haproxy.acls.keycloak = ''
    acl is_keycloak hdr(host) -i id.cpluspatch.com
    use_backend keycloak if is_keycloak
  '';

  modules.haproxy.backends.keycloak = ''
    backend keycloak
      server keycloak 127.0.0.1:${toString config.services.keycloak.settings.http-port}
  '';

  security.acme.certs."id.cpluspatch.com" = {};
}
