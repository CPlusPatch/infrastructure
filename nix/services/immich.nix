{
  config,
  lib,
  ...
}: let
  inherit (import ../lib/zerotier-ips.nix) zerotier-ips;
in {
  sops.templates."immich-secrets.env" = {
    owner = "immich";

    content = ''
      DB_PASSWORD=${config.sops.placeholder."postgresql/immich"}
      REDIS_PASSWORD=${config.sops.placeholder."redis/immich"}
      IMMICH_CONFIG_FILE=${config.sops.templates."immich-config.json".path}
    '';
  };

  # Don't use services.immich.settings, as it doesn't support secrets
  sops.templates."immich-config.json" = {
    owner = "immich";

    content = builtins.toJSON {
      backup = {
        database = {
          cronExpression = "0 02 * * *";
          enabled = false;
          keepLastAmount = 14;
        };
      };
      ffmpeg = {
        accel = "disabled";
        accelDecode = false;
        acceptedAudioCodecs = [
          "aac"
          "mp3"
          "libopus"
          "pcm_s16le"
        ];
        acceptedContainers = [
          "mov"
          "ogg"
          "webm"
        ];
        acceptedVideoCodecs = [
          "h264"
          "hevc"
          "vp9"
          "av1"
        ];
        bframes = -1;
        cqMode = "auto";
        crf = 23;
        gopSize = 0;
        maxBitrate = "0";
        preferredHwDevice = "auto";
        preset = "ultrafast";
        refs = 0;
        targetAudioCodec = "aac";
        targetResolution = "720";
        targetVideoCodec = "h264";
        temporalAQ = false;
        threads = 0;
        tonemap = "hable";
        transcode = "required";
        twoPass = false;
      };
      image = {
        colorspace = "p3";
        extractEmbedded = false;
        preview = {
          format = "jpeg";
          quality = 80;
          size = 1440;
        };
        thumbnail = {
          format = "webp";
          quality = 80;
          size = 250;
        };
      };
      job = {
        backgroundTask = {
          concurrency = 5;
        };
        faceDetection = {
          concurrency = 2;
        };
        library = {
          concurrency = 5;
        };
        metadataExtraction = {
          concurrency = 5;
        };
        migration = {
          concurrency = 5;
        };
        notifications = {
          concurrency = 5;
        };
        search = {
          concurrency = 5;
        };
        sidecar = {
          concurrency = 5;
        };
        smartSearch = {
          concurrency = 2;
        };
        thumbnailGeneration = {
          concurrency = 3;
        };
        videoConversion = {
          concurrency = 1;
        };
      };
      library = {
        scan = {
          cronExpression = "0 0 * * *";
          enabled = true;
        };
        watch = {
          enabled = false;
        };
      };
      logging = {
        enabled = true;
        level = "log";
      };
      machineLearning = {
        clip = {
          enabled = true;
          modelName = "ViT-H-14-378-quickgelu__dfn5b";
        };
        duplicateDetection = {
          enabled = true;
          maxDistance = 1.0e-2;
        };
        enabled = true;
        facialRecognition = {
          enabled = true;
          maxDistance = 0.5;
          minFaces = 3;
          minScore = 0.7;
          modelName = "antelopev2";
        };
        urls = [
          "http://10.147.19.66:8262"
        ];
      };
      map = {
        darkStyle = "https://tiles.immich.cloud/v1/style/dark.json";
        enabled = true;
        lightStyle = "https://tiles.immich.cloud/v1/style/light.json";
      };
      metadata = {
        faces = {
          import = false;
        };
      };
      newVersionCheck = {
        enabled = false;
      };
      notifications = {
        smtp = {
          enabled = false;
          from = "";
          replyTo = "";
          transport = {
            host = "";
            ignoreCert = false;
            password = "";
            port = 587;
            username = "";
          };
        };
      };
      oauth = {
        autoLaunch = true;
        autoRegister = true;
        buttonText = "Login with CPlusPatch ID";
        clientId = "immich";
        clientSecret = config.sops.placeholder."immich/oidc-client-secret";
        defaultStorageQuota = 0;
        enabled = true;
        issuerUrl = "https://id.cpluspatch.com/realms/master/.well-known/openid-configuration";
        mobileOverrideEnabled = false;
        mobileRedirectUri = "";
        profileSigningAlgorithm = "none";
        scope = "openid email profile";
        signingAlgorithm = "RS256";
        storageLabelClaim = "preferred_username";
        storageQuotaClaim = "immich_quota";
      };
      passwordLogin = {
        enabled = false;
      };
      reverseGeocoding = {
        enabled = true;
      };
      server = {
        externalDomain = "";
        loginPageMessage = "";
        publicUsers = true;
      };
      storageTemplate = {
        enabled = false;
        hashVerificationEnabled = true;
        template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
      };
      templates = {
        email = {
          albumInviteTemplate = "";
          albumUpdateTemplate = "";
          welcomeTemplate = "";
        };
      };
      theme = {
        customCss = "";
      };
      trash = {
        days = 30;
        enabled = true;
      };
      user = {
        deleteDelay = 7;
      };
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
      #host = zerotier-ips.freeman;
      name = "immich";
      user = "immich";
    };

    redis = {
      enable = false;
      host = zerotier-ips.freeman;
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
    host    all             all             10.147.19.0/24        scram-sha-256
  '';

  # Add CAP_FOWNER to immich to prevent permission errors
  # with a CIFS drive mounted by the user jessew
  systemd.services.immich-server.serviceConfig = {
    AmbientCapabilities = "CAP_FOWNER";
    CapabilityBoundingSet = lib.mkForce "CAP_FOWNER";
  };

  services.traefik.dynamicConfigOptions.http.routers.immich = {
    rule = "Host(`photos.cpluspatch.com`)";
    service = "immich";
  };

  services.traefik.dynamicConfigOptions.http.services.immich = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:${toString config.services.immich.port}";}
      ];
    };
  };
}
