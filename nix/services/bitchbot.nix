{config, ...}: let
  ips = import ../lib/zerotier-ips.nix;
in {
  sops.templates."bitchbot.env" = {
    content = ''
      REDIS_URL=redis://:${config.sops.placeholder."redis/bitchbot"}@${ips.zerotier-ips.freeman}:6382
    '';
    owner = "bitchbot";
  };

  services.bitchbot = {
    enable = true;
    config = {
      login = {
        homeserver = "https://matrix.cpluspatch.dev";
        username = "bitchbot";
        store_path = "store.json";
      };
      monitoring.health_check_uri = "https://status.cpluspatch.com/api/push/vHNWvZsz1k?status=up&msg=OK&ping=";
      commands = {
        prefix = "j!";
      };
      responses = {
        cooldown = 10;
      };
      encryption = {
        store_path = "store";
      };
      users = {
        wife = "@nex:nexy7574.co.uk";
        admin = ["@jesse:cpluspatch.dev"];
        banned = ["*:tomfos.tr" "@tom:*"];
      };
      wife_id = "@nex:nexy7574.co.uk";
      response_cooldown = 60;
      banned_users = ["@+:tomfos.tr"];
    };
  };

  systemd.services.bitchbot.serviceConfig = {
    EnvironmentFile = config.sops.templates."bitchbot.env".path;
  };
}
