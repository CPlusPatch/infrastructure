#!/usr/bin/env bash
# Generates the SSH host key for a new host, before installing it.
#
# Hosts decrypt their secrets with their SSH host key, so the key must exist and be a
# sops recipient before the first activation:
#   1. ./scripts/new-host-key.sh <host>
#   2. Add the printed age key to .sops.yaml, then run sops updatekeys on the host's files
#   3. Install with nixos-anywhere --extra-files <printed directory>
#   4. Delete the printed directory
set -euo pipefail

host=${1:?usage: $0 <hostname>}
dir=$(mktemp -d)
mkdir -p "$dir/etc/ssh"
chmod 755 "$dir/etc" "$dir/etc/ssh"
ssh-keygen -q -t ed25519 -N "" -C "root@$host" -f "$dir/etc/ssh/ssh_host_ed25519_key"

echo "age key for .sops.yaml: $(ssh-to-age < "$dir/etc/ssh/ssh_host_ed25519_key.pub")"
echo "extra files for nixos-anywhere: $dir"
