{
  imports = [
    ../modules/backups.nix
  ];

  services.prowlarr = {
    enable = true;
  };

  modules.haproxy.acls.prowlarr = ''
    acl is_prowlarr hdr(host) -i prowlarr.lgs.cpluspatch.com
    use_backend prowlarr if is_prowlarr
  '';

  modules.haproxy.backends.prowlarr = ''
    backend prowlarr
      server prowlarr 127.0.0.1:9696
  '';

  security.acme.certs."prowlarr.lgs.cpluspatch.com" = {};

  services.backups.jobs.prowlarr.source = "/var/lib/prowlarr";
}
