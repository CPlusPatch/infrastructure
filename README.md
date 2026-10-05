<div align="center">
    <a href="https://cpluspatch.com">
        <picture>
            <img src="https://raw.githubusercontent.com/CPlusPatch/CPlusPatch/main/assets/minecraft_title.png" alt="CPlusPatch Logo" height="110" />
        </picture>
    </a>
</div>


<h2 align="center">
  <strong><code>infra</code></strong>
</h2>

Configuration for my servers on Hetzner Cloud, deployed with [Colmena](https://colmena.cli.rs/), with servers and DNS managed by [OpenTofu](https://opentofu.org).

| Host | Data |
|------|--------------|
| `faithplate` | Everything public: HAProxy, Email, Matrix, Nextcloud, Immich, Keycloak, Vaultwarden, Grafana... |
| `freeman` | Databases (PostgreSQL, Redis, ClickHouse, InfluxDB) and monitoring |
| `eli` | Minecraft server(s) |

```bash
nix develop                         # or let direnv do it
nix flake check                     # build every host and run the config checks
colmena apply --on faithplate       # deploy one host
```

The setup, deployment, and backups are documented in [DOCS.md](./DOCS.md).

## License

This project is currently licensed under an "All Rights Reserved" license. I will make it properly FOSS, but I need to figure out the best license and I don't have time to do that right now.
