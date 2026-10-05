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
    ../../services/banlist.nix
  ];

  # ZFS' cache can grow to most of the RAM by default. Walking a large directory, like Synapse's
  # media during backups, grew it past 2.5 GiB and pushed the services into swap
  boot.extraModprobeConfig = "options zfs zfs_arc_max=${toString (1536 * 1024 * 1024)}";

  # Synapse's media (27 GB of mostly incompressible files), with large records. Its own dataset,
  # so backups snapshot it on its own (see modules/backups.nix)
  disko.devices.zpool.zroot.datasets.synapse = {
    type = "zfs_fs";
    options = {
      mountpoint = "legacy";
      recordsize = "1M";
      "com.sun:auto-snapshot" = "false";
    };
    mountpoint = "/var/lib/matrix-synapse";
  };

  # Firewall ports are opened by the modules that use them: HAProxy, the mail server, Factorio
  # and the Minecraft proxy
  networking = {
    # Generate with:
    # head -c4 /dev/urandom | od -A none -t x4
    hostId = "76b7fe3c";
  };
}
