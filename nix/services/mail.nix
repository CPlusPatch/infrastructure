{config, ...}: {
  mailserver = {
    enable = true;
    fqdn = "${config.networking.hostName}.infra.cpluspatch.com";
    domains = ["cpluspatch.com" "cpluspatch.dev"];

    # Use Let's Encrypt certificates
    certificateScheme = "manual";
    certificateFile = "/var/lib/acme/${config.networking.hostName}.infra.cpluspatch.com/cert.pem";
    keyFile = "/var/lib/acme/${config.networking.hostName}.infra.cpluspatch.com/key.pem";

    loginAccounts = {
      "jesse.wierzbinski@cpluspatch.com" = {
        # nix-shell -p mkpasswd --run 'mkpasswd -sm bcrypt'
        hashedPassword = "$2b$05$eugDzraTpV833FCaoJrZt.RJdeFrotOn7sSHkozw5vo8H6Hwp9z7K";
        aliases = ["postmaster@cpluspatch.com" "contact@cpluspatch.com" "@cpluspatch.com"];
      };
      "cloud@cpluspatch.com" = {
        hashedPassword = "$2b$05$WzQ2/O96Awk9kFomIdXLw.680ut/0Q1Dn.TAzHU8w0j/R6/1tdLje";
      };
      "auth@cpluspatch.com" = {
        hashedPassword = "$2b$05$q6e7Fynq1IVPzjnW0.LoveueGZFhE5sI5.h835cTypARBguXxXlMS";
      };
    };

    virusScanning = true;

    fullTextSearch = {
      enable = true;
      autoIndexExclude = ["\\Trash" "\\Junk"];
    };

    # Set hierarchy separator to / as recommended by dovecot
    hierarchySeparator = "/";

    # Disbale POP3 (it's old and not used much)
    enableImap = true;
    enableImapSsl = true;
    enablePop3 = false;
    enablePop3Ssl = false;
    enableSubmission = true;
    enableSubmissionSsl = true;

    # Enable ManageSieve for client-side filtering
    # Opens port 4190
    enableManageSieve = true;
  };

  services.rspamd = {
    enable = true;
    workers.controller = {
      bindSockets = [
        {
          socket = "/run/rspamd/worker-controller.sock";
          mode = "0666";
        }
      ];
    };
    # Tune spam filtering
    extraConfig = ''
      actions {
        reject = 15;        # Reject when score is higher than 15
        add_header = 6;     # Add header when reaching this score
        greylist = 4;       # Apply greylisting when reaching this score
      }
    '';
  };

  modules.haproxy.acls.rspamd = ''
    acl is_rspamd hdr(host) -i rspamd.cpluspatch.com
    http-request auth if is_rspamd !{ http_auth(credentials) }
    use_backend rspamd if is_rspamd
  '';

  modules.haproxy.backends.rspamd = ''
    backend rspamd
      server rspamd unix@/run/rspamd/worker-controller.sock
  '';

  security.acme.certs."rspamd.cpluspatch.com" = {};
}
