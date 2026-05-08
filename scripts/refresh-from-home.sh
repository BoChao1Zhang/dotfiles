#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
src_home="${HOME:?HOME is not set}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

copy_file() {
  local src="$1"
  local dst="$2"
  [[ -f "$src" ]] || return 0
  mkdir -p -- "$(dirname -- "$dst")"
  cp -p -- "$src" "$dst"
}

copy_tree() {
  local src="$1"
  local dst="$2"
  shift 2
  [[ -d "$src" ]] || return 0
  mkdir -p -- "$dst"
  rsync -a --delete --delete-excluded "$@" "$src"/ "$dst"/
}

remove_tree_symlinks() {
  local dst="$1"
  [[ -d "$dst" ]] || return 0
  find "$dst" -type l -delete
}

sanitize_zshrc() {
  local src="$src_home/.zshrc"
  local dst="$repo_root/private_dot_zshrc.tmpl"
  [[ -f "$src" ]] || return 0
  perl -0pe '
    s/export MISTRAL_API_KEY="[^"]*"/export MISTRAL_API_KEY="{{ env "MISTRAL_API_KEY" }}"/g;
    s/export FIRECRAWL_API_KEY="[^"]*"/export FIRECRAWL_API_KEY="{{ env "FIRECRAWL_API_KEY" }}"/g;
    s/export JINA_API_KEY="[^"]*"/export JINA_API_KEY="{{ env "JINA_API_KEY" }}"/g;
  ' "$src" > "$dst"
}

sanitize_codex_config() {
  local src="$src_home/.codex/config.toml"
  local dst="$repo_root/dot_codex/private_config.toml.tmpl"
  [[ -f "$src" ]] || return 0
  mkdir -p -- "$(dirname -- "$dst")"
  perl -0pe '
    s#\Q$ENV{HOME}\E#{{ .chezmoi.homeDir }}#g;
    s/headers = \{ Authorization = "Bearer [^"{][^"]*" \}/headers = { Authorization = "Bearer {{ env "SIYUAN_SISYPHUS_TOKEN" }}" }/g;
    s/Authorization = "Bearer [^"{][^"]*"/Authorization = "Bearer {{ env "SIYUAN_SISYPHUS_TOKEN" }}"/g;
    s/GROK_API_KEY = "[^"]*"/GROK_API_KEY = "{{ env "GROK_API_KEY" }}"/g;
    s/TAVILY_API_KEY = "[^"]*"/TAVILY_API_KEY = "{{ env "TAVILY_API_KEY" }}"/g;
  ' "$src" > "$dst"
}

sanitize_claude_providers() {
  local src_dir="$src_home/.claude/providers"
  local dst_dir="$repo_root/dot_claude/providers"
  [[ -d "$src_dir" ]] || return 0
  mkdir -p -- "$dst_dir"

  find "$src_dir" -maxdepth 1 -type f -name '*.json' -print0 |
    while IFS= read -r -d '' src; do
      local base name env_name dst
      base="$(basename -- "$src")"
      name="${base%.json}"
      env_name="$(printf '%s' "$name" | tr '[:lower:]-' '[:upper:]_')"
      dst="$dst_dir/private_${base}.tmpl"
      perl -0pe "s/\"ANTHROPIC_API_KEY\"\\s*:\\s*\"[^\"]*\"/\"ANTHROPIC_API_KEY\": \"{{ env \\\"CLAUDE_PROVIDER_${env_name}_API_KEY\\\" }}\"/g" "$src" > "$dst"
    done
}

write_skill_manifest() {
  local dst="$repo_root/docs/skill-manifest.md"
  mkdir -p -- "$(dirname -- "$dst")"
  {
    printf '# Skill Manifest\n\n'
    printf 'Generated from this machine by `scripts/refresh-from-home.sh`.\n\n'
    printf '## Claude Skills\n\n'
    if [[ -d "$src_home/.claude/skills" ]]; then
      find "$src_home/.claude/skills" -maxdepth 1 -mindepth 1 -type d -print |
        sed "s#^$src_home/.claude/skills/##" | sort | sed 's/^/- /'
    fi
    printf '\n## Codex Skills\n\n'
    if [[ -d "$src_home/.codex/skills" ]]; then
      find "$src_home/.codex/skills" -maxdepth 1 -mindepth 1 -type d -print |
        sed "s#^$src_home/.codex/skills/##" | sort | sed 's/^/- /'
    fi
  } > "$dst"
}

encode_hidden_files() {
  find "$repo_root" \
    -path "$repo_root/.git" -prune -o \
    -mindepth 2 -type f -name '.*' -print0 |
    while IFS= read -r -d '' path; do
      local dir base target
      dir="$(dirname -- "$path")"
      base="$(basename -- "$path")"
      target="$dir/dot_${base#.}"
      [[ "$path" == "$target" ]] && continue
      mv -f -- "$path" "$target"
    done
}

need perl
need rsync
need sed
need find

copy_file "$src_home/.zprofile" "$repo_root/dot_zprofile"
copy_file "$src_home/.tmux.conf" "$repo_root/dot_tmux.conf"
sanitize_zshrc

copy_tree "$src_home/.config/nvim" "$repo_root/dot_config/nvim" \
  --exclude '.git/' \
  --exclude '.DS_Store'

copy_tree "$src_home/.config/tmux" "$repo_root/dot_config/tmux" \
  --exclude '.git/' \
  --exclude 'plugins/' \
  --exclude '*.bak' \
  --exclude 'cover.png' \
  --exclude '.DS_Store'

copy_file "$src_home/.claude/.gitignore" "$repo_root/dot_claude/dot_gitignore"
copy_file "$src_home/.claude/CLAUDE.md" "$repo_root/dot_claude/CLAUDE.md"
copy_file "$src_home/.claude/README.md" "$repo_root/dot_claude/README.md"
copy_file "$src_home/.claude/settings.json" "$repo_root/dot_claude/settings.json"
copy_file "$src_home/.claude/policy-limits.json" "$repo_root/dot_claude/policy-limits.json"
copy_file "$src_home/.claude/setup.sh" "$repo_root/dot_claude/executable_setup.sh"
copy_file "$src_home/.claude/statusline.sh" "$repo_root/dot_claude/executable_statusline.sh"
copy_file "$src_home/.claude/statusline-claude-hud.sh" "$repo_root/dot_claude/executable_statusline-claude-hud.sh"
copy_file "$src_home/.claude/integration.sh" "$repo_root/dot_claude/integration.sh"
copy_file "$src_home/.claude/integration.fish" "$repo_root/dot_claude/integration.fish"
copy_file "$src_home/.claude/emotion-pack.md" "$repo_root/dot_claude/emotion-pack.md"
copy_file "$src_home/.claude/opus46back.md" "$repo_root/dot_claude/opus46back.md"
copy_file "$src_home/.claude/tutorial.md" "$repo_root/dot_claude/tutorial.md"
copy_file "$src_home/.claude/video-desc.md" "$repo_root/dot_claude/video-desc.md"

copy_tree "$src_home/.claude/agents" "$repo_root/dot_claude/agents" \
  --exclude '.git/' \
  --exclude '.DS_Store'
copy_tree "$src_home/.claude/hooks" "$repo_root/dot_claude/hooks" \
  --exclude '.git/' \
  --exclude '__pycache__/' \
  --exclude '.DS_Store'
remove_tree_symlinks "$repo_root/dot_claude/skills"
copy_tree "$src_home/.claude/skills" "$repo_root/dot_claude/skills" \
  --copy-links \
  --exclude '.git/' \
  --exclude '__pycache__/' \
  --exclude '.venv/' \
  --exclude 'node_modules/' \
  --exclude 'dist/' \
  --exclude '*.tsbuildinfo' \
  --exclude '.DS_Store'
sanitize_claude_providers

copy_file "$src_home/.codex/AGENTS.md" "$repo_root/dot_codex/AGENTS.md"
copy_file "$src_home/.codex/browser/config.toml" "$repo_root/dot_codex/browser/config.toml"
sanitize_codex_config
remove_tree_symlinks "$repo_root/dot_codex/skills"
copy_tree "$src_home/.codex/skills" "$repo_root/dot_codex/skills" \
  --copy-links \
  --exclude '.system/' \
  --exclude '.git/' \
  --exclude '__pycache__/' \
  --exclude '.venv/' \
  --exclude 'node_modules/' \
  --exclude 'dist/' \
  --exclude '*.tsbuildinfo' \
  --exclude '*.zip' \
  --exclude '.DS_Store'

encode_hidden_files
write_skill_manifest

printf 'Refreshed chezmoi source at %s\n' "$repo_root"
