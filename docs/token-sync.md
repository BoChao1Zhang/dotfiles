# Token Sync

Use an encrypted env file in this private dotfiles repository. The simplest mode is password-based: remember one strong password, commit only `secrets/secrets.env.age`, and decrypt it on each new machine.

The scripts use `age` passphrase encryption by default. There is no custom password-derived key format to maintain.

## Layout

- Commit: `secrets/secrets.env.age`
- Do not commit: `secrets/secrets.env`
- Decrypted env on each machine: `~/.config/dotfiles/secrets.env`

## First Machine

Create and encrypt your token file:

```sh
./scripts/secrets-edit.sh
```

The script opens `secrets.example.env` in `$EDITOR`. Fill in the real values. When the editor exits, `age` asks you to create a password and writes `secrets/secrets.env.age`.

Commit the encrypted file:

```sh
git add secrets/secrets.env.age
git commit -m "Add encrypted shared tokens"
git push
```

## New Machine

Install tools, pull the repo, and decrypt by entering your password:

```sh
./scripts/install-dev-tools.sh
git pull
./scripts/secrets-install.sh
```

Then apply dotfiles:

```sh
./scripts/bootstrap.sh
chezmoi --source "$PWD" apply
```

`bootstrap.sh` automatically sources `~/.config/dotfiles/secrets.env` before rendering templates. This lets Codex MCP tokens, Claude provider keys, and shell workflow API keys resolve from the same shared source.

## Updating Tokens

```sh
./scripts/secrets-edit.sh
git add secrets/secrets.env.age
git commit -m "Update encrypted tokens"
git push
```

On other machines:

```sh
git pull
./scripts/secrets-install.sh
./scripts/bootstrap.sh
chezmoi --source "$PWD" apply
```

## Why This Scheme

- Plaintext tokens never go into git.
- The encrypted file can be backed up and pushed with the rest of dotfiles.
- Codex, Claude Code, zsh, and scripts all read the same env names.
- Rotation is one edit, one commit, and one decrypt per machine.

## Optional Age Key Mode

If you later prefer machine keys instead of a remembered password, the old flow is still supported:

```sh
mkdir -p ~/.config/dotfiles
age-keygen -o ~/.config/dotfiles/age-key.txt
chmod 600 ~/.config/dotfiles/age-key.txt
sed -n 's/^# public key: //p' ~/.config/dotfiles/age-key.txt > secrets/age-recipient.txt

./scripts/secrets-edit.sh --identity
./scripts/secrets-install.sh --identity
```
