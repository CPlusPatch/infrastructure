{
  config,
  lib,
  infra,
  ...
}: let
  inherit (infra) ips;
in {
  imports = [
    ../lib/secrets.nix
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

  # The local database isn't covered by pgbackrest (which only runs on freeman),
  # so dump it daily and let restic pick up the dumps
  services.postgresqlBackup = {
    enable = true;
    databases = [config.services.immich.database.name];
    compression = "zstd";
  };

  services.backups.jobs = {
    immich-db.source = config.services.postgresqlBackup.location;
    # Photos are only stored on the storage box otherwise. It's a CIFS mount, not ZFS
    immich-media = {
      source = config.services.immich.mediaLocation;
      zfsSnapshot = false;
    };
  };

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
