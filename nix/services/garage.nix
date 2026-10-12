{
  config,
  pkgs,
  infra,
  ...
}: let
  address = infra.ips.${config.networking.hostName};
in {
  sops.templates."garage.env" = {
    content = ''
      GARAGE_RPC_SECRET=${config.sops.placeholder."garage/rpc_secret"}
      GARAGE_ADMIN_TOKEN=${config.sops.placeholder."garage/admin_token"}
    '';
  };

  services.garage = {
    enable = true;
    package = pkgs.garage_2;
    environmentFile = config.sops.templates."garage.env".path;

    settings = {
      metadata_dir = "/var/lib/garage/meta";
      data_dir = "/var/lib/garage/data";
      # Crash-safe, and the dataset is snapshotted atomically for the backups
      db_engine = "lmdb";
      replication_factor = 1;

      # Only one node, so nothing needs to reach the RPC port
      rpc_bind_addr = "127.0.0.1:3901";
      rpc_public_addr = "127.0.0.1:3901";

      # The services below are reached by HAProxy on faithplate, over the private network
      s3_api = {
        api_bind_addr = "${address}:3900";
        # Same as Fastly's, so legacy clients' region setting doesn't change
        s3_region = "eu-central";
      };

      # Serves a bucket named after the Host header (a bucket alias, e.g. cdn.cpluspatch.com),
      # for public media. root_domain is a made-up suffix, only HAProxy uses it: <bucket>.web.internal
      # serves the bucket of that name, for paths that can't be aliases (cdn.cpluspatch.com/<bucket>/)
      s3_web = {
        bind_addr = "${address}:3902";
        root_domain = ".web.internal";
      };

      # The admin token comes from the environment file. /metrics has no token, as it's only
      # reachable from the private network, where Prometheus on freeman scrapes it
      admin.api_bind_addr = "${address}:3903";
    };
  };

  # A real user, as the state directory is a dataset mounted at /var/lib/garage, which a
  # DynamicUser's /var/lib/private/garage can't be
  users.users.garage = {
    isSystemUser = true;
    group = "garage";
  };
  users.groups.garage = {};

  systemd.services.garage.serviceConfig = {
    DynamicUser = false;
    User = "garage";
    Group = "garage";
    # eli's 5 GiB Minecraft heap leaves little RAM. Garage idles at 100-200 MB, so this is
    # just a ceiling for bursts (page cache of the metadata counts, and is reclaimable)
    MemoryHigh = "250M";
    MemoryMax = "400M";
    # Yield to the game server when both want the CPU
    CPUWeight = 50;
  };

  # Metadata and data in one dataset, so a snapshot captures both consistently. Backed up by
  # restic from that snapshot: the blocks are immutable and deduplicate well, and restoring
  # gives back the exact cluster, buckets and keys included
  services.backups.jobs.garage.source = "/var/lib/garage";
}
