# Site-wide HAProxy policy: certificates, redirects, and the services at home on kleiner.
# The HAProxy setup itself is nix/modules/haproxy.nix
{
  config,
  infra,
  ...
}: let
  kleiner = infra.kleiner.address;
in {
  modules.haproxy = {
    enable = true;

    # Protects the stats page and rspamd's UI
    extraConfig = ''
      userlist credentials
        user admin password $2b$05$d4BsCumQdqQ2ESUYjVyLT.ptJBpqGHKOw4Wn6B6gvGbLfT3.0lJRG
    '';
    metrics.userlist = "credentials";

    vhosts = {
      jellyfin2 = {
        domain = "tv.cpluspatch.com";
        server = "${kleiner}:8096";
      };
      seer = {
        domain = "seer.cpluspatch.com";
        server = "${kleiner}:5055";
      };
      radarr = {
        domain = "radarr.lgs.cpluspatch.com";
        server = "${kleiner}:7878";
      };
      sonarr = {
        domain = "sonarr.lgs.cpluspatch.com";
        server = "${kleiner}:8989";
      };
    };

    httpsDomains = ["broken.cpluspatch.com" "text.cpluspatch.com"];

    acls.site = ''
      # Opt out of FLoC
      http-response set-header Permissions-Policy "interest-cohort=()"
      http-response set-header X-Clacks-Overhead "GNU memdmp"

      # Ban Applebot because it makes sharkey crash
      acl applebot hdr_sub(User-Agent) Applebot
      http-request return status 401 if applebot

      # Redirect cpluspatch.dev to cpluspatch.com
      acl is_old_site hdr(host) -i cpluspatch.dev
      http-request redirect code 301 location https://cpluspatch.com%[capture.req.uri] if is_old_site !{ path_beg /.well-known/matrix }

      # Redirect text.cpluspatch.com to cpluspatch.com/text
      acl is_text_site hdr(host) -i text.cpluspatch.com
      http-request redirect code 301 location https://cpluspatch.com/text%[capture.req.uri] if is_text_site

      # To test what happens when a request is made to a non-existent backend
      acl is_broken hdr(host) -i broken.cpluspatch.com
      use_backend broken if is_broken
    '';

    backends.broken = ''
      backend broken
        mode http
        server broken 127.0.0.1:9999
    '';
  };

  # DNS challenges through Cloudflare, which allow wildcard certificates
  security.acme.defaults = {
    dnsProvider = "cloudflare";
    environmentFile = config.sops.templates."acme-cloudflare.env".path;
    # The local resolver can cache the challenge record as missing, and never see it appear
    dnsResolver = "1.1.1.1:53";
  };

  sops.templates."acme-cloudflare.env" = {
    content = ''
      CLOUDFLARE_DNS_API_TOKEN=${config.sops.placeholder."acme/cloudflare_dns_token"}
    '';
    owner = "acme";
  };

  # Wildcards cover every HTTPS domain (the HAProxy module checks it)
  security.acme.certs.wildcard-cpluspatch-com = {
    domain = "*.cpluspatch.com";
    extraDomainNames = ["*.lgs.cpluspatch.com"];
  };
  security.acme.certs.wildcard-cpluspatch-dev = {
    domain = "cpluspatch.dev";
    extraDomainNames = ["*.cpluspatch.dev"];
  };

  # Also served by HAProxy; the mail server module sets its own reloadServices
  security.acme.certs."${config.networking.hostName}.infra.cpluspatch.com".reloadServices = ["haproxy.service"];
}
