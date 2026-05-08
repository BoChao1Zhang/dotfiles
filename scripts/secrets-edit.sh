#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
encrypted="${DOTFILES_SECRETS_FILE:-$repo_root/secrets/secrets.env.age}"
identity="${DOTFILES_AGE_IDENTITY:-$HOME/.config/dotfiles/age-key.txt}"
recipient_file="${DOTFILES_AGE_RECIPIENT_FILE:-$repo_root/secrets/age-recipient.txt}"
mode="${DOTFILES_SECRETS_MODE:-auto}"
editor="${EDITOR:-vi}"
secret_tmp=""

usage() {
  cat <<'EOF'
Usage: ./scripts/secrets-edit.sh [options]

Edit and encrypt shared token environment variables.

Default mode is passphrase encryption for new files. Existing encrypted files
are auto-detected: passphrase files prompt for a password, identity files use
an age private key.

Options:
  --passphrase       Encrypt with a remembered password.
  --identity         Encrypt for an age public recipient.
  -h, --help         Show this help.

Environment:
  DOTFILES_SECRETS_FILE=/path/to/secrets.env.age
  DOTFILES_SECRETS_MODE=auto|passphrase|identity
  DOTFILES_AGE_IDENTITY=~/.config/dotfiles/age-key.txt
  DOTFILES_AGE_RECIPIENT=age1...
  DOTFILES_AGE_RECIPIENT_FILE=secrets/age-recipient.txt
  EDITOR=vim
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

  if [[ ! -f "$encrypted" ]]; then
    printf 'passphrase'
    return
  fi

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

resolve_recipient() {
  local recipient
  recipient="${DOTFILES_AGE_RECIPIENT:-}"

  if [[ -z "$recipient" && -f "$recipient_file" ]]; then
    recipient="$(sed -n '/^[[:space:]]*#/d; /^[[:space:]]*$/d; p' "$recipient_file" | sed -n '1p')"
  fi

  if [[ -z "$recipient" && -f "$identity" ]]; then
    recipient="$(sed -n 's/^# public key: //p' "$identity" | sed -n '1p')"
  fi

  if [[ -z "$recipient" ]]; then
    printf 'No age recipient found for identity mode.\n' >&2
    printf 'Set DOTFILES_AGE_RECIPIENT, create %s, or use an identity with a "# public key:" line.\n' "$recipient_file" >&2
    exit 1
  fi

  printf '%s' "$recipient"
}

decrypt_existing() {
  local selected_mode plaintext
  selected_mode="$1"
  plaintext="$2"

  if [[ ! -f "$encrypted" ]]; then
    cp "$repo_root/secrets.example.env" "$plaintext"
    return
  fi

  case "$selected_mode" in
    passphrase)
      age --decrypt -o "$plaintext" "$encrypted"
      ;;
    identity)
      [[ -f "$identity" ]] || {
        printf 'Cannot decrypt identity-encrypted secrets without identity: %s\n' "$identity" >&2
        exit 1
      }
      age --decrypt -i "$identity" -o "$plaintext" "$encrypted"
      ;;
  esac
}

encrypt_updated() {
  local selected_mode plaintext recipient
  selected_mode="$1"
  plaintext="$2"

  case "$selected_mode" in
    passphrase)
      age --passphrase -o "${encrypted}.tmp" "$plaintext"
      ;;
    identity)
      recipient="$(resolve_recipient)"
      age -r "$recipient" -o "${encrypted}.tmp" "$plaintext"
      ;;
  esac
}

main() {
  local selected_mode tmp
  parse_args "$@"
  require_age
  selected_mode="$(resolve_mode)"

  mkdir -p -- "$(dirname -- "$encrypted")"
  tmp="$(mktemp)"
  secret_tmp="$tmp"
  trap 'rm -f -- "$secret_tmp" "${encrypted}.tmp"' EXIT
  chmod 600 "$tmp"

  printf 'Secrets encryption mode: %s\n' "$selected_mode"
  decrypt_existing "$selected_mode" "$tmp"
  "$editor" "$tmp"
  encrypt_updated "$selected_mode" "$tmp"
  mv -f -- "${encrypted}.tmp" "$encrypted"

  printf 'Updated encrypted secrets: %s\n' "$encrypted"
}

main "$@"
