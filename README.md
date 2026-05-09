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

`install-dev-tools.sh` supports macOS and Ubuntu. On macOS it uses Homebrew plus nvm. On Ubuntu it does not use apt by default: it installs micromamba in `~/.local/bin`, creates a user-local conda-forge toolchain at `~/.local/share/dotfiles/toolchain` for Node.js, tmux, zsh, age, zoxide, starship, and supporting command-line tools, and installs the official Neovim release into `~/.local/share/dotfiles/neovim` when needed. It is idempotent by default: existing tools are skipped and npm CLIs are installed only when their commands are missing. Use `--upgrade` when you explicitly want to refresh already-installed tools. It does not automatically change your login shell.

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

Both `install-dev-tools.sh` and `bootstrap.sh` write `~/.config/dotfiles/shell-env.sh` and connect it to zsh, bash, and profile startup files so the user-local toolchain and `~/.local/bin` tools are available as plain commands. In an interactive terminal, `install-dev-tools.sh` starts a fresh zsh login shell at the end; pass `--no-reload-shell` to disable that behavior.

If a command such as `nvim` is missing on Ubuntu, repair the user-local toolchain with:

```sh
./scripts/install-dev-tools.sh --no-reload-shell
. ~/.config/dotfiles/shell-env.sh
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

If `tmux new` prints `server version is too old for client`, an older tmux server is still running on the default socket. Start a temporary new socket with `tmux -L dotfiles new -s test`, or close/save old sessions and stop the old server with the old client, usually `/usr/bin/tmux kill-server`; after that plain `tmux` will start the user-local version.

After applying the zsh config, two helper commands are available:

```sh
dotup "Update dotfiles from this machine"
dotup --tokens "Update dotfiles and encrypted tokens"
dotdown
```

`dotup` refreshes from `$HOME`, scans for plaintext tokens, commits, and pushes. `dotup --tokens` also captures known local tokens and encrypts them before committing. `dotdown` pulls, decrypts token env if present, bootstraps chezmoi, and applies the dotfiles.
