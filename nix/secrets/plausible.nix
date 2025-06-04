{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "plausible/secret_key_base" = {
      sopsFile = secretsDir + /plausible.yaml;
      key = "secret_key_base";
    };
  };
}
