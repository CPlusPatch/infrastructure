{
  pkgs,
  lib,
  config,
  ...
}: {
  imports = [
    ../secrets/postgresql/versia.nix
  ];

  sops.templates.versia_postgres_env = {
    content = ''
      POSTGRES_DB=lysand
      POSTGRES_PASSWORD=${config.sops.placeholder."postgresql/versia"}
      POSTGRES_USER=lysand
    '';
  };
  virtualisation.oci-containers.containers."versia" = {
    image = "ghcr.io/versia-pub/server:sha-f606635";
    volumes = [
      "/var/lib/versia/config.toml:/app/dist/config/config.toml:rw"
      "versia_versia-config:/app/dist/config:ro"
      "versia_versia-logs:/app/dist/logs:rw"
      "versia_versia-uploads:/app/dist/uploads:rw"
    ];
    cmd = ["cli" "start" "-t" "1"];
    ports = [
      "127.0.0.1:3984:8080/tcp"
    ];
    dependsOn = [
      "versia-fe"
      "versia-postgres"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=versia"
      "--network=versia_default"
    ];
  };
  systemd.services."docker-versia" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-versia_default.service"
      "docker-volume-versia_versia-config.service"
      "docker-volume-versia_versia-logs.service"
      "docker-volume-versia_versia-uploads.service"
    ];
    requires = [
      "docker-network-versia_default.service"
      "docker-volume-versia_versia-config.service"
      "docker-volume-versia_versia-logs.service"
      "docker-volume-versia_versia-uploads.service"
    ];
    partOf = [
      "docker-compose-versia-root.target"
    ];
    wantedBy = [
      "docker-compose-versia-root.target"
    ];
  };
  virtualisation.oci-containers.containers."versia-fe" = {
    image = "ghcr.io/versia-pub/frontend:main";
    log-driver = "journald";
    extraOptions = [
      "--network-alias=fe"
      "--network=versia_default"
    ];
  };
  systemd.services."docker-versia-fe" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-versia_default.service"
    ];
    requires = [
      "docker-network-versia_default.service"
    ];
    partOf = [
      "docker-compose-versia-root.target"
    ];
    wantedBy = [
      "docker-compose-versia-root.target"
    ];
  };
  virtualisation.oci-containers.containers."versia-postgres" = {
    image = "ghcr.io/versia-pub/postgres:main";
    environmentFiles = [
      config.sops.templates.versia_postgres_env.path
    ];
    volumes = [
      "versia_versia-postgres:/var/lib/postgresql/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=postgres"
      "--network=versia_default"
    ];
  };
  systemd.services."docker-versia-postgres" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-versia_default.service"
      "docker-volume-versia_versia-postgres.service"
    ];
    requires = [
      "docker-network-versia_default.service"
      "docker-volume-versia_versia-postgres.service"
    ];
    partOf = [
      "docker-compose-versia-root.target"
    ];
    wantedBy = [
      "docker-compose-versia-root.target"
    ];
  };
  virtualisation.oci-containers.containers."versia-redis" = {
    image = "redis:alpine";
    volumes = [
      "versia_versia-redis:/data:rw"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=redis"
      "--network=versia_default"
    ];
  };
  systemd.services."docker-versia-redis" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-versia_default.service"
      "docker-volume-versia_versia-redis.service"
    ];
    requires = [
      "docker-network-versia_default.service"
      "docker-volume-versia_versia-redis.service"
    ];
    partOf = [
      "docker-compose-versia-root.target"
    ];
    wantedBy = [
      "docker-compose-versia-root.target"
    ];
  };
  virtualisation.oci-containers.containers."versia-worker" = {
    image = "ghcr.io/versia-pub/worker:sha-f606635";
    environment = {
      "BUN_CONFIG_VERBOSE_FETCH" = "curl";
    };
    volumes = [
      "/var/lib/versia/config.toml:/app/dist/config/config.toml:ro"
      "versia_versia-config:/app/dist/config:ro"
      "versia_versia-worker-logs:/app/dist/logs:rw"
    ];
    dependsOn = [
      "versia-postgres"
      "versia-redis"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network-alias=worker"
      "--network=versia_default"
    ];
  };
  systemd.services."docker-versia-worker" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
      RestartMaxDelaySec = lib.mkOverride 90 "1m";
      RestartSec = lib.mkOverride 90 "100ms";
      RestartSteps = lib.mkOverride 90 9;
    };
    after = [
      "docker-network-versia_default.service"
      "docker-volume-versia_versia-config.service"
      "docker-volume-versia_versia-worker-logs.service"
    ];
    requires = [
      "docker-network-versia_default.service"
      "docker-volume-versia_versia-config.service"
      "docker-volume-versia_versia-worker-logs.service"
    ];
    partOf = [
      "docker-compose-versia-root.target"
    ];
    wantedBy = [
      "docker-compose-versia-root.target"
    ];
  };

  # Networks
  systemd.services."docker-network-versia_default" = {
    path = [pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "docker network rm -f versia_default";
    };
    script = ''
      docker network inspect versia_default || docker network create versia_default
    '';
    partOf = ["docker-compose-versia-root.target"];
    wantedBy = ["docker-compose-versia-root.target"];
  };

  # Volumes
  systemd.services."docker-volume-versia_versia-config" = {
    path = [pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect versia_versia-config || docker volume create versia_versia-config
    '';
    partOf = ["docker-compose-versia-root.target"];
    wantedBy = ["docker-compose-versia-root.target"];
  };
  systemd.services."docker-volume-versia_versia-logs" = {
    path = [pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect versia_versia-logs || docker volume create versia_versia-logs
    '';
    partOf = ["docker-compose-versia-root.target"];
    wantedBy = ["docker-compose-versia-root.target"];
  };
  systemd.services."docker-volume-versia_versia-postgres" = {
    path = [pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect versia_versia-postgres || docker volume create versia_versia-postgres
    '';
    partOf = ["docker-compose-versia-root.target"];
    wantedBy = ["docker-compose-versia-root.target"];
  };
  systemd.services."docker-volume-versia_versia-redis" = {
    path = [pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect versia_versia-redis || docker volume create versia_versia-redis
    '';
    partOf = ["docker-compose-versia-root.target"];
    wantedBy = ["docker-compose-versia-root.target"];
  };
  systemd.services."docker-volume-versia_versia-uploads" = {
    path = [pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect versia_versia-uploads || docker volume create versia_versia-uploads
    '';
    partOf = ["docker-compose-versia-root.target"];
    wantedBy = ["docker-compose-versia-root.target"];
  };
  systemd.services."docker-volume-versia_versia-worker-logs" = {
    path = [pkgs.docker];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      docker volume inspect versia_versia-worker-logs || docker volume create versia_versia-worker-logs
    '';
    partOf = ["docker-compose-versia-root.target"];
    wantedBy = ["docker-compose-versia-root.target"];
  };

  # Root service
  # When started, this will automatically create all resources and start
  # the containers. When stopped, this will teardown all resources.
  systemd.targets."docker-compose-versia-root" = {
    unitConfig = {
      Description = "Root target generated by compose2nix.";
    };
    wantedBy = ["multi-user.target"];
  };

  modules.haproxy.acls.versia = ''
    acl is_versia hdr(host) -i social.lysand.org
    use_backend versia if is_versia
  '';

  modules.haproxy.backends.versia = ''
    backend versia
      server versia 127.0.0.1:3984
  '';

  security.acme.certs."social.lysand.org" = {};
}
