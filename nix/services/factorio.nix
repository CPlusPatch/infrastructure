{config, ...}: {
  sops.templates."factorio.json" = {
    content = ''
      {
        "game_password": "${config.sops.placeholder."factorio/password"}"
      }
    '';
  };

  services.factorio = {
    enable = true;
    requireUserVerification = true;
    saveName = "mindtorio";
    openFirewall = true;
    game-name = "Mindtech Factorio";
    description = "Penis";
    autosave-interval = 5;
    admins = [
      "CPlusPatch"
      "Samlppdgh"
    ];
    extraSettingsFile = config.sops.templates."factorio.json".path;
  };

  modules.dns.domains = ["mindtorio.factorio.cpluspatch.com"];

  # /var/lib/factorio is a symlink (DynamicUser), which restic would store as-is
  services.backups.jobs.factorio.source = "/var/lib/private/factorio";
}
