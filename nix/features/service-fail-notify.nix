{
  lib,
  pkgs,
  ...
}:
with lib; {
  options.systemd.services = mkOption {
    type = with types;
      attrsOf (
        submodule {
          config.onFailure = ["notify-pushover@%n.service"];
        }
      );
  };

  config = {
    systemd.services."notify-pushover@" = {
      enable = true;
      onFailure = lib.mkForce []; # Can't refer to itself on failure
      description = "Notify on failed unit %i";
      serviceConfig = {
        Type = "oneshot";
      };

      scriptArgs = "%i %H";
      script = ''
        echo -e "Journal tail:\n$(journalctl -u $1 -n 20 -o cat)" | ${pkgs.curl}/bin/curl \
          -H "Title: $1 failed" \
          -H "Tags: warning,skull" \
          -T - \
          https://ntfy.sh/ServiceFailures 2&>1

      '';
    };
  };
}
