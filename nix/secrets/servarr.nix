{...}: let
  secretsDir = ../../secrets;
in {
  imports = [
    ./base.nix
  ];

  sops.secrets = {
    "radarr/key" = {
      sopsFile = secretsDir + /radarr.yaml;
      key = "api_key";
    };
    "prowlarr/key" = {
      sopsFile = secretsDir + /prowlarr.yaml;
      key = "api_key";
    };
    "sonarr/key" = {
      sopsFile = secretsDir + /sonarr.yaml;
      key = "api_key";
    };
  };
}
