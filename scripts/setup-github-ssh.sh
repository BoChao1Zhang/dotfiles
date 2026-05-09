#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
git_name="${GIT_USER_NAME:-BoChao1Zhang}"
git_email="${GIT_USER_EMAIL:-3210191548@qq.com}"
key_path="${SSH_KEY_PATH:-$HOME/.ssh/id_ed25519}"

usage() {
  cat <<'EOF'
Usage: ./scripts/setup-github-ssh.sh [options]

Options:
  --name NAME       Git commit author name. Defaults to GIT_USER_NAME or BoChao1Zhang.
  --email EMAIL     Git commit author email. Defaults to GIT_USER_EMAIL or 3210191548@qq.com.
  --key PATH        SSH key path. Defaults to ~/.ssh/id_ed25519.
  -h, --help        Show this help.
EOF
}

while (($#)); do
  case "$1" in
    --name)
      shift
      git_name="${1:?--name requires a value}"
      ;;
    --email)
      shift
      git_email="${1:?--email requires a value}"
      ;;
    --key)
      shift
      key_path="${1:?--key requires a value}"
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

need() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

need git
need ssh-keygen

git config --global user.name "$git_name"
git config --global user.email "$git_email"

mkdir -p -- "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

if [[ ! -f "$key_path" || ! -f "$key_path.pub" ]]; then
  printf 'Creating SSH key: %s\n' "$key_path"
  ssh-keygen -t ed25519 -C "$git_email" -f "$key_path" -N ""
fi

chmod 600 "$key_path"
chmod 644 "$key_path.pub"

if command -v ssh-add >/dev/null 2>&1; then
  ssh-add "$key_path" >/dev/null 2>&1 || true
fi

if git -C "$repo_root" remote get-url origin >/dev/null 2>&1; then
  remote_url="$(git -C "$repo_root" remote get-url origin)"
  case "$remote_url" in
    https://github.com/*)
      ssh_url="${remote_url#https://github.com/}"
      ssh_url="git@github.com:${ssh_url}"
      git -C "$repo_root" remote set-url origin "$ssh_url"
      printf 'Changed origin to SSH: %s\n' "$ssh_url"
      ;;
  esac
fi

printf '\nAdd this public key to GitHub SSH keys:\n\n'
cat "$key_path.pub"
printf '\n\nOpen: https://github.com/settings/keys\n'
printf '\nAfter adding it, test with:\n'
printf '  ssh -T git@github.com\n'
