{config, ...}: let
  image = ../../assets/nexus.png;
in {
  services.nginx.virtualHosts."pissing.nexus" = {
    locations."/" = {
      root = "/";
      tryFiles = "${image} =404";
    };
  };

  modules.haproxy.acls.nexus = ''
    acl is_nexus hdr(host) -i pissing.nexus
    use_backend nexus if is_nexus
  '';

  modules.haproxy.backends.nexus = ''
    backend nexus
      server nexus 127.0.0.1:${toString config.services.nginx.defaultHTTPListenPort}
  '';

  security.acme.certs."pissing.nexus" = {};
}
