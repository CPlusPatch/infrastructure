{
  config,
  lib,
  ...
}: let
  inherit (import ../lib/ips.nix) ips;
in {
  sops.templates."plausible.env" = {
    content = ''
      DATABASE_URL=postgres://plausible:${config.sops.placeholder."postgresql/plausible"}@${ips.freeman}:5432/plausible
      SECRET_KEY_BASE=${config.sops.placeholder."plausible/secret-key-base"}
    '';
  };

  services.plausible = {
    enable = true;

    server = {
      disableRegistration = true;
      baseUrl = "https://logs.cpluspatch.com";
      port = 10239;
      secretKeybaseFile = config.sops.secrets."plausible/secret-key-base".path;
    };

    database = {
      postgres = {
        setup = false;
      };

      clickhouse = {
        url = "http://${ips.freeman}:8123/plausible_events_db";
        setup = false;
      };
    };
  };

  # HACK: Inject Plausible secrets, because the service config doesn't have an option for that
  systemd.services.plausible = {
    # Remove the default NixOS DATABASE_URL that just points to a local socket for some reason
    environment.DATABASE_URL = lib.mkForce null;
    serviceConfig = {
      EnvironmentFile = config.sops.templates."plausible.env".path;
    };
  };

  modules.haproxy.acls.plausible = ''
    acl is_plausible hdr(host) -i logs.cpluspatch.com
    use_backend plausible if is_plausible
  '';

  modules.haproxy.backends.plausible = ''
    backend plausible
      server plausible 127.0.0.1:${toString config.services.plausible.server.port}
  '';

  security.acme.certs."logs.cpluspatch.com" = {};
}
