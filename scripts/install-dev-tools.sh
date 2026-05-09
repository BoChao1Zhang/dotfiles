#!/usr/bin/env bash
set -euo pipefail

local_bin="${LOCAL_BIN:-$HOME/.local/bin}"
nvm_dir="${NVM_DIR:-$HOME/.nvm}"
tool_prefix="${DOTFILES_TOOL_PREFIX:-$HOME/.local/share/dotfiles/toolchain}"
tool_bin="$tool_prefix/bin"
mamba_root="${MAMBA_ROOT_PREFIX:-$HOME/.local/share/micromamba}"
set_default_shell="${SET_DEFAULT_ZSH:-0}"
target_user="${TARGET_USER:-}"
zsh_path_override="${ZSH_PATH:-}"
upgrade_tools="${DOTFILES_UPGRADE_TOOLS:-0}"
reload_shell="${DOTFILES_RELOAD_SHELL:-auto}"

usage() {
  cat <<'EOF'
Usage: ./scripts/install-dev-tools.sh [options]

Options:
  --set-default-shell     Set the installed zsh as the target user's login shell.
  --target-user USER      User whose login shell should be changed.
                          Defaults to SUDO_USER when running via sudo, otherwise current user.
  --zsh-path PATH         Explicit zsh path to set as login shell.
  --upgrade               Upgrade tools that are already installed.
  --no-reload-shell       Do not exec a fresh zsh login shell at the end.
  -h, --help              Show this help.

Environment:
  SET_DEFAULT_ZSH=1       Same as --set-default-shell.
  TARGET_USER=USER        Same as --target-user.
  ZSH_PATH=PATH           Same as --zsh-path.
  DOTFILES_UPGRADE_TOOLS=1
                          Same as --upgrade.
  DOTFILES_RELOAD_SHELL=0 Disable the final interactive zsh reload.
  LOCAL_BIN=PATH          Defaults to ~/.local/bin.
  NVM_DIR=PATH            Defaults to ~/.nvm.
  DOTFILES_TOOL_PREFIX=PATH
                          Ubuntu user-local toolchain prefix.
  MAMBA_ROOT_PREFIX=PATH  micromamba root prefix.
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
      --upgrade)
        upgrade_tools=1
        ;;
      --no-reload-shell)
        reload_shell=0
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
  local packages missing pkg

  ensure_homebrew
  packages=(age ca-certificates curl fzf git jq neovim ripgrep starship tmux wget zoxide zsh)
  missing=()

  for pkg in "${packages[@]}"; do
    brew list --formula "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done

  if ((${#missing[@]})); then
    HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}" brew install "${missing[@]}"
  else
    printf 'Homebrew packages already installed.\n'
  fi
}

install_ubuntu_user_toolchain() {
  local packages missing pkg micromamba
  packages=(
    age
    ca-certificates
    curl
    fzf
    git
    jq
    neovim
    nodejs
    python
    ripgrep
    starship
    tmux
    wget
    zoxide
    zsh
  )
  missing=()

  install_micromamba

  for pkg in age curl fzf git jq nvim node npm python rg starship tmux wget zoxide zsh; do
    case "$pkg" in
      nvim) [[ -x "$tool_bin/nvim" ]] || missing+=("neovim") ;;
      node) [[ -x "$tool_bin/node" ]] || missing+=("nodejs") ;;
      npm) [[ -x "$tool_bin/npm" ]] || missing+=("nodejs") ;;
      python) [[ -x "$tool_bin/python" ]] || missing+=("python") ;;
      rg) [[ -x "$tool_bin/rg" ]] || missing+=("ripgrep") ;;
      *) [[ -x "$tool_bin/$pkg" ]] || missing+=("$pkg") ;;
    esac
  done

  if ((${#missing[@]})) || truthy "$upgrade_tools"; then
    micromamba="$local_bin/micromamba"
    if [[ -d "$tool_prefix/conda-meta" ]]; then
      MAMBA_ROOT_PREFIX="$mamba_root" "$micromamba" install -y -p "$tool_prefix" -c conda-forge "${packages[@]}"
    else
      MAMBA_ROOT_PREFIX="$mamba_root" "$micromamba" create -y -p "$tool_prefix" -c conda-forge "${packages[@]}"
    fi
    hash -r
    return
  fi

  printf 'Ubuntu user-local toolchain already installed at %s\n' "$tool_prefix"
}

install_micromamba() {
  local arch platform tmp archive

  if [[ -x "$local_bin/micromamba" ]] && ! truthy "$upgrade_tools"; then
    return
  fi

  case "$(uname -m)" in
    x86_64 | amd64) platform="linux-64" ;;
    aarch64 | arm64) platform="linux-aarch64" ;;
    *)
      printf 'Unsupported Ubuntu architecture for micromamba: %s\n' "$(uname -m)" >&2
      exit 1
      ;;
  esac

  mkdir -p "$local_bin" "$mamba_root"
  tmp="$(mktemp -d)"
  archive="$tmp/micromamba.tar.bz2"

  printf 'Installing micromamba into %s...\n' "$local_bin"
  if has curl; then
    curl -fsSL "https://micro.mamba.pm/api/micromamba/${platform}/latest" -o "$archive"
  elif has wget; then
    wget -qO "$archive" "https://micro.mamba.pm/api/micromamba/${platform}/latest"
  else
    printf 'Ubuntu user-local install needs curl or wget to fetch micromamba.\n' >&2
    exit 1
  fi

  tar -xjf "$archive" -C "$tmp" bin/micromamba
  install -m 0755 "$tmp/bin/micromamba" "$local_bin/micromamba"
  rm -rf "$tmp"
  hash -r
}

install_tmux_plugins() {
  local tpm_dir plugin missing_plugins
  tpm_dir="$HOME/.tmux/plugins/tpm"

  if [[ ! -d "$tpm_dir/.git" ]]; then
    printf 'Installing TPM (Tmux Plugin Manager)...\n'
    mkdir -p "$HOME/.tmux/plugins"
    git clone https://github.com/tmux-plugins/tpm "$tpm_dir"
  fi

  missing_plugins=0
  for plugin in tmux-sensible tmux-yank tmux-open tmux-copycat tmux-which-key tmux-mode-indicator tmux.nvim; do
    [[ -d "$HOME/.tmux/plugins/$plugin" ]] || missing_plugins=1
  done

  if [[ "$missing_plugins" == 0 ]] && ! truthy "$upgrade_tools"; then
    printf 'tmux plugins already installed.\n'
    return
  fi

  if [[ -x "$tpm_dir/bin/install_plugins" ]]; then
    printf 'Installing tmux plugins...\n'
    "$tpm_dir/bin/install_plugins" || true
  fi
}

install_nvm_and_node() {
  local nvm_tag tmp installer node_major default_version
  mkdir -p "$local_bin"

  if has node && has npm && ! truthy "$upgrade_tools"; then
    node_major="$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || printf 0)"
    if [[ "$node_major" -ge 20 ]]; then
      printf 'Node.js already installed: %s\n' "$(node --version)"
      return
    fi
  fi

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

  default_version="$(nvm version default 2>/dev/null || printf N/A)"
  if [[ "$default_version" != "N/A" ]] && ! truthy "$upgrade_tools"; then
    nvm use default
    return
  fi

  nvm install --lts --latest-npm
  nvm alias default 'lts/*'
  nvm use default
}

install_npm_tools() {
  local entry package command_name

  # shellcheck disable=SC1091
  [[ ! -s "$nvm_dir/nvm.sh" ]] || . "$nvm_dir/nvm.sh"
  has nvm && nvm use default >/dev/null 2>&1 || true

  for entry in '@openai/codex:codex' '@anthropic-ai/claude-code:claude'; do
    package="${entry%%:*}"
    command_name="${entry##*:}"
    if has "$command_name" && ! truthy "$upgrade_tools"; then
      printf '%s already installed.\n' "$command_name"
      continue
    fi
    npm install -g "${package}@latest"
  done
}

truthy() {
  case "${1:-}" in
    1 | true | TRUE | yes | YES | y | Y | on | ON) return 0 ;;
    *) return 1 ;;
  esac
}

write_shell_env() {
  local env_file rc_file
  env_file="$HOME/.config/dotfiles/shell-env.sh"

  mkdir -p -- "$(dirname -- "$env_file")" "$local_bin"
  cat > "$env_file" <<EOF
# Generated by dotfiles. Safe to source from zsh, bash, and scripts.
case ":\$PATH:" in
  *":$tool_bin:"*) ;;
  *) export PATH="$tool_bin:\$PATH" ;;
esac
case ":\$PATH:" in
  *":$local_bin:"*) ;;
  *) export PATH="$local_bin:\$PATH" ;;
esac

export DOTFILES_TOOL_PREFIX="$tool_prefix"
export MAMBA_ROOT_PREFIX="$mamba_root"
export NVM_DIR="$nvm_dir"
[ -s "\$NVM_DIR/nvm.sh" ] && . "\$NVM_DIR/nvm.sh"
[ -s "\$NVM_DIR/bash_completion" ] && . "\$NVM_DIR/bash_completion"
EOF

  # shellcheck disable=SC1090
  . "$env_file"

  for rc_file in "$HOME/.zshrc" "$HOME/.zprofile"; do
    [[ -e "$rc_file" ]] || touch "$rc_file"
    if ! grep -Fq '$HOME/.config/dotfiles/shell-env.sh' "$rc_file" 2>/dev/null; then
      {
        printf '\n'
        printf '# Dotfiles tool environment\n'
        printf '[ ! -f "$HOME/.config/dotfiles/shell-env.sh" ] || . "$HOME/.config/dotfiles/shell-env.sh"\n'
      } >> "$rc_file"
    fi
  done
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

  if [[ "$os" == "ubuntu" && -x "$tool_bin/zsh" ]]; then
    printf '%s' "$tool_bin/zsh"
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

reload_interactive_shell() {
  local os shell_path
  os="$1"

  if [[ "$reload_shell" == "auto" ]]; then
    [[ -t 0 && -t 1 && -z "${CI:-}" ]] || return
  elif ! truthy "$reload_shell"; then
    return
  fi

  shell_path="$(resolve_zsh_path "$os")"
  printf '\nStarting a fresh zsh login shell with the updated tool environment...\n'
  printf 'Exit that shell to return to the previous session.\n'
  exec "$shell_path" -l
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
  micromamba --version 2>/dev/null | sed 's/^/micromamba /' || true
}

main() {
  local os
  parse_args "$@"
  os="$(detect_os)"

  export PATH="$tool_bin:$local_bin:$PATH"
  write_shell_env

  case "$os" in
    macos)
      install_macos_packages
      install_nvm_and_node
      ;;
    ubuntu)
      install_ubuntu_user_toolchain
      ;;
    *)
      printf 'Unsupported OS: %s. This script currently supports macOS and Ubuntu.\n' "$os" >&2
      exit 1
      ;;
  esac

  install_npm_tools
  install_tmux_plugins
  print_versions

  if truthy "$set_default_shell"; then
    set_zsh_as_default_shell "$os"
  fi

  printf '\nDone. Tool environment has been written to:\n'
  printf '  %s\n' "$HOME/.config/dotfiles/shell-env.sh"
  printf 'New zsh sessions will source it automatically. This installer also sourced it for its own follow-up steps.\n'
  printf '\nTo set zsh as your login shell during install, rerun with:\n'
  printf '  ./scripts/install-dev-tools.sh --set-default-shell\n'
  reload_interactive_shell "$os"
}

main "$@"
