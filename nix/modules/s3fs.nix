{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.s3fs;
in {
  options.services.s3fs = {
    enable = mkEnableOption "Mounts s3 object storage using s3fs";
    keyPath = mkOption {
      type = types.str;
      default = "/etc/passwd-s3fs";
    };
    mountPath = mkOption {
      type = types.str;
      default = "/mnt/data";
    };
    bucket = mkOption {
      type = types.str;
      default = "data";
    };
    region = mkOption {
      type = types.str;
      default = "us-east-1";
    };
    url = mkOption {
      type = types.str;
      default = "https://us-east-1.amazonaws.com/";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.s3fs = {
      description = "Object storage s3fs";
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStartPre = [
          "${pkgs.coreutils}/bin/mkdir -m 777 -pv ${cfg.mountPath}"
          "${pkgs.e2fsprogs}/bin/chattr +i ${cfg.mountPath}" # stop files being written to unmounted dir
        ];
        ExecStart = let
          options = [
            "passwd_file=${cfg.keyPath}"
            "use_path_request_style"
            "allow_other"
            "url=${cfg.url}"
            "endpoint=${cfg.region}"
            "umask=0000"
          ];
        in
          "${pkgs.s3fs}/bin/s3fs ${cfg.bucket} ${cfg.mountPath} -f "
          + lib.concatMapStringsSep " " (opt: "-o ${opt}") options;
        ExecStopPost = "-${pkgs.fuse}/bin/fusermount -u ${cfg.mountPath}";
        KillMode = "process";
        Restart = "on-failure";
      };
    };
  };
}
