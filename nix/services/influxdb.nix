{
  config,
  inputs,
  pkgs,
  ...
}: {
  services.influxdb = {
    enable = true;
    # See the nixpkgs-influxdb input in flake.nix
    package = inputs.nixpkgs-influxdb.legacyPackages.${pkgs.stdenv.hostPlatform.system}.influxdb;
    settings = {
      index-version = "tsi1";
    };
  };

  services.backups.jobs.influxdb.source = config.services.influxdb.dataDir;
}
