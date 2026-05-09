#!/usr/bin/env bash
set -euo pipefail

local_bin="${LOCAL_BIN:-$HOME/.local/bin}"
nvm_dir="${NVM_DIR:-$HOME/.nvm}"
set_default_shell="${SET_DEFAULT_ZSH:-0}"
target_user="${TARGET_USER:-}"
zsh_path_override="${ZSH_PATH:-}"

usage() {
  cat <<'EOF'
Usage: ./scripts/install-dev-tools.sh [options]

Options:
  --set-default-shell     Set the installed zsh as the target user's login shell.
  --target-user USER      User whose login shell should be changed.
                          Defaults to SUDO_USER when running via sudo, otherwise current user.
  --zsh-path PATH         Explicit zsh path to set as login shell.
  -h, --help              Show this help.

Environment:
  SET_DEFAULT_ZSH=1       Same as --set-default-shell.
  TARGET_USER=USER        Same as --target-user.
  ZSH_PATH=PATH           Same as --zsh-path.
  LOCAL_BIN=PATH          Defaults to ~/.local/bin.
  NVM_DIR=PATH            Defaults to ~/.nvm.
EOF
}

parse_args() {
  while (($#)); do
    case "$1" in
      --set-default-shell)
        set_default_shell=1
        ;;
      --target-user)
        shift
        [[ $# -gt 0 ]] || {
          printf '--target-user requires a value.\n' >&2
          exit 1
        }
        target_user="$1"
        ;;
      --zsh-path)
        shift
        [[ $# -gt 0 ]] || {
          printf '--zsh-path requires a value.\n' >&2
          exit 1
        }
        zsh_path_override="$1"
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
  brew install age ca-certificates curl fzf git jq neovim ripgrep starship tmux wget zoxide zsh
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
    fzf \
    git \
    jq \
    libevent-dev \
    libncurses-dev \
    libncursesw5-dev \
    libpcre2-dev \
    ncurses-dev \
    pkg-config \
    python3 \
    ripgrep \
    wget \
    xclip \
    xsel \
    xz-utils \
    zsh
}

install_starship() {
  if has starship; then
    return
  fi

  mkdir -p "$local_bin"
  printf 'Installing starship prompt...\n'
  curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$local_bin"
}

install_zoxide() {
  if has zoxide; then
    return
  fi

  mkdir -p "$local_bin"
  printf 'Installing zoxide...\n'
  curl -fsSL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
}

install_tmux_plugins() {
  local tpm_dir
  tpm_dir="$HOME/.tmux/plugins/tpm"

  if [[ ! -d "$tpm_dir/.git" ]]; then
    printf 'Installing TPM (Tmux Plugin Manager)...\n'
    mkdir -p "$HOME/.tmux/plugins"
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
  fi

  if [[ -x "$tpm_dir/bin/install_plugins" ]]; then
    printf 'Installing tmux plugins...\n'
    "$tpm_dir/bin/install_plugins" || true
  fi
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

truthy() {
  case "${1:-}" in
    1 | true | TRUE | yes | YES | y | Y | on | ON) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_target_user() {
  if [[ -n "$target_user" ]]; then
    printf '%s' "$target_user"
    return
  fi

  if [[ "${EUID:-$(id -u)}" -eq 0 && -n "${SUDO_USER:-}" && "${SUDO_USER:-}" != "root" ]]; then
    printf '%s' "$SUDO_USER"
    return
  fi

  id -un
}

resolve_zsh_path() {
  local os path
  os="$1"

  if [[ -n "$zsh_path_override" ]]; then
    [[ -x "$zsh_path_override" ]] || {
      printf 'Configured zsh path is not executable: %s\n' "$zsh_path_override" >&2
      exit 1
    }
    printf '%s' "$zsh_path_override"
    return
  fi

  if [[ "$os" == "macos" && -n "${HOMEBREW_PREFIX:-}" ]]; then
    path="$HOMEBREW_PREFIX/bin/zsh"
    [[ -x "$path" ]] && {
      printf '%s' "$path"
      return
    }
  fi

  if [[ "$os" == "ubuntu" && -x /usr/local/bin/zsh ]]; then
    printf '/usr/local/bin/zsh'
    return
  fi

  path="$(command -v zsh || true)"
  [[ -n "$path" && -x "$path" ]] || {
    printf 'zsh is not installed or not executable.\n' >&2
    exit 1
  }
  printf '%s' "$path"
}

ensure_shell_registered() {
  local shell_path
  shell_path="$1"

  if grep -Fxq -- "$shell_path" /etc/shells 2>/dev/null; then
    return
  fi

  printf 'Registering %s in /etc/shells...\n' "$shell_path"
  printf '%s\n' "$shell_path" | as_root tee -a /etc/shells >/dev/null
}

current_login_shell() {
  local user os
  user="$1"
  os="$2"

  if [[ "$os" == "macos" ]] && has dscl; then
    dscl . -read "/Users/$user" UserShell 2>/dev/null | awk '{print $2}'
    return
  fi

  if has getent; then
    getent passwd "$user" | awk -F: '{print $7}'
    return
  fi

  awk -F: -v user="$user" '$1 == user {print $7}' /etc/passwd 2>/dev/null || true
}

set_zsh_as_default_shell() {
  local os user shell_path current_shell
  os="$1"
  user="$(resolve_target_user)"
  shell_path="$(resolve_zsh_path "$os")"
  current_shell="$(current_login_shell "$user" "$os")"

  ensure_shell_registered "$shell_path"

  if [[ "$current_shell" == "$shell_path" ]]; then
    printf 'Default shell already set for %s: %s\n' "$user" "$shell_path"
    return
  fi

  printf 'Setting default shell for %s to %s...\n' "$user" "$shell_path"
  as_root chsh -s "$shell_path" "$user"
  printf 'Default shell updated. Start a new login session to use it.\n'
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
  parse_args "$@"
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
  install_starship
  install_zoxide
  install_tmux_plugins
  print_versions

  if truthy "$set_default_shell"; then
    set_zsh_as_default_shell "$os"
  fi

  printf '\nDone. Restart your shell, or run:\n'
  printf '  export PATH="%s:$PATH"\n' "$local_bin"
  printf '  export NVM_DIR="%s"\n' "$nvm_dir"
  printf '  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"\n'
  printf '\nTo set zsh as your login shell during install, rerun with:\n'
  printf '  ./scripts/install-dev-tools.sh --set-default-shell\n'
}

main "$@"
