{
  config,
  lib,
  ...
}: let
  # Secrets by sops file. Each file is only encrypted for the hosts listed here (see
  # .sops.yaml), and each host only declares the secrets it can decrypt
  files = {
    # Backups
    common = {
      hosts = ["eli" "faithplate" "freeman"];
      secrets = [
        "backups/passphrase"
        "s3/backups/access_key_id"
        "s3/backups/secret_key"
        "sftp/backup_private_key"
      ];
    };

    # Used by services on faithplate and the databases they connect to on freeman
    faithplate-freeman = {
      hosts = ["faithplate" "freeman"];
      secrets = [
        "clickhouse/plausible_password"
        "redis/immich"
        "redis/sharkey"
        "redis/synapse"
        "redis/versia"
      ];
    };

    faithplate = {
      hosts = ["faithplate"];
      secrets = [
        "disks/fs-01b"
        "factorio/password"
        "fitbit/client_id"
        "fitbit/client_secret"
        "fitbit/influxdb_password"
        "grafana/secret_key"
        "keycloak/grafana"
        "keycloak/nextcloud"
        "keycloak/synapse"
        "keycloak/versia"
        "nextcloud/secret"
        "plausible/secret_key_base"
        "postgresql/grafana"
        "postgresql/immich"
        "postgresql/keycloak"
        "postgresql/mautrix-signal"
        "postgresql/nextcloud"
        "postgresql/plausible"
        "postgresql/sharkey"
        "postgresql/synapse"
        "postgresql/vaultwarden"
        "postgresql/versia"
        "s3/nextcloud/secret_key"
        "s3/versia/access_key_id"
        "s3/versia/secret_key"
        "synapse/as_token"
        "synapse/form_secret"
        "synapse/hs_token"
        "synapse/macaroon_secret_key"
        "synapse/pickle_key"
        "synapse/registration_shared_secret"
        "synapse/signing_key"
        "synapse/ssap_secret"
        "versia/authentication_key"
        "versia/instance_private_key"
        "versia/instance_public_key"
        "versia/sonic_password"
        "versia/vapid_private_key"
        "versia/vapid_public_key"
      ];
    };

    freeman = {
      hosts = ["freeman"];
      secrets = [
        "ntfy/topic"
        "postgresql/root"
      ];
    };

    eli = {
      hosts = ["eli"];
      secrets = ["minecraft/rcon_password"];
    };
  };

  hostFiles = lib.filterAttrs (name: file: lib.elem config.networking.hostName file.hosts) files;
in {
  sops = {
    # Hosts decrypt with their SSH host key, converted to an age key
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

    # No defaultSopsFile: a secret that isn't declared above for this host fails to evaluate
    secrets = lib.mkMerge (
      lib.mapAttrsToList (name: file:
        lib.genAttrs file.secrets (secret: {
          sopsFile = ../../secrets/${name}.yaml;
        }))
      hostFiles
      ++ [
        # Dedicated SSH key for backup SFTP access (restic + pgbackrest → kleiner).
        # Owner defaults to root (restic); postgresql.nix overrides to pgbackrest.
        {
          "sftp/backup_private_key" = {
            owner = lib.mkDefault "root";
            mode = lib.mkDefault "0400";
          };
        }
      ]
    );
  };
}
