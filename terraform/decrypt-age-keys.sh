#!/usr/bin/env bash
# Decrypts the age key from the sops file and writes it to a file

set -euo pipefail -x

mkdir -p var/lib/secrets

umask 0177
sops --extract '["age-key"]' -d "$SOPS_FILE" >./var/lib/secrets/age
# restore umask
umask 0022