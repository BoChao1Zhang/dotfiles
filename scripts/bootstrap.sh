#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
chezmoi_bin_dir="${CHEZMOI_BIN_DIR:-$HOME/.local/bin}"

has() {
  command -v "$1" >/dev/null 2>&1
}

toml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
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

configure_chezmoi_source() {
  local config_home config_file escaped_source

  config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
  config_file="${CHEZMOI_CONFIG_FILE:-$config_home/chezmoi/chezmoi.toml}"
  escaped_source="$(toml_escape "$repo_root")"

  if [[ ! -e "$config_file" ]]; then
    mkdir -p -- "$(dirname -- "$config_file")"
    printf 'sourceDir = "%s"\n' "$escaped_source" > "$config_file"
    printf 'Configured chezmoi sourceDir in %s\n' "$config_file"
    return
  fi

  if grep -Eq '^[[:space:]]*sourceDir[[:space:]]*=' "$config_file"; then
    printf 'Using existing chezmoi config: %s\n' "$config_file"
    return
  fi

  {
    printf '\n'
    printf 'sourceDir = "%s"\n' "$escaped_source"
  } >> "$config_file"
  printf 'Added chezmoi sourceDir to %s\n' "$config_file"
}

if ! command -v chezmoi >/dev/null 2>&1; then
  install_chezmoi_official
fi

configure_chezmoi_source

chezmoi --source "$repo_root" diff

printf '\nReview the diff above. Apply with:\n  chezmoi --source %q apply\n' "$repo_root"
