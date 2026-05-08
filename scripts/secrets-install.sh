#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
encrypted="${DOTFILES_SECRETS_FILE:-$repo_root/secrets/secrets.env.age}"
identity="${DOTFILES_AGE_IDENTITY:-$HOME/.config/dotfiles/age-key.txt}"
output="${DOTFILES_SECRETS_ENV:-$HOME/.config/dotfiles/secrets.env}"
mode="${DOTFILES_SECRETS_MODE:-auto}"
secret_tmp=""

usage() {
  cat <<'EOF'
Usage: ./scripts/secrets-install.sh [options]

Decrypt shared token environment variables to ~/.config/dotfiles/secrets.env.

Options:
  --passphrase       Decrypt by prompting for the remembered password.
  --identity         Decrypt with an age private key.
  -h, --help         Show this help.

Environment:
  DOTFILES_SECRETS_FILE=/path/to/secrets.env.age
  DOTFILES_SECRETS_ENV=~/.config/dotfiles/secrets.env
  DOTFILES_SECRETS_MODE=auto|passphrase|identity
  DOTFILES_AGE_IDENTITY=~/.config/dotfiles/age-key.txt
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      --passphrase)
        mode="passphrase"
        ;;
      --identity)
        mode="identity"
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        printf 'Unknown option: %s\n\n' "$1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done
}

require_age() {
  if ! command -v age >/dev/null 2>&1; then
    printf 'age is not installed. Run ./scripts/install-dev-tools.sh first.\n' >&2
    exit 1
  fi
}

detect_existing_mode() {
  local stanza
  stanza="$(sed -n 's/^-> //p' "$encrypted" | awk 'NR == 1 {print $1}')"

  case "$stanza" in
    scrypt) printf 'passphrase' ;;
    *) printf 'identity' ;;
  esac
}

resolve_mode() {
  case "$mode" in
    auto) detect_existing_mode ;;
    passphrase | identity) printf '%s' "$mode" ;;
    *)
      printf 'Invalid DOTFILES_SECRETS_MODE: %s\n' "$mode" >&2
      exit 1
      ;;
  esac
}

decrypt_to_tmp() {
  local selected_mode tmp
  selected_mode="$1"
  tmp="$2"

  case "$selected_mode" in
    passphrase)
      age --decrypt -o "$tmp" "$encrypted"
      ;;
    identity)
      [[ -f "$identity" ]] || {
        printf 'age identity not found: %s\n' "$identity" >&2
        printf 'Restore your private age key there, chmod 600 it, then rerun this script.\n' >&2
        exit 1
      }
      age --decrypt -i "$identity" -o "$tmp" "$encrypted"
      ;;
  esac
}

main() {
  local selected_mode tmp
  parse_args "$@"
  require_age

  if [[ ! -f "$encrypted" ]]; then
    printf 'Encrypted secrets file not found: %s\n' "$encrypted" >&2
    printf 'Create it with ./scripts/secrets-edit.sh.\n' >&2
    exit 1
  fi

  selected_mode="$(resolve_mode)"
  printf 'Secrets decryption mode: %s\n' "$selected_mode"

  mkdir -p -- "$(dirname -- "$output")"
  tmp="${output}.tmp"
  secret_tmp="$tmp"
  trap 'rm -f -- "$secret_tmp"' EXIT

  umask 077
  decrypt_to_tmp "$selected_mode" "$tmp"
  mv -f -- "$tmp" "$output"
  chmod 600 "$output"

  printf 'Installed decrypted secrets to %s\n' "$output"
  printf 'For this shell, load them with:\n  set -a; . %q; set +a\n' "$output"
}

main "$@"
