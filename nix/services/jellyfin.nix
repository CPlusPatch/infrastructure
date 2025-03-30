{
  services.jellyfin = {
    enable = true;
  };

  modules.haproxy.acls.jellyfin = ''
    acl is_jellyfin hdr(host) -i stream.cpluspatch.com
    use_backend jellyfin if is_jellyfin
  '';

  modules.haproxy.backends.jellyfin = ''
    backend jellyfin
      server jellyfin 127.0.0.1:8096
  '';

  security.acme.certs."stream.cpluspatch.com" = {};
}
