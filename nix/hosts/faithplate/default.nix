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

  modules.dns.domains = [
    # Factorio server
    "mindtorio.factorio.cpluspatch.com"
  ];

  networking = {
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "76b7fe3c";

    firewall = {
      allowedTCPPorts = [
        25 # SMTP
        465 # SMTP over SSL
        587 # SMTP submission
        993 # IMAP over SSL
      ];
    };
  };
}
