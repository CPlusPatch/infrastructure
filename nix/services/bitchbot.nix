{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (import ../lib/ips.nix) ips;
in {
  imports = [
    ../secrets/redis/bitchbot.nix
  ];

  sops.templates."bitchbot.env" = {
    content = ''
      REDIS_URL=redis://:${config.sops.placeholder."redis/bitchbot"}@${ips.freeman}:6382
      CONSOLA_LEVEL=4
    '';
    #owner = "bitchbot";
  };

  services.bitchbot = {
    enable = false;
    config = {
      login = {
        homeserver = "https://matrix.cpluspatch.dev";
        username = "bitchbot";
        store_path = "${config.services.bitchbot.dataDir}/store.json";
      };
      monitoring.health_check_uri = "https://status.cpluspatch.com/api/push/vHNWvZsz1k?status=up&msg=OK&ping=";
      commands = {
        prefix = "j!";
      };
      responses = {
        cooldown = 10;
      };
      encryption = {
        store_path = "${config.services.bitchbot.dataDir}/store";
      };
      users = {
        wife = "@nex:nexy7574.co.uk";
        admin = ["@jesse:cpluspatch.dev"];
        banned = ["*:tomfos.tr" "@tom:*" "@star:nexy7574.co.uk" "echo" "ping"];
      };
      wife_id = "@nex:nexy7574.co.uk";
      response_cooldown = 60;
      banned_users = ["@+:tomfos.tr"];
    };
  };

  systemd.services.bitchbot.serviceConfig = {
    EnvironmentFile = config.sops.templates."bitchbot.env".path;
    User = lib.mkForce "root";
    Group = lib.mkForce "root";
  };

  modules.haproxy.acls.bitchbot = ''
    acl is_bitchbot hdr(host) -i bitchbot.cpluspatch.com
    acl is_bitchbot_api path_beg /api
    use_backend bitchbot_api if is_bitchbot is_bitchbot_api
    use_backend bitchbot_fe if is_bitchbot !is_bitchbot_api
  '';

  modules.haproxy.backends.bitchbot = ''
    backend bitchbot_api
      server bitchbot_api_server 127.0.0.1:16193
  '';

  modules.haproxy.backends.bitchbot_fe = ''
    backend bitchbot_fe
      server bitchbot_fe_server 127.0.0.1:${toString config.services.nginx.defaultHTTPListenPort}
  '';

  services.nginx.virtualHosts."bitchbot.cpluspatch.com" = {
    root = "${pkgs.bitchbot}/bitchbot/dist";
  };

  security.acme.certs."bitchbot.cpluspatch.com" = {};
}
