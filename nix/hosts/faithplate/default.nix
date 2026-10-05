{
  imports = [
    ../../features/fs-01b.nix

    ../../services/haproxy.nix
    ../../services/keycloak.nix
    ../../services/servarr.nix
    ../../services/synapse.nix
    ../../services/vaultwarden.nix
    ../../services/plausible.nix
    ../../services/mail.nix
    ../../services/grafana.nix
    ../../services/nextcloud.nix
    ../../services/sharkey.nix
    ../../services/immich.nix
    ../../services/versia2.nix
    ../../services/static.nix
    ../../services/fitbit-prometheus.nix
    ../../services/factorio.nix
    ../../services/minecraft-proxy.nix
  ];

  # Firewall ports are opened by the modules that use them: HAProxy, the mail server, Factorio
  # and the Minecraft proxy
  networking = {
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "76b7fe3c";
  };
}
