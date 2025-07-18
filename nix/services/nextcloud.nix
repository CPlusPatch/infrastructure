{
  config,
  pkgs,
  ...
}: let
  inherit (import ../lib/ips.nix) ips;
in {
  imports = [
    ../secrets/nextcloud.nix
    ../secrets/postgresql/nextcloud.nix
    ../secrets/s3/nextcloud.nix
    ../secrets/keycloak/nextcloud.nix
  ];

  sops = {
    templates."nextcloud-secrets.json" = {
      owner = "nextcloud";
      content = builtins.toJSON {
        secret = config.sops.placeholder."nextcloud/secret";
      };
    };

    secrets."postgresql/nextcloud".owner = "nextcloud";
    secrets."s3/nextcloud/secret_key".owner = "nextcloud";
    secrets."keycloak/nextcloud/client_secret".owner = "nextcloud";
    secrets."nextcloud/exporter_password".owner = "nextcloud-exporter";
  };

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
        spreed
        ;
    };

    config = {
      adminuser = "admin";
      adminpassFile = builtins.toFile "admin-password" "admin";

      dbhost = ips.freeman;
      dbname = "nextcloud";
      dbpassFile = config.sops.secrets."postgresql/nextcloud".path;
      dbtype = "pgsql";
      dbuser = "nextcloud";

      objectstore.s3 = {
        enable = true;
        bucket = "cloud";
        verify_bucket_exists = true;
        hostname = "eu-central.object.fastlystorage.app";
        region = "eu-central";
        key = "bpV8YxQW2BnSUeGFJncw93";
        secretFile = config.sops.secrets."s3/nextcloud/secret_key".path;
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

  services.prometheus.exporters.nextcloud = {
    enable = true;
    port = 9205;
    url = "https://cloud.cpluspatch.com";
    passwordFile = config.sops.secrets."nextcloud/exporter_password".path;
    username = "admin";
  };

  modules.haproxy.acls.nextcloud = ''
    acl is_nextcloud hdr(host) -i cloud.cpluspatch.com
    acl is_dav_url_discovery path /.well-known/caldav /.well-known/carddav
    use_backend nextcloud if is_nextcloud
    http-request redirect location /remote.php/dav/ code 301 if is_nextcloud is_dav_url_discovery
  '';

  modules.haproxy.backends.nextcloud = ''
    backend nextcloud
      server nextcloud 127.0.0.1:${toString config.services.nginx.defaultHTTPListenPort}
  '';

  security.acme.certs."cloud.cpluspatch.com" = {};
}
