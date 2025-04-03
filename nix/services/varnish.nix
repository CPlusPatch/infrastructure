{
  services.varnish = {
    enable = true;

    config = ''
      vcl 4.1;
      import std;

      # If missing cache, Varnish will re-send the request to HAProxy
      backend default {
        .host = "localhost";
        .port = "19872";
        .connect_timeout = 3s;
        .first_byte_timeout = 10s;
        .between_bytes_timeout = 5s;
        .probe = {
          .url = "/healthcheck";
          .expected_response = 200;
          .timeout = 1s;
          .interval = 3s;
          .window = 2;
          .threshold = 2;
          .initial = 2;
        }
      }

      acl purge {
        "localhost";
      }

      sub vcl_recv {
        # Health Checking
        if (req.url == "/healthcheck") {
          return (synth(200, "Health check OK!"));
        }

        # Grace period (stale content delivery while revalidating)
        set req.grace = 30s;

        # Purge request
        if (req.method == "PURGE") {
          if (!client.ip ~ purge) {
            return (synth(405, "Not allowed."));
          }

          return (purge);
        }

        # Accept-Encoding header clean-up
        if (req.http.Accept-Encoding) {
          # use gzip when possible, otherwise use deflate
          if (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
          } elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
          } else {
            # unknown algorithm, remove accept-encoding header
            # notably, we don't want Brotli
            unset req.http.Accept-Encoding;
          }
        }

        # Stale content delivery
        # If the backend died, serve stale content
        if (std.healthy(req.backend_hint)) {
          set req.grace = 30s;
        } else {
          set req.grace = 1d;
        }

        # Cookie ignored in these static pages
        unset req.http.cookie;

        # Static objects are first looked up in the cache
        if (req.url ~ "\.(css|gif|jpg|jpeg|bmp|png|ico|img|tga|wmf)$") {
          return (hash);
        }

        # if we arrive here, we look for the object in the cache
        return (hash);
      }

      sub vcl_hash {
        hash_data(req.url);

        # Hash the host header if it exists
        if (req.http.host) {
          hash_data(req.http.host);
        } else {
          hash_data(server.ip);
        }

        return (lookup);
      }

      sub vcl_backend_response {
        # Stale content delivery
        set beresp.grace = 1d;

        # Hide Server information
        unset beresp.http.Server;

        # Store compressed objects in memory
        # They would be uncompressed on the fly by Varnish if the client doesn't support compression
        if (beresp.http.content-type ~ "(text|application)") {
          set beresp.do_gzip = true;
        }

        # remove any cookie on static or pseudo-static objects
        unset beresp.http.set-cookie;

        return (deliver);
      }

      sub vcl_deliver {
        unset resp.http.via;
        unset resp.http.x-varnish;

        # could be useful to know if the object was in cache or not
        if (obj.hits > 0) {
          set resp.http.X-Cache = "HIT";
        } else {
          set resp.http.X-Cache = "MISS";
        }

        return (deliver);
      }
    '';
  };
}
