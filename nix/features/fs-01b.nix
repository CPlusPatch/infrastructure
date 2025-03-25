{
  pkgs,
  config,
  ...
}: {
  sops.templates."smb-secrets" = {
    content = ''
      username=u397505
      password=${config.sops.placeholder."fs-01b/password"}
    '';
  };

  # For mount.cifs
  environment.systemPackages = [pkgs.cifs-utils];

  fileSystems."/mnt/fs-01b" = {
    device = "//u397505.your-storagebox.de/backup";
    fsType = "cifs";
    options = let
      # Prevents hanging on network split
      automount_opts = "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s";
    in ["${automount_opts},credentials=${config.sops.templates."smb-secrets".path},file_mode=0666,dir_mode=0777,uid=1000,gid=100,iocharset=utf8,noperm"];
  };
}
