{config, ...}: {
  mailserver = {
    enable = true;
    fqdn = "${config.networking.hostName}.infra.cpluspatch.com";
    domains = ["cpluspatch.com" "cpluspatch.dev"];
    stateVersion = 5;

    # Use Let's Encrypt certificates
    x509.useACMEHost = config.mailserver.fqdn;

    accounts = {
      "jesse.wierzbinski@cpluspatch.com" = {
        # nix-shell -p mkpasswd --run 'mkpasswd -sm bcrypt'
        hashedPassword = "$2b$05$eugDzraTpV833FCaoJrZt.RJdeFrotOn7sSHkozw5vo8H6Hwp9z7K";
        aliases = ["postmaster@cpluspatch.com" "contact@cpluspatch.com" "@cpluspatch.com"];
      };
      "cloud@cpluspatch.com" = {
        hashedPassword = "$2b$05$WzQ2/O96Awk9kFomIdXLw.680ut/0Q1Dn.TAzHU8w0j/R6/1tdLje";
      };
      "auth@cpluspatch.com" = {
        hashedPassword = "$2b$05$6px1d7Wxh2Sl3EdI3AO8UuARNtHPUKOCbGUTKjCxKq3bQ6lmPvOLe";
      };
    };

    # ClamAV holds ~1 GB of signatures in memory, and rspamd already filters spam
    virusScanning = false;

    fullTextSearch = {
      enable = false;
      # Index new emails as they arrive
      autoIndex = true;
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
          # Owned by the rspamd user and group, HAProxy reaches it through group membership
          mode = "0660";
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

  # HAProxy needs access to the controller socket
  users.users.${config.services.haproxy.user}.extraGroups = [config.services.rspamd.group];

  services.backups.jobs = {
    mail.source = config.mailserver.storage.path;
    mail-dkim.source = config.mailserver.dkim.keyDirectory;
  };

  modules.haproxy.vhosts.rspamd = {
    domain = "rspamd.cpluspatch.com";
    server = "unix@/run/rspamd/worker-controller.sock";
    extraRules = ''
      http-request auth if is_rspamd !{ http_auth(credentials) }
    '';
  };
}
