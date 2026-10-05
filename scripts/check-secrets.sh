#!/usr/bin/env bash
# Checks the sops files against the registry (secrets/registry.nix, passed as JSON):
# every file holds exactly the registered keys, and is encrypted for exactly its hosts and the
# admins, as .sops.yaml says. Key names and recipients are plaintext, so nothing is decrypted.
#   check-secrets.sh <registry.json> <repository root>
set -euo pipefail

registry=$1
cd "$2"
status=0

fail() {
  echo "$1" >&2
  status=1
}

# Anchor name => age key, from the keys list in .sops.yaml
declare -A keys
while read -r name key; do
  keys[$name]=$key
done < <(yq '.keys[] | anchor + " " + .' .sops.yaml)

for name in $(jq -r 'keys[]' "$registry"); do
  file=secrets/$name.yaml

  # Keys, as the slash-separated paths sops-nix uses
  actual=$(yq '[.. | select(tag == "!!str") | path | join("/")] | .[] | select(test("^sops/") | not)' "$file" | sort)
  expected=$(jq -r --arg name "$name" '.[$name].secrets[]' "$registry" | sort)
  diff <(echo "$expected") <(echo "$actual") > /dev/null ||
    fail "$file: keys differ from the registry (< registry, > file):
$(diff <(echo "$expected") <(echo "$actual") | grep '^[<>]')"

  # The first creation rule matching the file, as sops picks it
  aliases=""
  while read -r regex rule; do
    if [[ $file =~ $regex ]]; then
      aliases=$rule
      break
    fi
  done < <(yq '.creation_rules[] | .path_regex + " " + ([.key_groups[].age[] | alias] | join(","))' .sops.yaml)

  ruleHosts=$(tr , '\n' <<< "$aliases" | grep -v '^admin_' | sort)
  registryHosts=$(jq -r --arg name "$name" '.[$name].hosts[]' "$registry" | sort)
  [[ $ruleHosts == "$registryHosts" ]] ||
    fail "$file: .sops.yaml encrypts it for [$(echo $ruleHosts)], the registry says [$(echo $registryHosts)]"

  # Recipients the file is actually encrypted for, which only change with sops updatekeys
  expectedRecipients=$(tr , '\n' <<< "$aliases" | while read -r alias; do echo "${keys[$alias]}"; done | sort)
  actualRecipients=$(yq '.sops.age[].recipient' "$file" | sort)
  [[ $expectedRecipients == "$actualRecipients" ]] ||
    fail "$file: recipients differ from .sops.yaml, run: sops updatekeys $file"
done

exit $status
