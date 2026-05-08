#!/usr/bin/env bash
set -euo pipefail

local_bin="${LOCAL_BIN:-$HOME/.local/bin}"
nvm_dir="${NVM_DIR:-$HOME/.nvm}"

has() {
  command -v "$1" >/dev/null 2>&1
}

as_root() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    "$@"
  elif has sudo; then
    sudo "$@"
  else
    printf 'This step needs root privileges, but sudo is not installed.\n' >&2
    exit 1
  fi
}

detect_os() {
  local kernel
  kernel="$(uname -s 2>/dev/null || printf unknown)"

  case "$kernel" in
    Darwin) printf 'macos' ;;
    Linux)
      if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID:-}" in
          ubuntu) printf 'ubuntu' ;;
          *) printf 'linux' ;;
        esac
      else
        printf 'linux'
      fi
      ;;
    *) printf 'unsupported' ;;
  esac
}

github_latest_tag() {
  local repo latest_url tag
  repo="$1"
  latest_url="$(curl -fsLI -o /dev/null -w '%{url_effective}' "https://github.com/${repo}/releases/latest")"
  tag="${latest_url##*/}"
  [[ -n "$tag" && "$tag" != "latest" ]] || {
    printf 'Could not resolve latest release tag for %s\n' "$repo" >&2
    exit 1
  }
  printf '%s' "$tag"
}

ensure_homebrew() {
  if ! has brew; then
    printf 'Installing Homebrew...\n'
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

install_macos_packages() {
  ensure_homebrew
  brew update
  brew install age ca-certificates curl git neovim ripgrep tmux wget zsh
}

install_ubuntu_packages() {
  as_root apt-get update
  as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y \
    age \
    autoconf \
    automake \
    bison \
    build-essential \
    byacc \
    ca-certificates \
    curl \
    file \
    git \
    libevent-dev \
    libncurses-dev \
    libncursesw5-dev \
    libpcre2-dev \
    ncurses-dev \
    pkg-config \
    ripgrep \
    wget \
    xz-utils \
    zsh
}

install_nvm_and_node() {
  local nvm_tag tmp installer
  mkdir -p "$local_bin"

  if [[ ! -s "$nvm_dir/nvm.sh" ]]; then
    nvm_tag="$(github_latest_tag nvm-sh/nvm)"
    tmp="$(mktemp -d)"
    installer="$tmp/install-nvm.sh"
    printf 'Installing nvm %s...\n' "$nvm_tag"
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${nvm_tag}/install.sh" -o "$installer"
    PROFILE=/dev/null bash "$installer"
    rm -rf "$tmp"
  fi

  # shellcheck disable=SC1091
  . "$nvm_dir/nvm.sh"
  nvm install node --latest-npm
  nvm alias default node
  nvm use default
}

install_npm_tools() {
  # shellcheck disable=SC1091
  . "$nvm_dir/nvm.sh"
  nvm use default
  npm install -g @openai/codex@latest @anthropic-ai/claude-code@latest
}

install_neovim_linux_latest() {
  local machine nvim_arch archive tmp
  machine="$(uname -m)"

  case "$machine" in
    x86_64 | amd64) nvim_arch="x86_64" ;;
    arm64 | aarch64) nvim_arch="arm64" ;;
    *)
      printf 'Unsupported Linux architecture for Neovim prebuilt archive: %s\n' "$machine" >&2
      return 1
      ;;
  esac

  tmp="$(mktemp -d)"
  archive="$tmp/nvim-linux-${nvim_arch}.tar.gz"

  printf 'Installing latest stable Neovim prebuilt archive for Linux %s...\n' "$nvim_arch"
  curl -fL "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-${nvim_arch}.tar.gz" -o "$archive"
  as_root rm -rf "/opt/nvim-linux-${nvim_arch}"
  as_root tar -C /opt -xzf "$archive"
  as_root ln -sf "/opt/nvim-linux-${nvim_arch}/bin/nvim" /usr/local/bin/nvim
  rm -rf "$tmp"
}

install_tmux_linux_latest() {
  local tag version tmp archive jobs
  tag="$(github_latest_tag tmux/tmux)"
  version="${tag#v}"
  tmp="$(mktemp -d)"
  archive="$tmp/tmux-${version}.tar.gz"
  jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 2)"

  printf 'Building tmux %s from release tarball...\n' "$version"
  curl -fL "https://github.com/tmux/tmux/releases/download/${tag}/tmux-${version}.tar.gz" -o "$archive"
  tar -C "$tmp" -xzf "$archive"
  (
    cd "$tmp/tmux-${version}"
    ./configure --prefix=/usr/local
    make -j "$jobs"
    as_root make install
  )
  rm -rf "$tmp"
}

install_zsh_linux_latest() {
  local tmp archive src_dir jobs
  tmp="$(mktemp -d)"
  archive="$tmp/zsh-latest.tar.xz"
  jobs="$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 2)"

  printf 'Building latest zsh from upstream release archive...\n'
  curl -fL "https://sourceforge.net/projects/zsh/files/latest/download" -o "$archive"
  src_dir="$(tar -tf "$archive" | sed -n '1p' | cut -d / -f 1)"
  tar -C "$tmp" -xf "$archive"
  (
    cd "$tmp/$src_dir"
    ./configure --prefix=/usr/local --enable-multibyte
    make -j "$jobs"
    as_root make install
  )

  if ! grep -qx '/usr/local/bin/zsh' /etc/shells 2>/dev/null; then
    printf '/usr/local/bin/zsh\n' | as_root tee -a /etc/shells >/dev/null
  fi

  rm -rf "$tmp"
}

print_versions() {
  printf '\nInstalled versions:\n'
  node --version 2>/dev/null || true
  npm --version 2>/dev/null || true
  codex --version 2>/dev/null || true
  claude --version 2>/dev/null || true
  nvim --version 2>/dev/null | sed -n '1p' || true
  tmux -V 2>/dev/null || true
  zsh --version 2>/dev/null || true
  age --version 2>/dev/null | sed -n '1p' || true
}

main() {
  local os
  os="$(detect_os)"

  export PATH="$local_bin:$PATH"

  case "$os" in
    macos)
      install_macos_packages
      ;;
    ubuntu)
      install_ubuntu_packages
      install_neovim_linux_latest
      install_tmux_linux_latest
      install_zsh_linux_latest
      ;;
    *)
      printf 'Unsupported OS: %s. This script currently supports macOS and Ubuntu.\n' "$os" >&2
      exit 1
      ;;
  esac

  install_nvm_and_node
  install_npm_tools
  print_versions

  printf '\nDone. Restart your shell, or run:\n'
  printf '  export PATH="%s:$PATH"\n' "$local_bin"
  printf '  export NVM_DIR="%s"\n' "$nvm_dir"
  printf '  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n'
  printf '\nTo make the newly installed zsh your login shell, run manually after checking /usr/local/bin/zsh:\n'
  printf '  chsh -s /usr/local/bin/zsh\n'
}

main "$@"
