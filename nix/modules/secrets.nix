{
  config,
  lib,
  ...
}: let
  files = import ../../secrets/registry.nix;
  hostFiles = lib.filterAttrs (name: file: lib.elem config.networking.hostName file.hosts) files;
in {
  sops = {
    # Hosts decrypt with their SSH host key, converted to an age key
    age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

    # No defaultSopsFile: a secret that isn't in the registry for this host fails to evaluate
    secrets = lib.mkMerge (
      lib.mapAttrsToList (name: file:
        lib.genAttrs file.secrets (secret: {
          sopsFile = ../../secrets/${name}.yaml;
        }))
      hostFiles
      ++ [
        # Dedicated SSH key for backup SFTP access (restic + pgbackrest → kleiner).
        # Owner defaults to root (restic); postgresql.nix overrides to pgbackrest.
        {
          "sftp/backup_private_key" = {
            owner = lib.mkDefault "root";
            mode = lib.mkDefault "0400";
          };
        }
      ]
    );
  };
}
