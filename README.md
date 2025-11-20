<div align="center">
    <a href="https://versia.pub">
        <picture>
            <img src="https://raw.githubusercontent.com/CPlusPatch/CPlusPatch/main/assets/minecraft_title.png" alt="CPlusPatch Logo" height="110" />
        </picture>
    </a>
</div>


<h2 align="center">
  <strong><code>infra</code></strong>
</h2>

My infra's [`OpenTofu`](https://opentofu.org) and [`NixOS`](https://nixos.org) configuration files.

## Documentation

Documentation is available in the [DOCS.md](./DOCS.md) file.

## Patches

Allows using swap during install.

```bash
# In terraform/.terraform/modules/nixos_install/src/nixos-anywhere.sh
# Replace line 673 with the following:

  # HACK: Increase size of tmpfs
  runSsh sh <<SSH
set -eu ${enableDebug}
mount -o remount,size=10G,noatime /
mount -o remount,size=10G,noatime /nix/.rw-store
SSH

# Also remove the "swapoff -a" on line 727 in the same file. 
```

## License

This project is currently licensed under an "All Rights Reserved" license. I will make it properly FOSS, but I need to figure out the best license and I don't have time to do that right now.