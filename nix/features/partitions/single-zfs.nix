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
  boot.zfs.forceImportRoot = false;

  disko.devices = {
    disk = {
      main = {
        type = "disk";
        content = {
          type = "gpt";

          partitions = {
            # For Hetzner, EFI is not supported natively, so we use a legacy boot partition
            boot = {
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
              type = "8200"; # Linux swap GUID, enables systemd-gpt-auto-generator discovery
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

        rootFsOptions = {
          compression = "zstd";
          # By default ZFS doesn't enable support for storing
          # ACL data in the filesystem. Billions must enable it.
          acltype = "posixacl";
          xattr = "sa";
          dnodesize = "auto"; # Required companion to xattr=sa
          # Disable access time updates
          # for performance reasons
          atime = "off";
          # Don't try to mount the root filesystem
          mountpoint = "none";
        };

        # 4K sector alignment for SSD/NVMe
        options.ashift = "12";

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
            # Create a blank snapshot to avoid ZFS performance issues
            postCreateHook = "zfs list -t snapshot zroot/root@blank 2>/dev/null || zfs snapshot zroot/root@blank";
          };

          # Reserve a fixed 5G buffer to avoid ZFS performance issues
          "reserved" = {
            type = "zfs_fs";
            options = {
              mountpoint = "none";
              reservation = "5G";
            };
          };
        };
      };
    };
  };
}
