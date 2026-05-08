#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
encrypted="${DOTFILES_SECRETS_FILE:-$repo_root/secrets/secrets.env.age}"
identity="${DOTFILES_AGE_IDENTITY:-$HOME/.config/dotfiles/age-key.txt}"
output="${DOTFILES_SECRETS_ENV:-$HOME/.config/dotfiles/secrets.env}"

if ! command -v age >/dev/null 2>&1; then
  printf 'age is not installed. Run ./scripts/install-dev-tools.sh first.\n' >&2
  exit 1
fi

if [[ ! -f "$encrypted" ]]; then
  printf 'Encrypted secrets file not found: %s\n' "$encrypted" >&2
  printf 'Create it with ./scripts/secrets-edit.sh after setting up an age key.\n' >&2
  exit 1
fi

if [[ ! -f "$identity" ]]; then
  printf 'age identity not found: %s\n' "$identity" >&2
  printf 'Restore your private age key there, chmod 600 it, then rerun this script.\n' >&2
  exit 1
fi

mkdir -p -- "$(dirname -- "$output")"
tmp="${output}.tmp"
trap 'rm -f -- "$tmp"' EXIT

umask 077
age --decrypt -i "$identity" -o "$tmp" "$encrypted"
mv -f -- "$tmp" "$output"
chmod 600 "$output"

printf 'Installed decrypted secrets to %s\n' "$output"
printf 'For this shell, load them with:\n  set -a; . %q; set +a\n' "$output"

