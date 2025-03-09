#!/usr/bin/env bash
# Decrypts the age key from the sops file and writes it to a file

set -euo pipefail -x

mkdir -p var/lib/secrets

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

umask 0177
# I don't have nonroot Nix access on my machine, so I'm using sudo
sudo nix-shell -p sops --run "sops decrypt --extract '[\"age-key\"]' "$SCRIPT_DIR/$SOPS_FILE" >./var/lib/secrets/age"
# restore umask
umask 0022