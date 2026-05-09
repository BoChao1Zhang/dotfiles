#!/usr/bin/env bash
# Copy the built React bundle into Anki's media folder.
# Files starting with "_" are treated as media assets and never garbage-collected
# by Anki's "Check Media" sweep, even though no note references them by name.
#
# Usage: install-media.sh [profile]
#   profile defaults to "User 1" (Anki's default profile name on macOS).
set -euo pipefail

PROFILE="${1:-User 1}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$SKILL_DIR/dist"
MEDIA_DIR="$HOME/Library/Application Support/Anki2/$PROFILE/collection.media"

if [[ ! -d "$DIST_DIR" ]]; then
  echo "error: $DIST_DIR not found — run 'pnpm --dir $SKILL_DIR/app build' first" >&2
  exit 1
fi

if [[ ! -d "$MEDIA_DIR" ]]; then
  echo "error: $MEDIA_DIR not found — open Anki at least once with profile '$PROFILE'" >&2
  exit 1
fi

count=0
for f in "$DIST_DIR"/_*; do
  [[ -e "$f" ]] || continue
  cp "$f" "$MEDIA_DIR/"
  count=$((count + 1))
done

echo "copied $count files into $MEDIA_DIR"
