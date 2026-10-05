{
  config,
  lib,
  pkgs,
  infra,
  nodes,
  ...
}: {
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

    # On freeman with the other databases, which sets up its extensions (postgresql.nix)
    database = {
      enable = false;
      host = infra.ips.freeman;
      inherit (nodes.freeman.config.services.postgresql.settings) port;
      name = "immich";
      user = "immich";
    };

    redis = {
      enable = false;
      inherit (nodes.freeman.config.services.redis.servers.immich) port;
      host = nodes.freeman.config.services.redis.servers.immich.bind;
    };
  };

  services.backups.jobs = {
    # Photos are only stored on the storage box otherwise. It's a CIFS mount, not ZFS
    immich-media = {
      source = config.services.immich.mediaLocation;
      zfsSnapshot = false;
    };
  };

  # The media is on the storage box, which is mounted on first access. Fail to start (and
  # retry) while it's unreachable, rather than running without the photos. Not
  # RequiresMountsFor, which would stop Immich whenever the idle share gets unmounted
  systemd.services.immich-server.serviceConfig.ExecStartPre = "${pkgs.coreutils}/bin/test -d ${config.services.immich.mediaLocation}/library";

  # Add CAP_FOWNER to immich to prevent permission errors
  # with a CIFS drive mounted by the user jessew
  systemd.services.immich-server.serviceConfig = {
    AmbientCapabilities = "CAP_FOWNER";
    CapabilityBoundingSet = lib.mkForce "CAP_FOWNER";
  };

  modules.haproxy.vhosts.immich = {
    domain = "photos.cpluspatch.com";
    server = "localhost:${toString config.services.immich.port}";
  };
}
