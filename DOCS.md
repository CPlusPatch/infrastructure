<!-- omit in toc -->
# Documentation

- [Overview](#overview)
- [Tools](#tools)
- [Structure](#structure)
  - [📂 `assets/`](#-assets)
  - [📂 `html/`](#-html)
  - [📂 `nix/`](#-nix)
  - [📂 `secrets/`](#-secrets)
  - [📂 `terraform/`](#-terraform)
- [Deployment](#deployment)
- [Backups](#backups)
  - [General services (restic)](#general-services-restic)
  - [PostgreSQL (pgbackrest)](#postgresql-pgbackrest)
  - [Restoring from a restic backup](#restoring-from-a-restic-backup)
  - [Restoring from a pgbackrest backup](#restoring-from-a-pgbackrest-backup)

## Overview

Three [Hetzner Cloud](https://www.hetzner.com/cloud) servers managed as a NixOS fleet:

| Host | Type | Role |
|------|------|------|
| **Faithplate** | cx33 | Primary services host (web, applications, proxying) |
| **Freeman** | cx23 | Backend services (databases, monitoring) |
| **Eli** | cx33 | Minecraft server host |

## Tools

This project is largely centered around [**Nix**](https://nixos.org/), [**Terraform**](https://www.terraform.io/), and [**Colmena**](https://colmena.cli.rs/).

Nix is used for:
- Partitioning hosts' disks
- Managing packages, services and configuration on hosts
- Operating system configuration and upgrades

Terraform is used for:
- Provisioning cloud infrastructure (primarily from [**Hetzner Cloud**](https://www.hetzner.com/cloud))
- Bootstrapping NixOS on newly created hosts
- Managing DNS records (via [**Cloudflare**](https://www.cloudflare.com/))
- Generating `nixos-vars.json` with host IP/network data consumed by Nix

Colmena is used for:
- Deploying NixOS configuration changes to running hosts

> [!NOTE]
> This project is fully IPv4/IPv6 dual stack. All DNS records, server configurations, and services are set up to support both protocols when interfacing with the public internet.
>
> IPv6 is typically used in internal communication between services.

## Structure

The repository is structured as follows:

```
├── 📂 assets/
├── 📂 html/
├── 📂 nix/
│   ├── 📂 features/
│   ├── 📂 hosts/
│   ├── 📂 lib/
│   ├── 📂 modules/
│   ├── 📂 packages/
│   ├── 📂 secrets/
│   └── 📂 services/
├── 📂 secrets/
├── 📂 terraform/
│   ├── 📄 dns.tf
│   ├── 📄 nixos-vars.json
│   ├── 📄 servers.tf
├── 📄 flake.nix
```

### 📂 `assets/`

Contains assets used for various purposes, such as website images.

### 📂 `html/`

Has static HTML hosted by the web server, mostly for custom 5xx error pages.

### 📂 `nix/`

Houses all NixOS-related code, including host configurations, Nix packages, services, and modules.

<!-- omit in toc -->
#### 📂 `nix/hosts/`

Contains host-specific configurations and definitions. All hosts have their own folder named after their hostname, and inherit from common configurations in the `base` host folder.

Host configurations import from the other folders in `nix/` to compose their full configuration.

<!-- omit in toc -->
#### 📂 `nix/modules/`

Contains various custom NixOS modules.

<!-- omit in toc -->
#### 📂 `nix/services/`

Configuration and definition for individual services, such as web servers, databases, etc. Each file typically defines a single service.

Hosts then import the service definitions they need.

### 📂 `secrets/`

This project uses [`sops-nix`](https://github.com/Mic92/sops-nix) to manage secrets. The `secrets/` folder contains [`age`](https://age-encryption.org/)-encrypted secret files that are used by the NixOS configurations.

### 📂 `terraform/`

Contains all Terraform code for provisioning infrastructure and bootstrapping NixOS on hosts.

<!-- omit in toc -->
#### 📄 `terraform/servers.tf`

Defines [**Hetzner Cloud**](https://www.hetzner.com/cloud) server instances for each host, including their resources (CPU, RAM, disk) and networking (public IPv4/IPv6, private networking). NixOS is bootstrapped on each newly created host using [`nixos-anywhere`'s Terraform module](https://github.com/numtide/nixos-anywhere/terraform/all-in-one).

Additionally, a list of domains is defined for each host, which is then used in `terraform/dns.tf` to create the appropriate DNS records. The list looks like this:

```hcl
domains = {
    "id.cpluspatch.com"           = hcloud_server.faithplate # faithplate is the hostname
    "prowlarr.lgs.cpluspatch.com" = hcloud_server.faithplate
    "radarr.lgs.cpluspatch.com"   = hcloud_server.faithplate
    "sonarr.lgs.cpluspatch.com"   = hcloud_server.faithplate
    "dl.lgs.cpluspatch.com"       = hcloud_server.faithplate
    # ...
}
```

<!-- omit in toc -->
#### 📄 `terraform/dns.tf`

Defines DNS records for each host using the Cloudflare provider, with the naming scheme `hostname.infra.cpluspatch.com`. These are automatically calculated from the host definitions in `terraform/servers.tf`.

`CNAME` records are then created for every domain defined in `terraform/servers.tf` that points to the corresponding `hostname.infra.cpluspatch.com` record.

Also defines custom non-A/AAAA/CNAME DNS records, such as email or SRV records.

<!-- omit in toc -->
#### 📄 `terraform/nixos-vars.json`

This file is used to pass variables from Terraform to NixOS during the bootstrapping process, such as IP addresses for network configuration and hostnames. It is generated automatically by Terraform and should not be modified manually.

## Deployment

### Provisioning new hosts

New hosts are provisioned with Terraform/OpenTofu, which also bootstraps NixOS via `nixos-anywhere`:

```bash
tofu -chdir=terraform apply
```

### Deploying configuration changes

NixOS configuration changes are deployed to running hosts using [**Colmena**](https://colmena.cli.rs/):

```bash
# Deploy to all hosts
colmena apply

# Deploy to a specific host
colmena apply --on faithplate

# Deploy to hosts with a specific tag
colmena apply --on @infra
```

Colmena reads the `colmenaHive` output from `flake.nix`, which defines each host's deployment target (`targetHost`) and tags.

## Backups

All backup configuration lives in `nix/modules/backups.nix` (general services) and `nix/modules/postgresql.nix` (PostgreSQL). Every backup is written to two independent targets:

| Target | Technology | Location |
|--------|-----------|----------|
| **Primary** | S3 (Fastly) | `eu-central.object.fastlystorage.app` / bucket `backups` |
| **Secondary** | SFTP | `kleiner:/mnt/HDD1/Backups/Infra` |

### General services (restic)

Most services declare a backup job via `services.backups.jobs.<name>.source = "<path>"` in their service file (e.g. `nix/services/vaultwarden.nix`). The `backups` module translates each job into two `services.restic.backups` entries — `s3-<name>` and `sftp-<name>` — running daily with a randomised up-to-3-hour delay.

**Retention policy:** 7 daily · 5 weekly · 12 monthly

The wrapper scripts created by the NixOS module allow manual operations:

```bash
# List snapshots for a job
restic-s3-vaultwarden snapshots
restic-sftp-vaultwarden snapshots

# Check repository integrity
restic-s3-mail check
```

### PostgreSQL (pgbackrest)

PostgreSQL uses [pgbackrest](https://pgbackrest.org/) rather than restic, as pgbackrest performs continuous WAL archiving in addition to scheduled full backups.

**Repositories:**

| Index | Type | Location |
|-------|------|----------|
| 1 | S3 | `eu-central.object.fastlystorage.app/backups/postgresql` |
| 2 | SFTP | `kleiner:/mnt/HDD1/Backups/Infra/postgresql` |

**Schedule:** full backup daily, WAL continuously archived to both repos.

**Retention:** 10 full backups kept.

### Restoring from a restic backup

The NixOS restic module generates a wrapper script per backup job that pre-loads all required environment variables.

```bash
# 1. List available snapshots
restic-s3-<name> snapshots         # from S3
restic-sftp-<name> snapshots       # from SFTP fallback

# 2. Restore the latest snapshot to a target directory
restic-s3-<name> restore latest --target /tmp/restore-<name>

# 3. Restore a specific snapshot
restic-s3-<name> restore <snapshot-id> --target /tmp/restore-<name>

# 4. Restore only specific paths within a snapshot
restic-s3-<name> restore latest --target / --include /var/lib/<service>
```

Replace `<name>` with the job name (e.g. `vaultwarden`, `synapse`, `mail`, `clickhouse`).

### Restoring from a pgbackrest backup

pgbackrest restores require PostgreSQL to be stopped first.

```bash
# 1. Stop PostgreSQL
systemctl stop postgresql

# 2. Check available backups
sudo -u postgres pgbackrest --stanza=main info

# 3a. Restore the latest backup (from the fastest available repo)
sudo -u postgres pgbackrest --stanza=main restore

# 3b. Restore from a specific repo (1 = S3, 2 = SFTP)
sudo -u postgres pgbackrest --stanza=main restore --repo=1

# 3c. Point-in-time recovery to a specific timestamp
sudo -u postgres pgbackrest --stanza=main restore \
  --target="2026-01-15 10:30:00" \
  --target-action=promote

# 4. Start PostgreSQL
systemctl start postgresql
```
