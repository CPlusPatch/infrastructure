<!-- omit in toc -->
# Documentation

- [Machines](#machines)
- [Repository layout](#repository-layout)
- [Elements](#elements)
- [Deploying](#deploying)
- [Adding a service or domain](#adding-a-service-or-domain)
- [Secrets](#secrets)
- [Terraform](#terraform)
- [Monitoring and alerts](#monitoring-and-alerts)
- [Backups](#backups)
- [Restoring](#restoring)
- [Upgrading PostgreSQL](#upgrading-postgresql)
- [Minecraft](#minecraft)
- [Routine maintenance](#routine-maintenance)
- [Setting up a new host](#setting-up-a-new-host)

## Machines

Three Hetzner Cloud servers in Falkenstein (`fsn1`), all running NixOS on a single ZFS pool.

| Host | Type | Private IP | Role |
|------|------|------------|------|
| `freeman` | cx23 | 10.0.1.1 | PostgreSQL 17, Redis, ClickHouse, InfluxDB, Prometheus, Alertmanager |
| `eli` | cx33 | 10.0.1.2 | Minecraft |
| `faithplate` | cx33 | 10.0.1.3 | HAProxy and every public service |

`freeman` has no public IPv4 address, only IPv6. The others are dual stack.

The hosts talk to each other over Hetzner's private network (`10.0.0.0/8`, interface `enp7s0`), which the firewall trusts. Tailscale is also trusted, and is how HAProxy reaches the media services (Jellyfin, Seer, Radarr, Sonarr) running on `kleiner`, my machine at home. `kleiner` is also the second backup target.

> [!WARNING]
> The servers are on grandfathered prices. Never change `server_type` in `terraform/servers.tf`: resizing moves the server to current pricing for good.

## Repository layout

```
assets/                Modpacks (.mrpack) and server icons
html/                  Error pages and the bot challenge page, built into the cpluspatch-pages package
nix/    
  features/            Building blocks every host gets: VM hardware, networking, SSH, Tailscale, the shell, the monitoring agent
  hosts/    
    base/              Configuration shared by all hosts
    <host>/            Host-specific config: the services it runs, its host ID, etc
  modules/             Custom modules with options: backups, dns, haproxy, secrets
  packages/            The cpluspatch-pages package
  services/            One file per service, imported by the host that runs it
scripts/    
  new-host-key.sh      Generates a new host's SSH key before it's installed
  check-secrets.sh     Checks the sops files against the registry, run by nix flake check
secrets/               Sops files, one per group of hosts
  registry.nix         Which secrets each file holds, and which hosts can read it
terraform/             Hetzner servers and Cloudflare DNS
flake.nix              Inputs, the Colmena hive, checks, dev shell, formatter
```

## Elements

- **The hive** : `flake.nix` defines one Colmena node per host. Every node gets the modules in `defaults` (disko, sops-nix, the base config, ...) plus its own list. A host's `default.nix` mostly just lists the services it runs.

- **Host data from Terraform** : Terraform writes each server's addresses to `terraform/nixos-vars.json`. The flake reads that file and passes it to every module as the `infra` argument, so a service can say `infra.ips.freeman` instead of hardcoding `10.0.1.1`. The same data configures each host's static IPs in `nix/features/hetzner-network.nix`.

- **Other hosts' settings** : Colmena passes every host's configuration as `nodes`, so a service can read a value from the host that owns it instead of repeating it. Services on `faithplate` take their database ports from `nodes.freeman.config.services`, and Prometheus takes the list of vhosts to probe from `nodes.faithplate`.

- **HTTPS** : HAProxy on `faithplate` terminates TLS for everything and routes requests by host name. The setup is a module, `nix/modules/haproxy.nix`, and the site-wide rules (redirects, certificates, the services on `kleiner`) are in `nix/services/haproxy.nix`. Most services declare a vhost:

    ```nix
    modules.haproxy.vhosts.vaultwarden = {
        domain = "vault.cpluspatch.com";
        server = "127.0.0.1:8222";
    };
    ```

    That one block creates the routing rule, the backend, and the DNS record. Certificates come from two Let's Encrypt wildcards, `*.cpluspatch.com` (plus `*.lgs.cpluspatch.com`) and `cpluspatch.dev` (plus `*.cpluspatch.dev`), issued with DNS challenges through a Cloudflare API token. The build fails if a domain isn't covered by a certificate, so a vhost like `a.b.cpluspatch.com` would need its own cert first. The mail server keeps its own certificate for `faithplate.infra.cpluspatch.com`.

    A vhost with `protected = true` makes browsers solve a proof-of-work challenge before reaching it, like Anubis. It's for services that scrapers hammer, and doesn't affect API clients, which don't claim to be Mozilla. No vhost uses it at the moment.

- **DNS** : Services add their domains to `modules.dns.domains`. The flake collects them into its `domains` output, `terraform/domains.json` is a copy of that, and Terraform turns each entry into a CNAME to `<host>.infra.cpluspatch.com`. `nix flake check` fails when the JSON is out of date. Mail records (MX, SPF, DKIM, DMARC, autodiscovery) and the Minecraft SRV record are written by hand in `terraform/dns.tf`.

- **Databases** : PostgreSQL on `freeman` creates a role and a database for each service on `faithplate` (`roles` in `nix/services/postgresql.nix`), and `postgresql-set-passwords` sets each role's password from its secret on every boot and deploy. A rebuilt `freeman` only needs its data restored, or nothing at all for a fresh start.

- **Build-time checks** : `nix flake check` builds every host, and the build itself validates the HAProxy config (warnings count as errors), the Prometheus config and alert rules, the Alertmanager config, the domains file, and the secrets (see [Secrets](#secrets)). If it passes, the config is at least well-formed.

## Deploying

Everything below runs inside the dev shell (`nix develop`, or automatically with direnv), which has Colmena, OpenTofu, sops, ssh-to-age and the formatter.

```bash
nix flake check                          # build all hosts, run every check
colmena build                            # build without the checks
colmena apply --on freeman dry-activate  # show which units would restart, change nothing
colmena apply --on freeman               # build, copy and switch
colmena apply                            # all hosts at once
nix fmt                                  # format with alejandra
```

Some habits that have saved me trouble:

- Run `dry-activate` before anything touching networking, databases or HAProxy. It lists exactly which services will stop, start or reload.
- Deploy one host at a time. When PostgreSQL or Redis on `freeman` restarts (or the host reboots), the services on `faithplate` log connection errors until they're back, then reconnect on their own.
- For changes that are only safe at boot (networking, kernel), use `colmena apply --on <host> boot` and then reboot, with the Hetzner console open just in case.
- When a deploy changes the Minecraft server's config, it stops the server and only starts its socket. Start it again with `systemctl start minecraft-server-wiki`.

To roll a host back to its previous generation:

```bash
ssh root@<host>.infra.cpluspatch.com nixos-rebuild switch --rollback
```

Older generations also show up in the GRUB menu, which you can reach from the Hetzner console.

**Updating inputs:**

```bash
nix flake update
nix flake check
colmena apply --on eli    # least important host first
```

nixpkgs tracks `nixos-unstable`. Read the NixOS evaluation warnings after an update.

## Adding a service or domain

1. Write `nix/services/<name>.nix`. For anything behind HTTPS, add a `modules.haproxy.vhosts.<name>` block like the one above, and a `services.backups.jobs.<name>.source` line if it keeps state.
2. Import it in `nix/hosts/<host>/default.nix`.
3. Regenerate the DNS file and check everything:

   ```bash
   nix eval --json .#domains | jq -S . > terraform/domains.json
   nix flake check
   ```

4. Create the DNS record, then deploy:

   ```bash
   cd terraform && tofu apply
   colmena apply --on faithplate
   ```

Domains that HAProxy serves through hand-written rules (`modules.haproxy.acls`) instead of a vhost, like Synapse's, go in `modules.haproxy.httpsDomains`, so the certificate check still covers them. HAProxy evaluates `http-request` rules before `use_backend` ones whatever their order, so the module groups the lines by directive and drops comments. Domains that aren't HTTPS at all, like the Factorio server, go straight into `modules.dns.domains`.

## Secrets

Secrets are [sops](https://github.com/getsops/sops) files in `secrets/`, encrypted with age. Each host decrypts with its own SSH host key, converted to an age key, and only receives the files it needs:

| File | Readable by |
|------|-------------|
| `common.yaml` | all hosts (backup credentials) |
| `faithplate-freeman.yaml` | `faithplate`, `freeman` (database passwords both sides need) |
| `faithplate.yaml` | `faithplate` |
| `freeman.yaml` | `freeman` |
| `eli.yaml` | `eli` |

My personal age key (`~/.config/sops/age/keys.txt`) can read all of them. Recipients are set in `.sops.yaml`.

```bash
sops secrets/faithplate.yaml                    # open in $EDITOR
sops decrypt --extract '["ntfy"]["topic"]' secrets/freeman.yaml

# Add a value without it ending up in shell history
read -rs V && printf '%s' "$V" | jq -Rs . \
  | sops set --value-stdin secrets/faithplate.yaml '["service"]["password"]'; unset V
```

A new secret also needs declaring in `secrets/registry.nix`, under the file it lives in. `nix flake check` compares the registry with the files, which works without decrypting anything since sops leaves key names in plaintext:

- every registered secret exists in its file, and the file holds nothing else
- `.sops.yaml` encrypts each file for exactly the hosts the registry lists (plus admins)
- each file is actually encrypted for those recipients, i.e. `sops updatekeys` was run

After changing recipients in `.sops.yaml`, re-encrypt the affected files with `sops updatekeys secrets/<file>.yaml`.

## Terraform

The state is local: `terraform/terraform.tfstate`, alongside `terraform.tfvars` with the Hetzner and Cloudflare tokens. Both are gitignored and should stay `chmod 600`.

```bash
cd terraform
tofu plan
tofu apply
```

The servers have delete and rebuild protection on. Removing a server means turning protection off in `servers.tf` and applying that first.

## Monitoring and alerts

`freeman` runs Prometheus, Alertmanager and the blackbox exporter. Every host runs `node_exporter` on its private address.

- **Dashboard:** [stats.cpluspatch.com](https://stats.cpluspatch.com), "Infrastructure" folder. It's provisioned from `nix/services/grafana-dashboards/infrastructure.json` and read-only in the UI, so change the JSON in the repo instead. Dashboards made in the UI live in "General" and aren't touched by deploys.
- **Prometheus:** port 9090 on `freeman`, reachable over the private network or Tailscale.
- **Probes:** every HTTPS vhost, `matrix.cpluspatch.dev`, the Minecraft port, SMTP (STARTTLS on 25, over the private network) and submission and IMAP over TLS (465, 993) are probed from `freeman` every 15 seconds. The HTTPS list comes from HAProxy's vhosts, so new services are picked up automatically.
- **Scraped:** node exporters, HAProxy, PostgreSQL, ClickHouse, every Redis server (through one `redis_exporter`), and Synapse.

Alert rules are in `nix/services/prometheus.nix`:

| Alert | Fires when |
|-------|------------|
| `HostDown` | A node exporter can't be scraped for 3 minutes |
| `EndpointDown` | A probe has failed for 5 minutes |
| `DiskSpaceLow` / `DiskSpaceCritical` | Under 15% / 5% free |
| `DiskFillsWithin24h` | The last 6 hours' trend reaches zero within a day |
| `MemoryPressure` | Processes spend over 10% of their time waiting for memory, for 15 minutes |
| `MemoryAlmostExhausted` | Under 2% available, counting ZFS' reclaimable cache as available |
| `HighCpu` | Over 90% for 30 minutes |
| `ZfsPoolUnhealthy` | A pool isn't `ONLINE` |
| `UnitFailed` | A systemd unit is in the failed state |
| `BackupStale` | A daily backup timer hasn't run for 36 hours, or a weekly one for 8 days |
| `PostgresDown` | The Postgres exporter can't reach the database |
| `WalArchivingStalled` | PostgreSQL hasn't archived WAL for 30 minutes, usually because a pgBackRest repository is unreachable |
| `RedisDown` | A Redis server can't be reached by the exporter |
| `CertificateExpiringSoon` | A probed certificate expires in under 14 days (renewal normally happens at 30) |
| `ScrapeTargetDown` | Any other metrics endpoint is down for 10 minutes |

Alerts go to a private [ntfy](https://ntfy.sh) topic on ntfy.sh. Get its name with `sops decrypt --extract '["ntfy"]["topic"]' secrets/freeman.yaml` and subscribe to it in the app. Critical alerts arrive at urgent priority, warnings at default, and resolved messages at low.

Alertmanager has no web UI exposed and `amtool` isn't installed, so use its API on `freeman`:

```bash
# What's firing
curl -s localhost:9093/api/v2/alerts | jq '.[].labels'

# Silence an alert for two hours, e.g. during maintenance
curl -s -X POST localhost:9093/api/v2/silences -H 'Content-Type: application/json' -d "{
  \"matchers\": [{\"name\": \"alertname\", \"value\": \"HostDown\", \"isRegex\": false}],
  \"startsAt\": \"$(date -u +%FT%TZ)\", \"endsAt\": \"$(date -u -d '+2 hours' +%FT%TZ)\",
  \"createdBy\": \"jesse\", \"comment\": \"maintenance\"}"

# Send a test notification that resolves itself after two minutes
curl -s -X POST localhost:9093/api/v2/alerts -H 'Content-Type: application/json' -d "[{
  \"labels\": {\"alertname\": \"TestNotification\", \"severity\": \"warning\"},
  \"annotations\": {\"summary\": \"Test alert\"},
  \"endsAt\": \"$(date -u -d '+2 min' +%FT%TZ)\"}]"
```

## Backups

Every backup goes to two places: S3 at Fastly (`eu-central.object.fastlystorage.app`, bucket `backups`), and SFTP to `kleiner:/mnt/HDD1/Backups/Infra`.

**Files (restic).** A service adds `services.backups.jobs.<name>.source = "/var/lib/<name>";`, and `nix/modules/backups.nix` turns that into two restic jobs, `s3-<name>` and `sftp-<name>`. They run daily at a random time between midnight and 3am. Before each run the job snapshots the ZFS dataset and backs up the snapshot, so databases and other files that change mid-run are captured consistently. Each run also prunes old snapshots and reads back a random 2% of the data to check the repository.

Retention is 7 daily, 5 weekly and 12 monthly snapshots.

Two jobs are special. `immich-media` backs up the photos on the Hetzner storage box (`/mnt/fs-01b/immich`), which is CIFS, so it skips the ZFS snapshot (`zfsSnapshot = false`). `immich-db` backs up `/var/backup/postgresql/immich.sql.zstd`, a dump that `postgresqlBackup` writes at 01:15, because Immich uses its own local PostgreSQL on `faithplate`.

> [!WARNING]
> One trap: services with `DynamicUser` keep their data in `/var/lib/private/<name>`, and `/var/lib/<name>` is only a symlink. restic stores a symlink as a symlink, so the source must be the real directory. This went unnoticed for months on three services.

**PostgreSQL on `freeman` (pgBackRest).** WAL is archived continuously to both repositories, so a restore can go to any point in time. Full backups run on Sundays and incremental ones the other days: repo 1 (Fastly S3, `/postgresql`) at midnight, repo 2 (`kleiner`) at 03:00. Each repository keeps 4 full backups, so about a month of history.

Archiving is asynchronous, so each repository receives WAL independently: when `kleiner` is off, Fastly stays current and PostgreSQL keeps the WAL `kleiner` hasn't received yet. Past 8 GiB (`archive-push-queue-max`) that WAL is dropped to protect the disk, and `kleiner` can't restore past that point until its next full backup. `WalArchivingStalled` fires after 30 minutes without archiving, and the backup jobs to Fastly still run while `kleiner` is unreachable.

**Not backed up:**
- Nextcloud's files, Versia's media and Sharkey's media. They live only in Fastly buckets.
- Nextcloud's `/var/lib/nextcloud`, which holds `config.php` and its instance secrets.

**Checking on them:**

```bash
systemctl list-timers 'restic-*' 'pgbackrest-*' 'postgresqlBackup-*'
journalctl -u restic-backups-s3-synapse -n 30
restic-s3-synapse snapshots
```

The Grafana dashboard's backup table shows how long ago each job last ran, and `BackupStale` fires after 36 hours (8 days for the weekly full PostgreSQL backups).

## Restoring

Stop the service before restoring over its data, and restore into a temporary directory first when you can.

**From restic.** Every job has a wrapper (`restic-s3-<name>`, `restic-sftp-<name>`) with the credentials already loaded. Snapshots taken from ZFS keep the snapshot path, `/.zfs/snapshot/restic-<job>/<source>`, so point the restore at that subfolder:

```bash
restic-s3-vaultwarden snapshots

# Restore the latest snapshot's contents into /tmp/restore
restic-s3-vaultwarden restore 'latest:/.zfs/snapshot/restic-s3-vaultwarden/var/lib/vaultwarden' --target /tmp/restore

# Add --dry-run to see what would be restored without writing anything
# Use a snapshot ID instead of "latest" for an older one
# From kleiner instead: restic-sftp-vaultwarden ..., with restic-sftp-vaultwarden in the path too
```

Then stop the service, move its directory aside, copy the restored one into place with the right owner, and start it again.

`immich-media` has no snapshot prefix: `restic-s3-immich-media restore latest --target /tmp/restore` gives `/tmp/restore/mnt/fs-01b/immich`.

**The Immich database.** Restore `immich-db` as above, then load the dump:

```bash
systemctl stop immich-server
sudo -u postgres dropdb immich
sudo -u postgres createdb -O immich immich
zstdcat /tmp/restore/immich.sql.zstd | sudo -u postgres psql immich
systemctl start immich-server
```

**PostgreSQL on `freeman`.** pgBackRest needs the S3 credentials from the environment file. Without them, even `info` fails. Open a shell as `postgres` with them loaded:

```bash
sudo -u postgres bash
set -a; . /run/secrets/rendered/pgbackrest-s3-env; set +a

pgbackrest --stanza=main info    # backups in both repos
```

Then, with PostgreSQL stopped (`systemctl stop postgresql`, from a root shell):

```bash
# Latest backup plus all archived WAL. Uses repo 1, falling back to repo 2
pgbackrest --stanza=main restore --delta

# Restore from kleiner instead
pgbackrest --stanza=main restore --delta --repo=2

# Point in time
pgbackrest --stanza=main restore --delta --type=time \
  --target='2026-10-05 14:30:00+02' --target-action=promote
```

and `systemctl start postgresql` afterwards.

`--delta` reuses files that haven't changed instead of needing an empty data directory. Restoring rolls back every database on `freeman` at once. To recover a single database, restore to a scratch data directory with `--pg1-path`, start a temporary instance on another port, and `pg_dump` what you need from it.

## Upgrading PostgreSQL

Major versions of PostgreSQL on `freeman` change the on-disk format, so they go through `pg_upgrade`, wrapped in `upgrade-postgresql` (`nix/services/postgresql.nix`). Every service on `faithplate` that uses the database is down meanwhile, usually 10 to 20 minutes.

> [!WARNING]
> Never deploy the new `services.postgresql.package` before running the script: PostgreSQL would start on an empty data directory, and the services would create fresh databases in it.

1. Set `upgradeTo` to the next version and deploy. This only installs the script and the new binaries.
2. Check the clusters are compatible, without stopping anything: `upgrade-postgresql --check`
3. Take a full backup to both repositories (`systemctl start pgbackrest-main-full`, then `pgbackrest-main-full-kleiner`).
4. Stop the services on `faithplate` that use the database, then on `freeman`:

   ```bash
   systemctl stop postgresql
   zfs snapshot zroot/root@pre-pg-upgrade      # the old data directory, for rolling back
   upgrade-postgresql                         # pg_upgrade --link into /var/lib/postgresql/<new>
   ```

5. Set `services.postgresql.package` to the new version and deploy `freeman`. PostgreSQL starts on the upgraded directory.
6. Follow what `pg_upgrade` printed at the end (`vacuumdb --all --analyze-in-stages --missing-stats-only`), then move the backups to the new version, with the S3 credentials loaded as in [Restoring](#restoring):

   ```bash
   pgbackrest --stanza=main stanza-upgrade
   systemctl start pgbackrest-main-full pgbackrest-main-full-kleiner
   ```

7. Start the services on `faithplate` again.

To roll back before step 6, stop PostgreSQL, clone the snapshot (`zfs clone zroot/root@pre-pg-upgrade zroot/pg-rollback`), copy the old data directory back from it, and deploy the previous package. Once everything works, delete the snapshot and the old data directory.

## Minecraft

`eli` runs one server, `wiki`, with the Yuri-Aero modpack. Players connect to `mc.cpluspatch.com`, which is HAProxy on `faithplate` forwarding to `eli` over the private network, so `eli` doesn't expose the game port publicly. The other modpacks in `assets/` are from older servers.

```bash
journalctl -u minecraft-server-<name> -f                   # console output
echo 'neoforge tps' > /run/minecraft/<name>.stdin          # run a console command
systemctl restart minecraft-server-<name>
```

The RCON password is `minecraft/rcon_password` in `secrets/eli.yaml`, on port 10003.

The JVM settings and `server.properties` come from `nix/services/minecraft.nix`: a 5 GiB heap with G1 and Aikar's flags. Don't go above 5 GiB, since the host only has 8 GiB and ZFS' cache is capped at 1 GiB to leave room for it.

Updating the modpack means replacing the `.mrpack` in `assets/` and updating `packHash` in `minecraft.nix`. The build prints the right hash if it's wrong. Mods that crash on startup can go in `excludedMods`.

## Routine maintenance

- **Health** :

    ```bash
    systemctl --failed
    zpool status                 # scrubs run automatically
    journalctl -p err -b         # errors since boot
    ```

- **Disk and logs** : The Nix store is garbage-collected weekly, removing generations older than 14 days. Journald keeps at most 500 MB or one month per host, and always leaves 2 GB free. Prometheus keeps 90 days or 5 GB, whichever comes first.

- **Certificates** : they renew on their own and reload HAProxy, Postfix and Dovecot as needed. To force a renewal:

    ```bash
    systemctl start acme-order-renew-wildcard-cpluspatch-com
    journalctl -u acme-order-renew-wildcard-cpluspatch-com -f
    ```

    The challenge uses Cloudflare's resolver (1.1.1.1) for its propagation check, because the local resolver caches the missing TXT record and the check never succeeds.

- **Rebooting** : Check that no backup is running first (`systemctl list-units --state=activating,active 'restic-backups-*.service' 'pgbackrest-*.service'` should list nothing), especially around 03:00, when the pgBackRest backup to `kleiner` can take a while. Reboot `freeman` last if you're doing all three, since everything else depends on it. Services on `faithplate` reconnect by themselves once it's back. Versia waits for the databases before starting.

## Setting up a new host

> [!NOTE]
> This hasn't been done end to end since the move to per-host secrets. Expect to adjust it.

1. Add an entry to `local.servers` in `terraform/servers.tf`, then `tofu apply`. This creates the server with Ubuntu and adds its addresses to `nixos-vars.json`.
2. Generate its SSH host key: `./scripts/new-host-key.sh <host>`. It prints an age key and a directory.
3. Add the age key to `.sops.yaml`, plus a creation rule for `secrets/<host>.yaml` if it needs its own secrets. Then run `sops updatekeys secrets/common.yaml` (and any other file it should read).
4. Create `nix/hosts/<host>/default.nix` with a new `networking.hostId` (`head -c4 /dev/urandom | od -A none -t x4`). The disk defaults to `/dev/sda` and the hardware config is shared, as every Hetzner VM is the same. Add `<host>.imports` to the hive in `flake.nix`, and the host to `hosts` in `secrets/registry.nix` for the files it reads.
5. Install NixOS over the Ubuntu image:

   ```bash
   nix build .#colmenaHive.nodes.<host>.config.system.build.diskoScript -o disko
   nix build .#colmenaHive.toplevel.<host> -o system
   nix run github:nix-community/nixos-anywhere -- \
     --store-paths ./disko ./system \
     --extra-files <directory from step 2> root@<public ip>
   ```

6. Delete the key directory from step 2. From then on, deploy with `colmena apply --on <host>`.
