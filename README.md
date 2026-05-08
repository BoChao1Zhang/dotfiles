# Dotfiles

Chezmoi source repository for Codex, Claude, tmux, Neovim, and zsh.

## What Is Managed

- `~/.zshrc` as a template, with API keys read from environment variables.
- `~/.zprofile`
- `~/.tmux.conf`
- `~/.config/tmux`, excluding downloaded plugins and backups.
- `~/.config/nvim`
- `~/.claude`, including agents, hooks, settings, providers, and skills. Runtime state, sessions, caches, history, backups, and project transcripts are excluded.
- `~/.codex`, including `AGENTS.md`, `config.toml` as a template, browser config, and user-installed skills. Auth, logs, sessions, history, caches, state databases, generated images, and memories are excluded.

## First Use

```sh
cd /path/to/dotfiles
./scripts/install-dev-tools.sh
./scripts/bootstrap.sh
```

`install-dev-tools.sh` supports macOS and Ubuntu. It installs Node.js through nvm, Codex CLI, Claude Code, Neovim, tmux, zsh, age, and supporting command-line tools. On Ubuntu it installs Neovim from the official release archive, builds tmux from the latest release tarball, and builds zsh from the upstream release archive. It does not automatically change your login shell.

To set zsh as the login shell explicitly:

```sh
./scripts/install-dev-tools.sh --set-default-shell
```

When running as `root` but targeting another user:

```sh
./scripts/install-dev-tools.sh --set-default-shell --target-user <username>
```

`bootstrap.sh` installs chezmoi with the official installer if needed, places it in `~/.local/bin` by default, records this directory as the chezmoi source, and shows a diff. Override the install directory with `CHEZMOI_BIN_DIR=/some/bin` when needed. After reviewing:

```sh
chezmoi apply
```

## Secrets

Real tokens are not committed. The recommended sync flow is an age-encrypted env file; see `docs/token-sync.md`.

```sh
./scripts/secrets-install.sh
./scripts/bootstrap.sh
chezmoi --source "$PWD" apply
```

`bootstrap.sh` sources `~/.config/dotfiles/secrets.env` when present, so Codex and Claude templates can render token-backed config.

## Refresh From This Machine

```sh
./scripts/refresh-from-home.sh
./scripts/scan-secrets.sh
git status
```

`scan-secrets.sh` exits with matches if it sees likely live tokens.
