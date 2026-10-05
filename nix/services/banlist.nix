# Bans scrapers and vulnerability scanners listed in banlist.json: their addresses at the
# firewall, their paths, user agents and headers in HAProxy
{
  lib,
  pkgs,
  ...
}: let
  banlist = lib.importJSON ./banlist.json;

  isIpv6 = lib.hasInfix ":";
  ipv4 = lib.filter (ip: !isIpv6 ip) banlist.ips;
  ipv6 = lib.filter isIpv6 banlist.ips;

  # Only web traffic is dropped: mail, Minecraft and SSH stay reachable, since the list also
  # covers cloud providers that legitimate mail servers send from
  ruleset = pkgs.writeText "banlist.nft" ''
    # Replaced in one transaction: creating the table first makes the delete always succeed
    table inet banlist
    delete table inet banlist

    table inet banlist {
      # auto-merge, as some ranges overlap
      set ipv4 {
        type ipv4_addr
        flags interval
        auto-merge
        elements = { ${lib.concatStringsSep ", " ipv4} }
      }

      set ipv6 {
        type ipv6_addr
        flags interval
        auto-merge
        elements = { ${lib.concatStringsSep ", " ipv6} }
      }

      # Before the NixOS firewall (iptables, at priority 0)
      chain input {
        type filter hook input priority -10; policy accept;
        iifname "enp1s0" ip saddr @ipv4 meta l4proto { tcp, udp } th dport { 80, 443 } drop
        iifname "enp1s0" ip6 saddr @ipv6 meta l4proto { tcp, udp } th dport { 80, 443 } drop
      }
    }
  '';

  nft = "${pkgs.nftables}/bin/nft";

  # Paths are shell-style globs, where * matches anything
  globToRegex = glob: "^" + lib.concatMapStringsSep ".*" lib.escapeRegex (lib.splitString "*" glob) + "$";
  # HAProxy's -i flag replaces the inline (?i)
  caseInsensitive = lib.removePrefix "(?i)";
  patterns = name: lines: pkgs.writeText "banlist-${name}" (lib.concatLines lines);

  # Banned crawlers asking for robots.txt are told to stay away, which the honest ones respect.
  # Everyone else gets the service's own robots.txt
  robotsTxt = pkgs.writeText "banlist-robots.txt" ''
    User-agent: *
    Disallow: /
  '';

  # Requests whose connection is closed: banned user agents and headers, Google's crawlers
  dropped = lib.concatStringsSep " || " (
    ["banned_agent" "googlebot_agent googlebot_ip"]
    ++ lib.optional (banlist.headers.include != []) ("banned_header" + lib.optionalString (banlist.headers.exclude != []) " !allowed_header")
  );

  headerAcl = acl: header:
    if header.value == "*"
    then "acl ${acl} req.hdr(${header.name}) -m found"
    else "acl ${acl} req.hdr(${header.name}) -i ${header.value}";
in {
  # For nft list table inet banlist
  environment.systemPackages = [pkgs.nftables];

  systemd.services.banlist = {
    description = "Drop web traffic from banned addresses";
    wantedBy = ["multi-user.target"];
    before = ["network-pre.target"];
    wants = ["network-pre.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${nft} -f ${ruleset}";
      ExecStop = "${nft} delete table inet banlist";
    };
  };

  # Checks the ruleset at build time, like the NixOS nftables module, in a userspace kernel
  system.checks = [
    (pkgs.runCommand "check-banlist-ruleset" {} ''
      LD_PRELOAD="${pkgs.lklWithFirewall.lib}/lib/liblkl-hijack.so" ${nft} --check --file ${ruleset}
      touch $out
    '')
  ];

  # Handled before routing, so they never reach a service, and without telling them they're
  # blocked, which would only make them come back disguised: scanners get an empty 404, as if
  # there was nothing there, and crawlers a closed connection, like a network error. The drops
  # aren't logged, they would fill the log. Each list is a file, as HAProxy's configuration
  # lines have a length limit
  modules.haproxy.acls.banlist =
    ''
      acl banned_path path -m reg -f ${patterns "paths" (map globToRegex banlist.paths)}
      acl banned_agent hdr(User-Agent) -m reg -i -f ${patterns "user-agents" [(caseInsensitive banlist.userAgents)]}
      ${lib.concatMapStringsSep "\n" (headerAcl "banned_header") banlist.headers.include}
      ${lib.concatMapStringsSep "\n" (headerAcl "allowed_header") banlist.headers.exclude}
      # Google's own crawlers, from Google's addresses
      acl googlebot_agent hdr(User-Agent) -m reg -i -f ${patterns "googlebot-agents" [(caseInsensitive banlist.googlebot.userAgents)]}
      acl googlebot_ip src -f ${patterns "googlebot-ips" banlist.googlebot.ips}

      acl robots_txt path /robots.txt

      http-request return status 200 content-type text/plain file ${robotsTxt} if robots_txt banned_agent || robots_txt googlebot_agent googlebot_ip
      http-request return status 404 if banned_path
      http-request set-log-level silent if ${dropped}
      http-request silent-drop if ${dropped}
    '';
}
