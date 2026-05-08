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
./scripts/bootstrap.sh
```

`bootstrap.sh` installs chezmoi with Homebrew if needed, initializes this directory as the chezmoi source, and shows a diff. After reviewing:

```sh
chezmoi apply
```

## Secrets

Real tokens are not committed. The templates expect these environment variables when you apply:

```sh
source ./secrets.example.env
chezmoi apply
```

Fill the variables from your password manager or current machine first. Keep the real file private and untracked.

## Refresh From This Machine

```sh
./scripts/refresh-from-home.sh
./scripts/scan-secrets.sh
git status
```

`scan-secrets.sh` exits with matches if it sees likely live tokens.

