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

## Overview

## Tools

This project is largely centered around [**Nix**](https://nixos.org/), as well as [**Terraform**](https://www.terraform.io/).

Nix is used for:
- Partitioning hosts' disks
- Managing packages, services and configuration on hosts
- Operating system configuration and upgrades

Terraform is used for:
- Provisioning cloud infrastructure (primarily from [**Hetzner Cloud**](https://www.hetzner.com/cloud))
- Bootstrapping NixOS on newly created hosts
- Managing DNS records (via [**Cloudflare**](https://www.cloudflare.com/))
- Deploying NixOS configuration changes to hosts

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

NixOS configuration changes are deployed to hosts using [`nixos-anywhere`'s Terraform module](https://github.com/numtide/nixos-anywhere/terraform/all-in-one).

The command to deploy changes is:

```bash
# Using OpenTofu :)
tofu -chdir=terraform apply
```