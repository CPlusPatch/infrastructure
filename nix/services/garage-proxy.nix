# Garage's S3 API (on eli) behind HAProxy
{
  infra,
  lib,
  ...
}: let
  # There was a migration from Fastly and Cloudflare R2 to self-hosted garage on eli,
  # but the old domains are still in use. This code rewrites requests to the new domain
  # and serves the same content, so old links don't break.
  #
  # cdn: Versia's media, was Fastly's. The bucket is versia-cpp
  enableVersiaCdn = true;
  # mk-cdn: Sharkey's media, an R2 custom domain that isn't in the Terraform config. Also
  # needs `garage bucket alias misskey mk-cdn.cpluspatch.com` and detaching it from R2 first
  enableMkCdn = false;

  web = "${infra.ips.eli}:3902";

  # Media never changes under the same name, so browsers can cache it for good. There is no
  # CDN in front: HAProxy serves it directly from eli. Errors aren't cached
  cache = ''
    http-response set-header Cache-Control "public, max-age=31536000, immutable" if { status 200 206 304 }
    http-response set-header Access-Control-Allow-Origin "*"
  '';
in {
  modules.haproxy = lib.mkMerge [
    {
      vhosts.s3 = {
        domain = "s3.cpluspatch.com";
        server = "${infra.ips.eli}:3900";
      };
    }
    (lib.mkIf enableVersiaCdn {
      # Versia used the same domain as garage but with a different path, so the rewrite is necessary.
      httpsDomains = ["cdn.cpluspatch.com"];

      acls.cdn = ''
        acl is_cdn hdr(host) -i cdn.cpluspatch.com
        use_backend cdn if is_cdn
      '';

      backends.cdn = ''
        # Versia's path-style URLs, cdn.cpluspatch.com/versia-cpp/<key>, become the versia-cpp
        # bucket's website, versia-cpp.web.internal/<key>
        backend cdn
          http-request deny deny_status 404 unless { path_reg ^/versia-cpp/. }
          http-request set-header Host versia-cpp.web.internal
          http-request set-path %[path,regsub(^/versia-cpp,)]
          ${cache}
          server cdn ${web}
      '';
    })

    (lib.mkIf enableMkCdn {
      httpsDomains = ["mk-cdn.cpluspatch.com"];

      acls.mk-cdn = ''
        acl is_mk_cdn hdr(host) -i mk-cdn.cpluspatch.com
        use_backend mk-cdn if is_mk_cdn
      '';

      # The bucket has the domain as an alias, so the path needs no rewriting
      backends.mk-cdn = ''
        backend mk-cdn
          ${cache}
          server mk-cdn ${web}
      '';
    })
  ];
}
