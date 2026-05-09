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

`install-dev-tools.sh` supports macOS and Ubuntu. It installs Node.js through nvm, Codex CLI, Claude Code, Neovim, tmux, zsh, age, zoxide, starship, TPM plugins, and supporting command-line tools. On Ubuntu it installs Neovim from the official release archive, builds tmux from the latest release tarball, and builds zsh from the upstream release archive. It does not automatically change your login shell.

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

## GitHub Setup

For push access, use SSH instead of GitHub password authentication:

```sh
./scripts/setup-github-ssh.sh
```

Add the printed public key to GitHub at <https://github.com/settings/keys>, then test:

```sh
ssh -T git@github.com
```

## Secrets

Real tokens are not committed. The recommended sync flow is a password-encrypted age file; see `docs/token-sync.md`.

Create or update the encrypted token file by scanning local configs:

```sh
./scripts/secrets-capture.sh
git add secrets/secrets.env.age
git commit -m "Update encrypted tokens"
git push
```

Use `./scripts/secrets-edit.sh` when you want to edit the env file manually.

On a new machine, decrypt it by entering the same password:

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

`refresh-from-home.sh` also protects Claude/Codex skill scripts whose filenames start with `run_` or `once_` so chezmoi copies them as normal files instead of executing them during `apply`.

The zsh template is defensive: Zim, zoxide, starship, local env hooks, and tmux aliases are loaded only when available. This keeps a fresh Ubuntu/root shell quiet while `install-dev-tools.sh` is still installing dependencies.

After applying the zsh config, two helper commands are available:

```sh
dotup "Update dotfiles from this machine"
dotup --tokens "Update dotfiles and encrypted tokens"
dotdown
```

`dotup` refreshes from `$HOME`, scans for plaintext tokens, commits, and pushes. `dotup --tokens` also captures known local tokens and encrypts them before committing. `dotdown` pulls, decrypts token env if present, bootstraps chezmoi, and applies the dotfiles.
