# Forwards Minecraft from mc.cpluspatch.com to the server on eli, over the private network
{
  infra,
  nodes,
  ...
}: let
  port = nodes.eli.config.services.minecraft-servers.servers.wiki.serverProperties.server-port;
in {
  modules.haproxy.frontends.minecraft-eli-fe = ''
    frontend minecraft-eli-fe
      mode tcp
      bind :::${toString port} v4v6
      # Only connection errors, not every player login and server list ping
      option dontlog-normal
      default_backend minecraft-eli
  '';

  modules.haproxy.backends.minecraft-eli = ''
    backend minecraft-eli
      mode tcp
      server minecraft-eli ${infra.ips.eli}:${toString port}
  '';

  networking.firewall.allowedTCPPorts = [port];

  modules.dns.domains = ["mc.cpluspatch.com"];
}
