{
  config,
  pkgs,
  ...
}: {
  imports = [../packages/pages/import.mod.nix];

  services.nginx.virtualHosts."static.cpluspatch.com" = {
    # Serve all of pkgs.cpluspatch-pages/
    locations."/pages/" = {
      alias = "${pkgs.cpluspatch-pages}/";

      # Enable CORS
      extraConfig = ''
        add_header 'Access-Control-Allow-Origin' '*';
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
        add_header 'Access-Control-Allow-Headers' 'Content-Type';
      '';
    };
  };

  modules.haproxy.acls.static = ''
    acl is_static hdr(host) -i static.cpluspatch.com
    use_backend static if is_static
  '';

  modules.haproxy.backends.static = ''
    backend static
      server static 127.0.0.1:${toString config.services.nginx.defaultHTTPListenPort}
  '';

  security.acme.certs."static.cpluspatch.com" = {};
}
