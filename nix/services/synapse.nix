{
  config,
  lib,
  ...
}: let
  inherit (import ../lib/ips.nix) ips;
in {
  nixpkgs.config.permittedInsecurePackages = [
    # Why does mautrix-signal use this? :(
    "olm-3.2.16"
  ];

  # Make secrets accessible to Synapse
  sops.secrets = {
    "synapse/registration-shared-secret" = {
      owner = "matrix-synapse";
    };
    "synapse/signing-key" = {
      owner = "matrix-synapse";
    };
    "synapse/form-secret" = {
      owner = "matrix-synapse";
    };
    "synapse/macaroon-secret-key" = {
      owner = "matrix-synapse";
    };
    "synapse/ssap-secret" = {
      owner = "matrix-synapse";
    };
    "synapse/oidc-client-secret" = {
      owner = "matrix-synapse";
    };
    "synapse/as-token" = {
      owner = "mautrix-signal";
    };
    "synapse/hs-token" = {
      owner = "mautrix-signal";
    };
    "synapse/pickle-key" = {
      owner = "mautrix-signal";
    };
    "redis/synapse" = {
      owner = "matrix-synapse";
    };
  };

  sops.templates."synapse/extra-config.yaml" = {
    content = ''
      modules:
        - module: shared_secret_authenticator.SharedSecretAuthProvider
          config:
            shared_secret: ${config.sops.placeholder."synapse/ssap-secret"}"
            m_login_password_support_enabled: false
    '';
    owner = "matrix-synapse";
  };

  sops.templates."synapse/pgpass" = {
    content = ''
      ${config.services.matrix-synapse.settings.database.args.host}:*:${config.services.matrix-synapse.settings.database.args.database}:${config.services.matrix-synapse.settings.database.args.user}:${config.sops.placeholder."postgresql/synapse"}
    '';
    owner = "matrix-synapse";
  };

  services.matrix-synapse = {
    enable = true;

    extras = ["oidc"];
    plugins = with config.services.matrix-synapse.package.plugins; [
      matrix-synapse-shared-secret-auth
      matrix-synapse-s3-storage-provider
    ];

    extraConfigFiles = [
      config.sops.templates."synapse/extra-config.yaml".path
    ];

    workers = {
      "federation_sender_1" = {
        worker_listeners = [
          {
            bind_addresses = [
              "127.0.0.1"
              "${ips.faithplate}"
            ];
            resources = [
              {
                names = [
                  "metrics"
                ];
              }
            ];
            tls = false;
            port = 9001;
            type = "metrics";
          }
        ];
      };
      "federation_sender_2" = {
        worker_listeners = [
          {
            bind_addresses = [
              "127.0.0.1"
              "${ips.faithplate}"
            ];
            resources = [
              {
                names = [
                  "metrics"
                ];
              }
            ];
            tls = false;
            port = 9002;
            type = "metrics";
          }
        ];
      };
    };

    settings = {
      database.args = {
        user = "synapse";
        database = "synapse";
        host = ips.freeman;
        passfile = config.sops.templates."synapse/pgpass".path;
      };

      redis = {
        enabled = true;
        host = ips.freeman;
        port = 6384;
        password_path = config.sops.secrets."redis/synapse".path;
      };

      federation_sender_instances = [
        "federation_sender_1"
        "federation_sender_2"
      ];

      enable_metrics = true;
      enable_registration = false;
      registration_requires_token = true;
      enable_registration_without_verification = true;
      max_upload_size = "100M";
      # Disabled because it fucks up performance
      presence.enabled = false;
      public_baseurl = "https://matrix.cpluspatch.dev";
      server_name = "cpluspatch.dev";
      serve_server_wellknown = false;

      signing_key_path = config.sops.secrets."synapse/signing-key".path;
      registration_shared_secret_path = config.sops.secrets."synapse/registration-shared-secret".path;
      form_secret_path = config.sops.secrets."synapse/form-secret".path;
      macaroon_secret_key_path = config.sops.secrets."synapse/macaroon-secret-key".path;

      listeners = [
        {
          bind_addresses = [
            "127.0.0.1"
          ];
          port = 8008;
          resources = [
            {
              names = [
                "client"
              ];
            }
            {
              names = [
                "federation"
              ];
            }
          ];
          tls = false;
          type = "http";
          x_forwarded = true;
        }
        {
          bind_addresses = [
            "127.0.0.1"
          ];
          port = 9093;
          type = "http";
          tls = false;
          resources = [
            {
              names = [
                "replication"
              ];
            }
          ];
        }
        {
          bind_addresses = [
            "127.0.0.1"
            "${ips.faithplate}"
          ];
          resources = [
            {
              names = [
                "metrics"
              ];
            }
          ];
          tls = false;
          port = 9000;
          type = "metrics";
        }
      ];

      instance_map = {
        main = {
          host = "127.0.0.1";
          port = 9093;
        };
      };

      oidc_providers = [
        {
          idp_id = "cpluspatch-id";
          idp_name = "CPlusPatch ID";
          idp_icon = "mxc://cpluspatch.dev/OFjyPnPkIiwJuouaxGTfIhtu";
          discover = true;
          issuer = "https://id.cpluspatch.com/realms/master/";
          client_id = "synapse";
          client_secret_path = config.sops.secrets."synapse/oidc-client-secret".path;
          scopes = ["openid" "profile"];
          backchannel_logout_enabled = true;
          user_mapping_provider.config = {
            localpart_template = "{{ user.preferred_username }}";
            display_name_template = "{{ user.name }}";
          };
        }
      ];
    };
  };

  # Allows the prometheus performance metrics to be collected
  # nixpkgs defaults it to "invisible", which doesn't let prometheus scrape it
  systemd.services.matrix-synapse.serviceConfig.ProcSubset = lib.mkForce "all";
  systemd.services.matrix-synapse-worker-federation_sender_1.serviceConfig = {
    ProcSubset = lib.mkForce "all";
    SupplementaryGroups = [
      "mautrix-signal"
    ];
  };
  systemd.services.matrix-synapse-worker-federation_sender_2.serviceConfig = {
    ProcSubset = lib.mkForce "all";
    SupplementaryGroups = [
      "mautrix-signal"
    ];
  };
  sops.templates."mautrix-signal/environment.env" = {
    content = ''
      MAUTRIX_SIGNAL_BRIDGE_LOGIN_SHARED_SECRET=${config.sops.placeholder."synapse/ssap-secret"}
      MAUTRIX_SIGNAL_BRIDGE_HS_TOKEN=${config.sops.placeholder."synapse/hs-token"}
      MAUTRIX_SIGNAL_BRIDGE_AS_TOKEN=${config.sops.placeholder."synapse/as-token"}
      MAUTRIX_SIGNAL_BRIDGE_PICKLE_KEY=${config.sops.placeholder."synapse/pickle-key"}
      MAUTRIX_SIGNAL_BRIDGE_POSTGRES_PASSWORD=${config.sops.placeholder."postgresql/mautrix-signal"}
    '';
    owner = "mautrix-signal";
  };

  services.mautrix-signal = {
    enable = true;
    environmentFile = config.sops.templates."mautrix-signal/environment.env".path;

    settings = {
      appservice = rec {
        bot = {
          displayname = "Signal Bridge Bot";
          username = "signalbot";
        };
        hostname = "[::]";
        hs_token = "$MAUTRIX_SIGNAL_BRIDGE_HS_TOKEN";
        as_token = "$MAUTRIX_SIGNAL_BRIDGE_AS_TOKEN";
        id = "signal";
        port = 29328;
        address = "http://localhost:${builtins.toString port}";
        username_template = "signal_{{.}}";
      };
      bridge = {
        command_prefix = "!signal";
        permissions = {
          "*" = "relay";
          config.services.matrix-synapse.settings.server_name = "relay";
          "@jesse:${config.services.matrix-synapse.settings.server_name}" = "admin";
        };
        relay = {
          enabled = false;
        };
      };
      database = {
        type = "postgres";
        uri = "postgres://mautrixsignal:$MAUTRIX_SIGNAL_BRIDGE_POSTGRES_PASSWORD@${ips.freeman}/mautrixsignal?sslmode=disable";
      };
      direct_media = {
        enabled = false;
      };
      double_puppet = {
        secrets = {};
        servers = {};
      };
      encryption = {
        allow = true;
        default = true;
        pickle_key = "$MAUTRIX_SIGNAL_BRIDGE_PICKLE_KEY";
      };
      homeserver = {
        address = "http://localhost:${builtins.toString (builtins.head config.services.matrix-synapse.settings.listeners).port}";
        domain = config.services.matrix-synapse.settings.server_name;
        async_media = true;
      };
      logging = {
        min_level = "info";
        writers = [
          {
            format = "pretty-colored";
            time_format = " ";
            type = "stdout";
          }
        ];
      };
      network = {
        displayname_template = "{{or .ProfileName .PhoneNumber \"Unknown user\"}}";
        use_contact_avatars = true;
      };
      provisioning = {
        shared_secret = "$MAUTRIX_SIGNAL_BRIDGE_LOGIN_SHARED_SECRET";
      };
      public_media = {
        enabled = false;
      };
    };
  };

  modules.haproxy.acls.synapse = ''
    acl is_synapse_domain hdr_reg(host) -i \bmatrix\.cpluspatch\.dev\b
    use_backend synapse if is_synapse_domain
    use_backend matrix-well-known-client if { hdr(host) -i cpluspatch.dev } { path_beg /.well-known/matrix/client }
    use_backend matrix-well-known-server if { hdr(host) -i cpluspatch.dev } { path_beg /.well-known/matrix/server }
  '';

  modules.haproxy.backends.synapse = ''
    backend synapse
      server synapse 127.0.0.1:${toString (builtins.head config.services.matrix-synapse.settings.listeners).port}
  '';

  modules.haproxy.backends.matrix-well-known-client = ''
    backend matrix-well-known-client
      http-after-response set-header Access-Control-Allow-Origin "*"
      http-after-response set-header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
      http-after-response set-header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization"
      http-request return status 200 content-type application/json string '{"m.homeserver":{"base_url":"https://matrix.cpluspatch.dev"}}'
  '';

  modules.haproxy.backends.matrix-well-known-server = ''
    backend matrix-well-known-server
      http-after-response set-header Access-Control-Allow-Origin "*"
      http-after-response set-header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
      http-after-response set-header Access-Control-Allow-Headers "Origin, X-Requested-With, Content-Type, Accept, Authorization"
      http-request return status 200 content-type application/json string '{"m.server":"matrix.cpluspatch.dev:443"}'
  '';

  security.acme.certs."matrix.cpluspatch.dev" = {};
  security.acme.certs."cpluspatch.dev" = {};
}
