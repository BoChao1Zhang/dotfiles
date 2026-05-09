#!/usr/bin/env bash
# One-time scientific-Python env setup for the flashcards skill.
#
# Creates a uv-managed venv at $SKILL/.venv and installs the libraries the
# render-viz pipeline can use (matplotlib, seaborn, plotly + kaleido, sympy,
# numpy, scipy, pandas, networkx, graphviz-py, Pillow, statsmodels).
#
# Idempotent: if .venv already exists with all deps, exits in <1s.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$SKILL_DIR/.venv"
MARKER="$VENV/.flashcards-deps-ok"

DEPS=(
  matplotlib seaborn
  "plotly>=5.20" kaleido
  sympy numpy scipy pandas
  networkx graphviz
  pillow statsmodels
)

if [[ -f "$MARKER" ]]; then
  echo "✓ env already provisioned at $VENV"
  exit 0
fi

if ! command -v uv >/dev/null 2>&1; then
  echo "error: 'uv' not found. Install via: curl -LsSf https://astral.sh/uv/install.sh | sh" >&2
  exit 1
fi

if [[ ! -d "$VENV" ]]; then
  echo "→ creating venv at $VENV (Python 3.12)"
  uv venv --python 3.12 "$VENV"
fi

echo "→ installing scientific stack: ${DEPS[*]}"
uv pip install --python "$VENV/bin/python" "${DEPS[@]}"

date > "$MARKER"
echo "✓ env ready at $VENV"
echo "  test: $VENV/bin/python -c 'import matplotlib, plotly, sympy; print(\"ok\")'"
