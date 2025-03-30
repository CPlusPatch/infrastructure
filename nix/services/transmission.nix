{
  pkgs,
  config,
  ...
}: {
  sops.templates."transmission.json" = {
    content = ''
      {
          "rpc-password": "${config.sops.placeholder."transmission/password"}"
      }
    '';
  };

  services.transmission = {
    enable = true;
    performanceNetParameters = true;
    package = pkgs.transmission_4;
    openPeerPorts = true;
    credentialsFile = config.sops.templates."transmission.json".path;
    webHome = pkgs.flood-for-transmission;

    settings = {
      rpc-bind-address = "localhost";
      download-dir = "/mnt/fs-01b/torrents/downloads";
      rpc-authentication-required = true;
      rpc-username = "admin";
    };
  };

  modules.haproxy.acls.transmission = ''
    acl is_transmission hdr(host) -i dl.lgs.cpluspatch.com
    use_backend transmission if is_transmission
    http-request auth if is_transmission !{ http_auth(credentials) }
  '';

  modules.haproxy.backends.transmission = ''
    backend transmission
      server transmission 127.0.0.1:${toString config.services.transmission.settings.rpc-port}
  '';

  security.acme.certs."dl.lgs.cpluspatch.com" = {};
}
