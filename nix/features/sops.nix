{
  sops = {
    secrets = {
      "postgresql/keycloak" = {
        sopsFile = ../../secrets/postgresql/keycloak.yaml;
        key = "password";
      };
      "postgresql/root" = {
        sopsFile = ../../secrets/postgresql/root.yaml;
        key = "password";
      };
      "postgresql/synapse" = {
        sopsFile = ../../secrets/postgresql/synapse.yaml;
        key = "password";
      };
      "postgresql/mautrix-signal" = {
        sopsFile = ../../secrets/postgresql/mautrix-signal.yaml;
        key = "password";
      };
      "postgresql/vaultwarden" = {
        sopsFile = ../../secrets/postgresql/vaultwarden.yaml;
        key = "password";
      };
      "postgresql/plausible" = {
        sopsFile = ../../secrets/postgresql/plausible.yaml;
        key = "password";
      };
      "s3/backups/keyid" = {
        sopsFile = ../../secrets/s3/backups.yaml;
        key = "key_id";
      };
      "s3/backups/secret" = {
        sopsFile = ../../secrets/s3/backups.yaml;
        key = "key_secret";
      };
      "radarr/key" = {
        sopsFile = ../../secrets/radarr.yaml;
        key = "api_key";
      };
      "prowlarr/key" = {
        sopsFile = ../../secrets/prowlarr.yaml;
        key = "api_key";
      };
      "sonarr/key" = {
        sopsFile = ../../secrets/sonarr.yaml;
        key = "api_key";
      };
      traefik = {
        sopsFile = ../../secrets/traefik.yaml;
        key = "hash";
      };
      "synapse/registration-shared-secret" = {
        sopsFile = ../../secrets/synapse.yaml;
        key = "registration_shared_secret";
      };
      "synapse/signing-key" = {
        sopsFile = ../../secrets/synapse.yaml;
        key = "signing_key";
      };
      "synapse/form-secret" = {
        sopsFile = ../../secrets/synapse.yaml;
        key = "form_secret";
      };
      "synapse/macaroon-secret-key" = {
        sopsFile = ../../secrets/synapse.yaml;
        key = "macaroon_secret_key";
      };
      "synapse/ssap-secret" = {
        sopsFile = ../../secrets/synapse.yaml;
        key = "ssap_secret";
      };
      "synapse/oidc-client-secret" = {
        sopsFile = ../../secrets/synapse.yaml;
        key = "oidc_client_secret";
      };
      "synapse/as-token" = {
        sopsFile = ../../secrets/synapse.yaml;
        key = "as_token";
      };
      "synapse/hs-token" = {
        sopsFile = ../../secrets/synapse.yaml;
        key = "hs_token";
      };
      "synapse/pickle-key" = {
        sopsFile = ../../secrets/synapse.yaml;
        key = "pickle_key";
      };
      "plausible/secret-key-base" = {
        sopsFile = ../../secrets/plausible.yaml;
        key = "secret_key_base";
      };
      "fs-01b/password" = {
        sopsFile = ../../secrets/fs-01b.yaml;
        key = "password";
      };
    };

    # Set by the Terraform deployment
    age.keyFile = "/var/lib/secrets/age";
  };
}
