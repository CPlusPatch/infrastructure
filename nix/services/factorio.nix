{config, ...}: {
  imports = [
    ../lib/secrets.nix
  ];

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

  services.backups.jobs.factorio.source = "/var/lib/factorio";
}
