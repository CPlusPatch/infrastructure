{config, ...}: {
  nixpkgs.overlays = [
    (import ../overlays/synapse-126.nix)
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

    settings = {
      database.args = {
        user = "synapse";
        database = "synapse";
        host = "10.147.19.243";
        passfile = config.sops.templates."synapse/pgpass".path;
      };

      enable_metrics = true;
      enable_registration = false;
      registration_requires_token = true;
      enable_registration_without_verification = true;
      max_upload_size = "100M";
      # Disabled because it fucks up performance
      presence.enabled = false;
      public_baseurl = "https://matrix.cpluspatch.dev";
      server_name = "cpluspatch.dev";
      serve_server_wellknown = true;

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

  services.traefik.dynamicConfigOptions.http.routers.synapse = {
    rule = "(Host(`cpluspatch.dev`) || Host(`matrix.cpluspatch.dev`)) && (PathPrefix(`/_matrix`) || PathPrefix(`/_synapse`) || PathPrefix(`/.well-known/matrix`))";
    service = "synapse";
  };

  services.traefik.dynamicConfigOptions.http = {
    services.synapse = {
      loadBalancer = {
        servers = [
          {url = "http://localhost:${builtins.toString (builtins.head config.services.matrix-synapse.settings.listeners).port}";}
        ];
      };
    };

    # this was funnier in my head
    middlewares.synapse.plugin = {
      "plugin-rewritebody" = {
        lastModified = "true";
        rewrites = [
          {
            regex = "\"name\":\"Synapse\"";
            replacement = "\"name\":\"i touch myself to toilets at Lowe's\"";
          }
        ];
      };
    };
  };
}
