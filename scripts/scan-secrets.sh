#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v rg >/dev/null 2>&1; then
  printf 'ripgrep is required for this scan.\n' >&2
  exit 1
fi

if rg --hidden -n \
  '(xai-[[:alnum:]_-]{20,}|tvly-[[:alnum:]_-]{20,}|fc-[0-9a-fA-F]{16,}|jina_[[:alnum:]_-]{20,}|sk-ant-[[:alnum:]_-]+|sk-proj-[[:alnum:]_-]+|sk-[[:alnum:]_-]{20,}|Bearer [[:alnum:]._-]{20,}|MISTRAL_API_KEY="[[:alnum:]_-]{12,}"|ANTHROPIC_API_KEY": "[^{}"][^"]{12,}")' \
  --glob '!.git/**' \
  --glob '!docs/skill-manifest.md' \
  .; then
  printf '\nPotential secrets found. Review the matches above before committing.\n' >&2
  exit 1
fi

printf 'No likely live tokens found.\n'
