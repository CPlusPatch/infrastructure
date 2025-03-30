{
  services.bitchbot = {
    enable = true;
    config = {
      homeserver_url = "https://cpluspatch.dev";
      user_id = "@bitchbot:cpluspatch.dev";
      command_prefix = "j!";
      store_path = "./store";
      wife_id = "@nex:nexy7574.co.uk";
      response_cooldown = 60;
      health_check_uri = "https://status.cpluspatch.com/api/push/vHNWvZsz1k?status=up&msg=OK&ping=";
    };
  };
}
