{
  config,
  lib,
  ...
}: let
  inherit (import ../lib/ips.nix) ips;
in {
  sops.templates."bitchbot.env" = {
    content = ''
      REDIS_URL=redis://:${config.sops.placeholder."redis/bitchbot"}@${ips.freeman}:6382
      CONSOLA_LEVEL=4
    '';
    owner = "bitchbot";
  };

  services.bitchbot = {
    enable = true;
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
}
