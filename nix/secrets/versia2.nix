{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "versia2/sonic" = {
      sopsFile = secretsDir + /versia2.yaml;
      key = "sonic_password";
    };
    "versia2/instance_public_key" = {
      sopsFile = secretsDir + /versia2.yaml;
      key = "instance_public_key";
    };
    "versia2/instance_private_key" = {
      sopsFile = secretsDir + /versia2.yaml;
      key = "instance_private_key";
    };
    "versia2/vapid_public_key" = {
      sopsFile = secretsDir + /versia2.yaml;
      key = "vapid_public_key";
    };
    "versia2/vapid_private_key" = {
      sopsFile = secretsDir + /versia2.yaml;
      key = "vapid_private_key";
    };
    "versia2/oidc_public_key" = {
      sopsFile = secretsDir + /versia2.yaml;
      key = "oidc_public_key";
    };
    "versia2/oidc_private_key" = {
      sopsFile = secretsDir + /versia2.yaml;
      key = "oidc_private_key";
    };
  };
}
