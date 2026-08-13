{lib, ...}: let
  genSecret = key: name: {
    "${key}/${name}" = {};
  };
in {
  # Set by the Terraform deployment
  sops = {
    # If Sops is asking for this, it means that you misspelled or forgot to import
    # one of the secrets configurations
    # defaultSopsFile = ../../secrets/docker.yaml;
    age.keyFile = "/var/lib/secrets/age";
    defaultSopsFile = ../../secrets/secrets.yaml;
    secrets = lib.mkMerge [
      (genSecret "backups" "passphrase")
      (genSecret "docker" "ghcr_password")
      (genSecret "factorio" "password")
      (genSecret "fitbit" "client_id")
      (genSecret "fitbit" "client_secret")
      (genSecret "fitbit" "influxdb_password")
      (genSecret "disks" "fs-01b")
      (genSecret "grafana" "secret_key")
      (genSecret "nextcloud" "secret")
      (genSecret "plausible" "secret_key_base")
      (genSecret "postgresql" "root")
      (genSecret "postgresql" "grafana")
      (genSecret "postgresql" "immich")
      (genSecret "postgresql" "keycloak")
      (genSecret "postgresql" "mautrix-signal")
      (genSecret "postgresql" "nextcloud")
      (genSecret "postgresql" "plausible")
      (genSecret "postgresql" "sharkey")
      (genSecret "postgresql" "synapse")
      (genSecret "postgresql" "vaultwarden")
      (genSecret "postgresql" "versia")
      (genSecret "prowlarr" "key")
      (genSecret "synapse" "registration_shared_secret")
      (genSecret "synapse" "macaroon_secret_key")
      (genSecret "synapse" "form_secret")
      (genSecret "synapse" "ssap_secret")
      (genSecret "synapse" "signing_key")
      (genSecret "synapse" "hs_token")
      (genSecret "synapse" "as_token")
      (genSecret "synapse" "pickle_key")
      (genSecret "versia" "sonic_password")
      (genSecret "versia" "instance_public_key")
      (genSecret "versia" "instance_private_key")
      (genSecret "versia" "vapid_public_key")
      (genSecret "versia" "vapid_private_key")
      (genSecret "versia" "authentication_key")
      (genSecret "keycloak" "grafana")
      (genSecret "keycloak" "nextcloud")
      (genSecret "keycloak" "synapse")
      (genSecret "keycloak" "versia")
      (genSecret "redis" "bitchbot")
      (genSecret "redis" "immich")
      (genSecret "redis" "sharkey")
      (genSecret "redis" "synapse")
      (genSecret "redis" "versia")
      (genSecret "s3" "backups/access_key_id")
      (genSecret "s3" "backups/secret_key")
      (genSecret "s3" "nextcloud/secret_key")
      (genSecret "s3" "versia/access_key_id")
      (genSecret "s3" "versia/secret_key")
      # Dedicated SSH key for backup SFTP access (restic + pgbackrest → kleiner).
      # Owner defaults to root (restic); postgresql.nix overrides to pgbackrest.
      {
        "sftp/backup_private_key" = {
          owner = lib.mkDefault "root";
          mode = lib.mkDefault "0400";
        };
      }
    ];
  };
}
