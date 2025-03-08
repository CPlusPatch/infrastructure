# Remember to set the device path to the correct disk
#
# disko.devices.disk.main.device = "/dev/sdX";
#
# when applying this configuration
{inputs, ...}: {
  imports = [
    inputs.disko.nixosModules.disko
  ];

  services.zfs.autoScrub.enable = true;
  services.zfs.trim.enable = true;

  disko.devices = {
    disk = {
      main = {
        type = "disk";
        content = {
          type = "gpt";

          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/efi";
                mountOptions = ["umask=0077"];
              };
            };

            zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "zroot";
              };
            };
          };
        };
      };
    };

    zpool = {
      zroot = {
        type = "zpool";
        name = "zroot";

        rootFsOptions = {
          compression = "zstd";
          mountpoint = "none";
          # By default ZFS doesn't enable support for storing
          # ACL data in the filesystem. Billions must enable it.
          acltype = "posixacl";
          xattr = "sa";
          # Disable access time updates
          # for performance reasons
          atime = "off";
        };

        # Set the ashift value to 12 for 4K sector drives
        # since we use this on SSDs and NVMe drives
        options.ashift = "12";

        datasets = {
          "local" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };

          "local/home" = {
            type = "zfs_fs";
            options = {
              mountpoint = "/home";
              "com.sun:auto-snapshot" = "true";
            };
          };

          "local/nix" = {
            type = "zfs_fs";
            options = {
              mountpoint = "/nix";
              # Disable auto snapshots for the Nix store
              "com.sun:auto-snapshot" = "false";
            };
          };

          "local/root" = {
            type = "zfs_fs";
            options = {
              mountpoint = "/";
              "com.sun:auto-snapshot" = "false";
            };
            postCreateHook = ''
              # List all snapshots of the dataset, filter out the one we're looking for
              # and check if it exists. If it doesn't, create it.
              if zfs list -t snapshot -H -o name | grep -E '^zroot/local/root@blank$' > /dev/null; then
                echo "Snapshot already exists"
              else
                zfs snapshot zroot/local/root@blank
              fi
            '';
          };

          # Reserve ~10% of the pool to avoid ZFS performance issues
          "local/reserved" = {
            type = "zfs_fs";
            options = {
              mountpoint = "/reserved";
              refreservation = "5G";
            };
          };
        };
      };
    };
  };
}
