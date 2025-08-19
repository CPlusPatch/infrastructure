{...}: {
  imports = [
    ../modules/backups.nix
  ];

  services.nzbget = {
    enable = true;

    settings = {
      MainDir = "/var/lib/nzbget";
      DestDir = "/mnt/fs-01b/usenet/downloads";
      FormAuth = "yes";
      ControlPassword = "";
    };
  };

  services.backups.jobs.nzbget.source = "/var/lib/nzbget";

  modules.haproxy.acls.nzbget = ''
    acl is_nzbget hdr(host) -i nzb.cpluspatch.com
    http-request auth if is_nzbget !{ http_auth(credentials) }
    use_backend nzbget if is_nzbget
  '';

  modules.haproxy.backends.nzbget = ''
    backend nzbget
      server nzbget 127.0.0.1:6789
  '';

  security.acme.certs."nzb.cpluspatch.com" = {};
}
