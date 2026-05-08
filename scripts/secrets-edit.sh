#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
encrypted="${DOTFILES_SECRETS_FILE:-$repo_root/secrets/secrets.env.age}"
identity="${DOTFILES_AGE_IDENTITY:-$HOME/.config/dotfiles/age-key.txt}"
recipient_file="${DOTFILES_AGE_RECIPIENT_FILE:-$repo_root/secrets/age-recipient.txt}"
editor="${EDITOR:-vi}"

if ! command -v age >/dev/null 2>&1; then
  printf 'age is not installed. Run ./scripts/install-dev-tools.sh first.\n' >&2
  exit 1
fi

recipient="${DOTFILES_AGE_RECIPIENT:-}"
if [[ -z "$recipient" && -f "$recipient_file" ]]; then
  recipient="$(sed -n '/^[[:space:]]*#/d; /^[[:space:]]*$/d; p' "$recipient_file" | sed -n '1p')"
fi
if [[ -z "$recipient" && -f "$identity" ]]; then
  recipient="$(sed -n 's/^# public key: //p' "$identity" | sed -n '1p')"
fi
if [[ -z "$recipient" ]]; then
  printf 'No age recipient found.\n' >&2
  printf 'Set DOTFILES_AGE_RECIPIENT, create %s, or use an identity with a "# public key:" line.\n' "$recipient_file" >&2
  exit 1
fi

mkdir -p -- "$(dirname -- "$encrypted")"
tmp="$(mktemp)"
trap 'rm -f -- "$tmp" "${encrypted}.tmp"' EXIT
chmod 600 "$tmp"

if [[ -f "$encrypted" ]]; then
  [[ -f "$identity" ]] || {
    printf 'Cannot decrypt existing secrets without identity: %s\n' "$identity" >&2
    exit 1
  }
  age --decrypt -i "$identity" -o "$tmp" "$encrypted"
else
  cp "$repo_root/secrets.example.env" "$tmp"
fi

"$editor" "$tmp"
age -r "$recipient" -o "${encrypted}.tmp" "$tmp"
mv -f -- "${encrypted}.tmp" "$encrypted"

printf 'Updated encrypted secrets: %s\n' "$encrypted"
