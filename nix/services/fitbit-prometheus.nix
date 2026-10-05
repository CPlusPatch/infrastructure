# Fetches Fitbit health data into InfluxDB on freeman
{
  config,
  lib,
  infra,
  nodes,
  ...
}: {
  sops.templates.fitbit-fetch-data-env = {
    content = ''
      AUTO_DATE_RANGE=True
      CLIENT_ID=${config.sops.placeholder."fitbit/client_id"}
      CLIENT_SECRET=${config.sops.placeholder."fitbit/client_secret"}
      DEVICENAME=Pixel Watch 3
      FITBIT_LOG_FILE_PATH=/app/logs/fitbit.log
      INFLUXDB_DATABASE=FitbitHealthStats
      INFLUXDB_HOST=${infra.ips.freeman}
      INFLUXDB_PASSWORD=${config.sops.placeholder."fitbit/influxdb_password"}
      INFLUXDB_PORT=${lib.last (lib.splitString ":" nodes.freeman.config.services.influxdb.settings.http.bind-address)}
      INFLUXDB_USERNAME=fitbit
      INFLUXDB_VERSION=1
      LOCAL_TIMEZONE=Automatic
      TOKEN_FILE_PATH=/app/tokens/fitbit.token
    '';
  };

  # Podman runs containers without a daemon, unlike Docker's dockerd and containerd
  virtualisation.podman = {
    enable = true;
    autoPrune.enable = true;
  };

  virtualisation.oci-containers = {
    backend = "podman";

    containers.fitbit-fetch-data = {
      # Pinned, so updates only happen on purpose. The tag was "latest". Podman needs the
      # registry, it doesn't assume Docker Hub
      image = "docker.io/thisisarpanghosh/fitbit-fetch-data@sha256:893ba4fe1ace9a97d6a85ca5ae14d7dcb11b7e53c0edff5958e344b9a5706ccf";
      environmentFiles = [config.sops.templates.fitbit-fetch-data-env.path];
      volumes = [
        "/etc/timezone:/etc/timezone:ro"
        "/var/lib/fitbit-fetch/logs:/app/logs:rw"
        "/var/lib/fitbit-fetch/tokens:/app/tokens:rw"
      ];
      log-driver = "journald";
    };
  };

  # Restart even after a clean exit, as the container is meant to run forever
  systemd.services.podman-fitbit-fetch-data.serviceConfig = {
    Restart = lib.mkForce "always";
    RestartSec = "1m";
  };
}
