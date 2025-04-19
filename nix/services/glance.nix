{config, ...}: {
  services.glance = {
    enable = true;

    settings = {
      server = {
        port = 5678;
      };

      theme = {
        background-color = "240 21 15";
        contrast-multiplier = 1.2;
        primary-color = "217 92 83";
        positive-color = "115 54 76";
        negative-color = "347 70 65";
      };

      pages = [
        {
          name = "Home";
          columns = [
            {
              size = "small";
              widgets = [
                {
                  type = "calendar";
                  first-day-of-week = "monday";
                }
                {
                  type = "rss";
                  limit = 10;
                  collapse-after = 3;
                  cache = "12h";
                  feeds = [
                    {
                      url = "https://selfh.st/rss/";
                      title = "selfh.st";
                      limit = 4;
                    }
                    {
                      url = "https://ciechanow.ski/atom.xml";
                    }
                    {
                      url = "https://www.joshwcomeau.com/rss.xml";
                      title = "Josh Comeau";
                    }
                    {
                      url = "https://samwho.dev/rss.xml";
                    }
                    {
                      url = "https://ishadeed.com/feed.xml";
                      title = "Ahmad Shadeed";
                    }
                  ];
                }
                {
                  type = "twitch-channels";
                  channels = [
                    "theprimeagen"
                    "j_blow"
                    "piratesoftware"
                    "cohhcarnage"
                    "christitustech"
                    "EJ_SA"
                  ];
                }
              ];
            }
            {
              size = "full";
              widgets = [
                {
                  type = "group";
                  widgets = [
                    {
                      type = "hacker-news";
                    }
                    {
                      type = "lobsters";
                    }
                  ];
                }
                {
                  type = "videos";
                  channels = [
                    "UCXuqSBlHAE6Xw-yeJA0Tunw" # Linus Tech Tips
                    "UCR-DXc1voovS8nhAvccRZhg" # Jeff Geerling
                    "UCsBjURrPoezykLs9EqgamOA" # Fireship
                    "UCBJycsmduvYEL83R_U4JriQ" # Marques Brownlee
                    "UCHnyfMqiRRG1u-2MsSQLbXA" # Veritasium
                  ];
                }
                {
                  type = "group";
                  widgets = [
                    {
                      type = "reddit";
                      subreddit = "technology";
                      show-thumbnails = true;
                    }
                  ];
                }
              ];
            }
            {
              size = "small";
              widgets = [
                {
                  type = "weather";
                  location = "Troyes, France";
                  units = "metric";
                  hour-format = "24h";
                }
                {
                  type = "markets";
                  markets = [
                    {
                      symbol = "SPY";
                      name = "S&P 500";
                    }
                    {
                      symbol = "BTC-USD";
                      name = "Bitcoin";
                    }
                    {
                      symbol = "NVDA";
                      name = "NVIDIA";
                    }
                    {
                      symbol = "AAPL";
                      name = "Apple";
                    }
                    {
                      symbol = "MSFT";
                      name = "Microsoft";
                    }
                  ];
                }
                {
                  type = "releases";
                  cache = "1d";
                  repositories = [
                    {repository = "honojs/hono";}
                    {repository = "oven-sh/bun";}
                    {repository = "immich-app/immich";}
                    {repository = "syncthing/syncthing";}
                  ];
                }
              ];
            }
          ];
        }
      ];
    };
  };

  modules.haproxy.acls.glance = ''
    acl is_glance hdr(host) -i glance.cpluspatch.com
    use_backend glance if is_glance
  '';

  modules.haproxy.backends.glance = ''
    backend glance
      server glance ${config.services.glance.settings.server.host}:${toString config.services.glance.settings.server.port}
  '';

  security.acme.certs."glance.cpluspatch.com" = {};
}
