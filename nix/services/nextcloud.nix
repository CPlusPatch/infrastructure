{
  config,
  pkgs,
  ...
}: let
  ips = import ../lib/zerotier-ips.nix;
in {
  sops.templates."nextcloud-secrets.json" = {
    owner = "nextcloud";
    content = builtins.toJSON {
      secret = config.sops.placeholder."nextcloud/secret";
    };
  };

  sops.secrets."postgresql/nextcloud".owner = "nextcloud";
  sops.secrets."s3/nextcloud/secret".owner = "nextcloud";
  sops.secrets."nextcloud/oidc-client-secret".owner = "nextcloud";
  sops.secrets."nextcloud/exporter-password".owner = "nextcloud-exporter";

  services.nextcloud = {
    enable = true;

    caching = {
      apcu = true;
      redis = true;
    };

    package = pkgs.nextcloud31;

    configureRedis = true;
    enableImagemagick = true;
    hostName = "cloud.cpluspatch.com";
    https = true;
    maxUploadSize = "10G";

    phpOptions = {
      "opcache.interned_strings_buffer" = "20";
    };

    extraApps = {
      inherit
        (pkgs.nextcloud31Packages.apps)
        mail
        calendar
        contacts
        notes
        impersonate
        tasks
        user_oidc
        music
        twofactor_webauthn
        ;
    };

    config = {
      adminuser = "admin";
      adminpassFile = builtins.toFile "admin-password" "admin";

      dbhost = ips.zerotier-ips.freeman;
      dbname = "nextcloud";
      dbpassFile = config.sops.secrets."postgresql/nextcloud".path;
      dbtype = "pgsql";
      dbuser = "nextcloud";

      objectstore.s3 = {
        enable = true;
        bucket = "cloud";
        autocreate = true;
        hostname = "eu-central.object.fastlystorage.app";
        region = "eu-central";
        key = "bpV8YxQW2BnSUeGFJncw93";
        secretFile = config.sops.secrets."s3/nextcloud/secret".path;
        usePathStyle = true;
      };
    };

    secretFile = config.sops.templates."nextcloud-secrets.json".path;

    settings = {
      default_phone_region = "FR";
      overwriteprotocol = "https";
      trusted_proxies = [
        "127.0.0.1/32"
        "::1/128"
        "10.0.0.0/8"
        "192.168.0.0/16"
        "172.16.0.0/12"
      ];
      # Non-file loggers aren't supported for whatever reason
      log_type = "file";

      maintenance_window_start = 1;
    };
  };

  mailserver.loginAccounts."cloud@cpluspatch.com" = {
    hashedPassword = "$2b$05$WzQ2/O96Awk9kFomIdXLw.680ut/0Q1Dn.TAzHU8w0j/R6/1tdLje";
  };

  services.prometheus.exporters.nextcloud = {
    enable = true;
    port = 9205;
    url = "https://cloud.cpluspatch.com";
    passwordFile = config.sops.secrets."nextcloud/exporter-password".path;
    username = "admin";
  };

  services.traefik.dynamicConfigOptions.http.routers.nextcloud = {
    rule = "Host(`cloud.cpluspatch.com`)";
    service = "nextcloud";
  };

  services.traefik.dynamicConfigOptions.http.services.nextcloud = {
    loadBalancer = {
      servers = [
        {url = "http://localhost:8080";}
      ];
    };
  };
}
