#!/usr/bin/env bash
# Run user Python code (read from stdin) inside the skill's scientific-Python
# venv, producing a PNG at $1. Bootstraps the venv on first invocation.
#
# Usage:
#   echo "<python>" | render-viz.sh /abs/path/out.png
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV="$SKILL_DIR/.venv"
MARKER="$VENV/.flashcards-deps-ok"

if [[ ! -f "$MARKER" ]]; then
  echo "→ first-time env setup; this may take a couple of minutes" >&2
  bash "$SCRIPT_DIR/setup-env.sh" >&2
fi

if [[ $# -ne 1 ]]; then
  echo "usage: $(basename "$0") <out.png>  (python source on stdin)" >&2
  exit 2
fi

exec "$VENV/bin/python" "$SCRIPT_DIR/render-viz.py" "$1"
