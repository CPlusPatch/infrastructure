{config}: let
  inherit (import ../lib/ips.nix) ips;
in {
  services.versia-server = {
    enable = true;
    dataDir = "/var/lib/versia-server";

    user = "versia-server";
    group = "versia-server";

    nodes = {
      api = {
        main = {};
      };
      worker = {
        "1" = {};
      };
    };

    config = {
      postgres = {
        host = ips.freeman;
        port = 5432;
        username = "versia";
        password = "PATH:${config.sops.secrets."postgresql/versia2".path}";
        database = "versia";
      };
      redis = {
        queue = {
          host = ips.freeman;
          port = 6383;
          password = "PATH:${config.sops.secrets."redis/versia2".path}";
          database = 0;
        };
      };
      search = {
        enabled = true;
        sonic = {
          host = "localhost";
          port = 7700;
          password = "PATH:${config.sops.secrets."versia2/sonic".path}";
        };
      };
      registration = {
        allow = false;
        require_approval = true;
        message = "This is a single-user instance.";
      };
      http = {
        base_url = "https://vs.cpluspatch.com";
        bind = "127.0.0.1";
        bind_port = 9227;
        banned_ips = [];
        banned_user_agents = [];
      };
      frontend = {
        enabled = true;
        routes = {
        };
        settings = {
        };
      };
      email = {
        send_emails = false;
      };
      media = {
        backend = "s3";
        uploads_path = "uploads";
        conversion = {
          convert_images = true;
          convert_to = "image/webp";
          convert_vectors = false;
        };
      };
      s3 = {
        endpoint = "https://eu-central.object.fastlystorage.app";
        access_key = "PATH:${config.sops.secrets."s3/versia2/keyid".path}";
        secret_access_key = "PATH:${config.sops.secrets."s3/versia2/secret".path}";
        region = "eu-central";
        bucket = "versia-cpp";
        public_url = "https://cdn.cpluspatch.com";
        path = "versia-cpp";
        force_path_style = true;
      };
      validation = {
        accounts = {
          max_displayname_characters = 50;
          max_username_characters = 30;
          max_bio_characters = 5000;
          max_avatar_bytes = 5000000;
          max_header_bytes = 5000000;
          disallowed_usernames = ["well-known" "about" "activities" "api" "auth" "dev" "inbox" "internal" "main" "media" "nodeinfo" "notice" "oauth" "objects" "proxy" "push" "registration" "relay" "settings" "status" "tag" "users" "web" "search" "mfa"];
          max_field_count = 10;
          max_field_name_characters = 1000;
          max_field_value_characters = 1000;
          max_pinned_notes = 20;
        };
        notes = {
          max_characters = 100000;
          allowed_url_schemes = ["http" "https" "ftp" "dat" "dweb" "gopher" "hyper" "ipfs" "ipns" "irc" "xmpp" "ircs" "magnet" "mailto" "mumble" "ssb" "gemini"];
          max_attachments = 32;
        };
        media = {
          max_bytes = 40000000;
          max_description_characters = 1000;
          allowed_mime_types = [];
        };
        emojis = {
          max_bytes = 1000000;
          max_shortcode_characters = 100;
          max_description_characters = 1000;
        };
        polls = {
          max_options = 20;
          max_option_characters = 500;
          min_duration_seconds = 60;
          max_duration_seconds = 8640000;
        };
        emails = {
          disallow_tempmail = false;
          disallowed_domains = [];
        };
        filters = {
          note_content = [];
          emoji_shortcode = [];
          username = [];
          displayname = [];
          bio = [];
        };
      };
      notifications = {
        push = {
          subject = "mailto:admin+versia@cpluspatch.com";
          vapid_keys = {};
        };
      };
      defaults = {
        visibility = "public";
        language = "en";
        placeholder_style = "thumbs";
      };
      queues = {
        delivery = {
          remove_after_complete_seconds = 31536000;
          remove_after_failure_seconds = 31536000;
        };
        inbox = {
          remove_after_complete_seconds = 31536000;
          remove_after_failure_seconds = 31536000;
        };
        fetch = {
          remove_after_complete_seconds = 31536000;
          remove_after_failure_seconds = 31536000;
        };
        push = {
          remove_after_complete_seconds = 31536000;
          remove_after_failure_seconds = 31536000;
        };
        media = {
          remove_after_complete_seconds = 31536000;
          remove_after_failure_seconds = 31536000;
        };
      };
      federation = {
        blocked = [];
        followers_only = [];
        discard = {
          reports = [];
          deletes = [];
          updates = [];
          media = [];
          follows = [];
          likes = [];
          reactions = [];
          banners = [];
          avatars = [];
        };
      };
      instance = {
        name = "Jesse's Stupendous Carnival";
        description = "My personal self-hosted Versia Server instance.";
        languages = ["en"];
        contact = {
          email = "admin+versia@cpluspatch.com";
        };
        branding = {
          logo = "https://cpluspatch.com/images/icons/logo.svg";
          banner = "https://mk-cdn.cpluspatch.com/uploads/a8fe8d17-c104-412d-a76e-ea294e307c58.webp";
        };
        rules = [
          {
            text = "I do whatever I want.";
            hint = "BITCH.";
          }
        ];
      };
      permissions = {
      };
      logging = {
        log_level = "info";
        log_file_path = "logs/versia.log";
        types = {
        };
      };
      plugins = {
        autoload = true;
        overrides = {
          enabled = [];
          disabled = [];
        };
        config = {
          "@versia/openid" = {
            forced = true;
            allow_registration = true;

            providers = [
              {
                name = "CPlusPatch ID";
                id = "cpluspatch-id";
                url = "https://id.cpluspatch.com/realms/master";
                client_id = "versia-cpp";
                client_secret = "PATH:${config.sops.secrets."versia2/oidc-client-secret".path}";
                icon = "https://cpluspatch.com/images/icons/logo.svg";
              }
            ];
          };
        };
      };
    };
  };
}
