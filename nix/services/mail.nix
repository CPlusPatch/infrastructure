{config, ...}: {
  mailserver = {
    enable = true;
    fqdn = "${config.networking.hostName}.infra.cpluspatch.com";
    domains = ["cpluspatch.com" "cpluspatch.dev"];

    # Use Let's Encrypt certificates
    certificateScheme = "manual";
    certificateFile = "/var/lib/traefik-certs/${config.networking.hostName}.infra.cpluspatch.com/certificate.crt";
    keyFile = "/var/lib/traefik-certs/${config.networking.hostName}.infra.cpluspatch.com/privatekey.key";

    loginAccounts = {
      "jesse.wierzbinski@cpluspatch.com" = {
        # nix-shell -p mkpasswd --run 'mkpasswd -sm bcrypt'
        hashedPassword = "$2b$05$eugDzraTpV833FCaoJrZt.RJdeFrotOn7sSHkozw5vo8H6Hwp9z7K";
        aliases = ["postmaster@cpluspatch.com" "contact@cpluspatch.com" "@cpluspatch.com"];
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

  # Add Traefik configuration for rspamd WebUI
  services.traefik.dynamicConfigOptions.http = {
    routers.rspamd = {
      rule = "Host(`rspamd.cpluspatch.com`)";
      service = "rspamd";
      middlewares = ["dashboard-auth@file" "compress@file"];
    };

    services.rspamd.loadBalancer = {
      servers = [
        {
          url = "http://unix:/run/rspamd/worker-controller.sock";
        }
      ];
    };
  };
}
