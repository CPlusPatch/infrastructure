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
      "s3/backups/keyid" = {
        sopsFile = ../../secrets/s3/backups.yaml;
        key = "key_id";
      };
      "s3/backups/secret" = {
        sopsFile = ../../secrets/s3/backups.yaml;
        key = "key_secret";
      };
    };

    age.keyFile = "/var/lib/secrets/age";
  };
}
