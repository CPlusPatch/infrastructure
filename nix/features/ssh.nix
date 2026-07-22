{pkgs, ...}: {
  services.openssh = {
    enable = true;

    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      Banner = "${pkgs.writeText "ssh-banner" ''

           |\---/|
           | ,_, |
            \_`_/-..----.
         ___/ `   ' ,""+ \
        (__...'   __\    |`.___.';
          (_,...'(_,.`__)/'.....+

      ''}";
    };
  };
}
