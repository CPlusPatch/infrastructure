{lib, ...}: {
  imports = [
    ../modules/backups.nix
  ];

  services.jellyfin = {
    enable = true;
  };

  systemd.services.jellyfin.serviceConfig = {
    Restart = lib.mkForce "always";
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

  services.backups.jobs.jellyfin.source = "/var/lib/jellyfin";
}
