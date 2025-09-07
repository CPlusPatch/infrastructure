{
  config,
  lib,
  ...
}: let
  inherit (import ../lib/ips.nix) ips;
in {
  imports = [
    ../secrets/postgresql/immich.nix
    ../secrets/redis/immich.nix
    ../secrets/keycloak/immich.nix
  ];

  sops = {
    templates."immich-secrets.env" = {
      owner = "immich";

      content = ''
        DB_PASSWORD=${config.sops.placeholder."postgresql/immich"}
        REDIS_PASSWORD=${config.sops.placeholder."redis/immich"}
      '';
    };
  };

  services.immich = {
    enable = true;

    mediaLocation = "/mnt/fs-01b/immich";

    secretsFile = config.sops.templates."immich-secrets.env".path;

    machine-learning.enable = false;

    environment = {
      UPLOAD_LOCATION = "/mnt/fs-01b/immich/upload";
      LIBRARY_LOCATION = "${config.services.immich.mediaLocation}/library";
      THUMBS_LOCATION = "${config.services.immich.mediaLocation}/thumbs";
      PROFILE_LOCATION = "${config.services.immich.mediaLocation}/profile";
      VIDEO_LOCATION = "${config.services.immich.mediaLocation}/encoded-video";
      BACKUPS_LOCATION = "${config.services.immich.mediaLocation}/backups";
    };

    database = {
      createDB = true;
      enable = true;
      # Use local database due to usage of pgvecto-rs extension
      #host = ips.freeman;
      name = "immich";
      user = "immich";
    };

    redis = {
      enable = false;
      host = ips.freeman;
      port = 6381;
    };
  };

  services.postgresql.settings.listen_addresses = lib.mkForce "*";
  services.postgresql.authentication = lib.mkForce ''
    local   all             postgres                                peer

    # TYPE  DATABASE        USER            ADDRESS                 METHOD

    # "local" is for Unix domain socket connections only
    local   all             all                                     peer
    # IPv4 local connections:
    host    all             all             127.0.0.1/32            md5
    # IPv6 local connections:
    host    all             all             ::1/128                 md5
    # Allow replication connections from localhost, by a user with the
    # replication privilege.
    local   replication     all                                     peer
    host    replication     all             127.0.0.1/32            md5
    host    replication     all             ::1/128                 md5
    host    all             all             10.0.0.0/8             scram-sha-256
  '';

  # Add CAP_FOWNER to immich to prevent permission errors
  # with a CIFS drive mounted by the user jessew
  systemd.services.immich-server.serviceConfig = {
    AmbientCapabilities = "CAP_FOWNER";
    CapabilityBoundingSet = lib.mkForce "CAP_FOWNER";
  };

  modules.haproxy.acls.immich = ''
    acl is_immich hdr(host) -i photos.cpluspatch.com
    use_backend immich if is_immich
  '';

  modules.haproxy.backends.immich = ''
    backend immich
      server immich localhost:${toString config.services.immich.port}
  '';

  security.acme.certs."photos.cpluspatch.com" = {};
}
