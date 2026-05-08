#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
chezmoi_bin_dir="${CHEZMOI_BIN_DIR:-$HOME/.local/bin}"

has() {
  command -v "$1" >/dev/null 2>&1
}

detect_platform() {
  local kernel distro
  kernel="$(uname -s 2>/dev/null || printf unknown)"

  if [[ "$kernel" == "Darwin" ]]; then
    printf 'macOS'
    return
  fi

  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    distro="${PRETTY_NAME:-${NAME:-${ID:-Linux}}}"
    printf '%s' "$distro"
    return
  fi

  printf '%s' "$kernel"
}

install_chezmoi_official() {
  local platform
  platform="$(detect_platform)"

  mkdir -p -- "$chezmoi_bin_dir"
  export PATH="$chezmoi_bin_dir:$PATH"

  printf 'Installing chezmoi with the official installer on %s...\n' "$platform"
  printf 'Install directory: %s\n' "$chezmoi_bin_dir"

  if has curl; then
    sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$chezmoi_bin_dir"
  elif has wget; then
    sh -c "$(wget -qO- https://get.chezmoi.io)" -- -b "$chezmoi_bin_dir"
  else
    printf 'Neither curl nor wget is installed, so the official chezmoi installer cannot be downloaded.\n' >&2
    printf 'Install curl or wget first, then rerun this script.\n' >&2
    exit 1
  fi
}

if ! command -v chezmoi >/dev/null 2>&1; then
  install_chezmoi_official
fi

chezmoi init --source "$repo_root"
chezmoi diff

printf '\nReview the diff above. Apply with:\n  chezmoi apply\n'
