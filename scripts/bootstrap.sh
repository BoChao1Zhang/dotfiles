#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v chezmoi >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install chezmoi
  else
    printf 'chezmoi is not installed. Install it first: https://www.chezmoi.io/install/\n' >&2
    exit 1
  fi
fi

chezmoi init --source "$repo_root"
chezmoi diff

printf '\nReview the diff above. Apply with:\n  chezmoi apply\n'

