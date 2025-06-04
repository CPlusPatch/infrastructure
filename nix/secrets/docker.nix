{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "docker/ghcr" = {
      sopsFile = secretsDir + /docker.yaml;
      key = "ghcr_password";
    };
  };
}
