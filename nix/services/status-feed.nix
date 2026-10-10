# Public status feed for cpluspatch.com's status board: a few fixed Prometheus queries written
# to static.cpluspatch.com/status.json every 20 seconds. Prometheus itself stays private, as its
# API runs any query and its labels hold private addresses, Redis URLs, unit names and mountpoints
{
  config,
  lib,
  pkgs,
  infra,
  nodes,
  ...
}: let
  inherit (config.modules.haproxy) vhosts;
  prometheus = "http://${infra.ips.freeman}:${toString nodes.freeman.config.services.prometheus.port}";
  minecraftPort = nodes.eli.config.services.minecraft-servers.servers.wiki.serverProperties.server-port;

  # Public name → blackbox probe instance, as labelled in prometheus.nix. Only these names, and
  # the ones below, can appear in the feed
  probes = {
    Matrix = "matrix.cpluspatch.dev";
    Mail = "${config.mailserver.fqdn}:993";
    Nextcloud = vhosts.nextcloud.domain;
    Immich = vhosts.immich.domain;
    Vaultwarden = vhosts.vaultwarden.domain;
    Sharkey = vhosts.sharkey.domain;
    Versia = vhosts.versia2.domain;
    Minecraft = "mc.cpluspatch.com:${toString minecraftPort}";
  };

  # Public name → exporter metric, up or down only. Down if any instance is down
  exporters = {
    PostgreSQL = "pg_up";
    Redis = "redis_up";
  };

  names = lib.attrNames probes ++ lib.attrNames exporters;
  hosts = lib.attrNames infra.ips;

  # Renames each series to its public name, and aggregating by name drops every other label
  named = name: series: ''label_replace(${series}, "name", "${name}", "", "")'';
  aggregate = op: series: "${op} by (name) (${lib.concatStringsSep " or " (lib.mapAttrsToList named series)})";

  upQuery = aggregate "min" (
    lib.mapAttrs (name: instance: ''probe_success{instance="${instance}"}'') probes // exporters
  );
  latencyQuery = aggregate "max" (lib.mapAttrs (name: instance: ''probe_duration_seconds{instance="${instance}"}'') probes);
  hostsQuery = ''max by (instance) (up{job="node"})'';
  # Only the count: alert names and annotations can hold anything
  alertsQuery = ''count(ALERTS{alertstate="firing"}) or vector(0)'';

  # Probes run every 20 seconds, so 30 steps are the last 10 minutes
  step = 20;
  beats = 30;

  # Missing steps and names count as down: Prometheus marks a failed probe's series stale
  # instead of recording 0
  feed = pkgs.writeText "status-feed.jq" ''
    def up: .[1] == "1";
    {
      generatedAt: $now,
      hosts: ($hosts | map(. as $h | {key: $h, value: any($hostsRes.data.result[]; .metric.instance == $h and (.value | up))}) | from_entries),
      alerts: ($alertsRes.data.result[0].value[1] | tonumber),
      probes: ($names | map(. as $n
        | ([$upRes.data.result[] | select(.metric.name == $n) | .values[] | {key: (.[0] | floor | tostring), value: up}] | from_entries) as $beats
        | {
          key: $n,
          value: ({beats: [range($start; $end + 1; ${toString step}) | $beats[tostring] // false]}
            + ([$latencyRes.data.result[] | select(.metric.name == $n) | {latency: (.value[1] | tonumber * 1000 | round)}] | first // {}))
        }) | from_entries)
    }
  '';

  script = pkgs.writeShellApplication {
    name = "status-feed";
    runtimeInputs = [pkgs.coreutils pkgs.curl pkgs.jq];
    text = ''
      now=$(date +%s)
      # Aligned to the step, so consecutive feeds share their beats
      end=$((now - now % ${toString step}))
      start=$((end - ${toString ((beats - 1) * step)}))

      query() {
        curl -fsS --max-time 10 --get "${prometheus}/api/v1/$1" "''${@:2}"
      }

      # Any failure exits here, keeping the previous feed
      up=$(query query_range --data-urlencode query=${lib.escapeShellArg upQuery} \
        --data-urlencode start="$start" --data-urlencode end="$end" --data-urlencode step=${toString step})
      latency=$(query query --data-urlencode query=${lib.escapeShellArg latencyQuery})
      hosts=$(query query --data-urlencode query=${lib.escapeShellArg hostsQuery})
      alerts=$(query query --data-urlencode query=${lib.escapeShellArg alertsQuery})

      json=$(jq -n -f ${feed} \
        --argjson now "$now" --argjson start "$start" --argjson end "$end" \
        --argjson names ${lib.escapeShellArg (builtins.toJSON names)} \
        --argjson hosts ${lib.escapeShellArg (builtins.toJSON hosts)} \
        --argjson upRes "$up" --argjson latencyRes "$latency" \
        --argjson hostsRes "$hosts" --argjson alertsRes "$alerts")

      # Same directory, so the rename is atomic and nginx never serves a partial file
      printf '%s\n' "$json" > "$STATE_DIRECTORY/.status.json.tmp"
      mv "$STATE_DIRECTORY/.status.json.tmp" "$STATE_DIRECTORY/status.json"
    '';
  };
in {
  # Static, as nginx can't read a DynamicUser's /var/lib/private
  users.users.status-feed = {
    isSystemUser = true;
    group = "status-feed";
  };
  users.groups.status-feed = {};

  systemd.services.status-feed = {
    description = "Write the public status feed";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe script;
      User = "status-feed";
      Group = "status-feed";
      StateDirectory = "status-feed";
      StateDirectoryMode = "0755";
      # The feed must be readable by nginx
      UMask = "0022";

      # Only reaches Prometheus on freeman
      IPAddressDeny = "any";
      IPAddressAllow = infra.ips.freeman;
      RestrictAddressFamilies = ["AF_INET" "AF_INET6"];

      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      PrivateUsers = true;
      PrivateIPC = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      ProtectProc = "invisible";
      ProcSubset = "pid";
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      MemoryDenyWriteExecute = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = ["@system-service"];
    };
  };

  systemd.timers.status-feed = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "1m";
      OnUnitActiveSec = "${toString step}s";
      AccuracySec = "1s";
    };
  };

  # Only the feed itself: an exact match, so nothing else in the directory is served
  services.nginx.virtualHosts."static.cpluspatch.com".locations."= /status.json" = {
    root = "/var/lib/status-feed";

    extraConfig = ''
      add_header Access-Control-Allow-Origin "https://cpluspatch.com" always;
      add_header Cache-Control "public, max-age=15" always;
    '';
  };
}
