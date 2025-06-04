{...}: let
  secretsDir = ../../../secrets;
in {
  imports = [
    ../base.nix
  ];

  sops.secrets = {
    "postgresql/mautrix-signal" = {
      sopsFile = secretsDir + /postgresql/mautrix-signal.yaml;
      key = "password";
    };
  };
}
