# Token Sync

Use an encrypted env file in this private dotfiles repository. The repo can sync everywhere, while plaintext tokens only exist on machines that have your age private key.

## Layout

- Commit: `secrets/secrets.env.age`
- Do not commit: `secrets/secrets.env`
- Private key on each machine: `~/.config/dotfiles/age-key.txt`
- Decrypted env on each machine: `~/.config/dotfiles/secrets.env`

## First Machine

Create one age identity and save the private key in a password manager:

```sh
mkdir -p ~/.config/dotfiles
age-keygen -o ~/.config/dotfiles/age-key.txt
chmod 600 ~/.config/dotfiles/age-key.txt
sed -n 's/^# public key: //p' ~/.config/dotfiles/age-key.txt > secrets/age-recipient.txt
```

Edit and encrypt your tokens:

```sh
./scripts/secrets-edit.sh
git add secrets/age-recipient.txt secrets/secrets.env.age
git commit -m "Add encrypted shared tokens"
git push
```

## New Machine

Restore the private age key from your password manager:

```sh
mkdir -p ~/.config/dotfiles
$EDITOR ~/.config/dotfiles/age-key.txt
chmod 600 ~/.config/dotfiles/age-key.txt
```

Then decrypt and apply:

```sh
./scripts/secrets-install.sh
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

