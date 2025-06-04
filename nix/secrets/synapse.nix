{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "synapse/registration_shared_secret" = {
      sopsFile = secretsDir + /synapse.yaml;
      key = "registration_shared_secret";
    };
    "synapse/signing_key" = {
      sopsFile = secretsDir + /synapse.yaml;
      key = "signing_key";
    };
    "synapse/form_secret" = {
      sopsFile = secretsDir + /synapse.yaml;
      key = "form_secret";
    };
    "synapse/macaroon_secret_key" = {
      sopsFile = secretsDir + /synapse.yaml;
      key = "macaroon_secret_key";
    };
    "synapse/ssap_secret" = {
      sopsFile = secretsDir + /synapse.yaml;
      key = "ssap_secret";
    };
    "synapse/as_token" = {
      sopsFile = secretsDir + /synapse.yaml;
      key = "as_token";
    };
    "synapse/hs_token" = {
      sopsFile = secretsDir + /synapse.yaml;
      key = "hs_token";
    };
    "synapse/pickle_key" = {
      sopsFile = secretsDir + /synapse.yaml;
      key = "pickle_key";
    };
  };
}
