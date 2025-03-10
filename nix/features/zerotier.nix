{
  services.zerotierone = {
    enable = true;
    joinNetworks = [
      "a09acf0233609fc8"
    ];
  };

  networking.firewall.trustedInterfaces = ["ztuku27hp3"];

  # Don't forget to add 10.147.19.0/24 to allowed IPs in Postgres hba.conf
}
