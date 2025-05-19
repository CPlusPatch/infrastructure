{...}: {
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      export PATH="$HOME/.local/bin:$PATH"
      source ~/.p10k.zsh
    '';

    shellAliases = {
      cat = "bat";
      docker-up = "docker-compose up -d";
      docker-down = "docker-compose down";
    };

    history = {
      append = true;
      size = 100000;
    };

    zplug = {
      enable = true;
      plugins = [
        {
          name = "romkatv/powerlevel10k";
          tags = ["as:theme" "depth:1"];
        }
      ];
    };
  };

  home.file.".p10k.zsh".text = builtins.readFile ./p10k.zsh;
}
