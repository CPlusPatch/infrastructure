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
            # need to do this because of GRUB for some reason?
            boot = {
              name = "boot";
              size = "1M";
              type = "EF02";
            };

            esp = {
              name = "ESP";
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };

            swap = {
              size = "4G";
              label = "swap";
              content = {
                type = "swap";
                discardPolicy = "both";
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

        # Using legacy mountpoints everywhere because
        # otherwise there are conflicts where systemd and zfs
        # try to mount the same dataset
        datasets = {
          "home" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "true";
            };
            mountpoint = "/home";
          };

          "nix" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              # Disable auto snapshots for the Nix store
              "com.sun:auto-snapshot" = "false";
            };
            mountpoint = "/nix";
          };

          "root" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              "com.sun:auto-snapshot" = "false";
            };
            mountpoint = "/";
            postCreateHook = ''
              # List all snapshots of the dataset, filter out the one we're looking for
              # and check if it exists. If it doesn't, create it.
              if zfs list -t snapshot -H -o name | grep -E '^zroot/root@blank$' > /dev/null; then
                echo "Snapshot already exists"
              else
                zfs snapshot zroot/root@blank
              fi
            '';
          };

          # Reserve ~10% of the pool to avoid ZFS performance issues
          "reserved" = {
            type = "zfs_fs";
            options = {
              mountpoint = "legacy";
              refreservation = "5G";
            };
            mountpoint = "/reserved";
          };
        };
      };
    };
  };
}
