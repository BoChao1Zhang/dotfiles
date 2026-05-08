#!/usr/bin/env bash
# Push templates/Front.html, templates/Back.html, templates/Styling.css into
# Anki's "PaperNotes" note type via AnkiConnect — so what's on disk == what
# Anki actually renders. Anki stores templates inside collection.anki2, not on
# disk; without this sync, edits to templates/*.html have no effect.
#
# Usage: sync-template.sh [model-name]
#   model-name defaults to "PaperNotes".
set -euo pipefail

MODEL="${1:-PaperNotes}"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TPL_DIR="$SKILL_DIR/templates"
ANKI_CONNECT="${ANKI_CONNECT:-http://localhost:8765}"

for f in Front.html Back.html Styling.css; do
  [[ -f "$TPL_DIR/$f" ]] || { echo "missing $TPL_DIR/$f" >&2; exit 1; }
done
# Card 2 (reverse-gated) is optional — older models don't have it.
HAS_CARD2=0
[[ -f "$TPL_DIR/Card2-Front.html" && -f "$TPL_DIR/Card2-Back.html" ]] && HAS_CARD2=1

# Discover the existing card-template name (e.g. "Card 1" or localized "卡片 1")
# so we update the same key — AnkiConnect silently ignores writes to unknown
# template names and that bug eats hours.
EXISTING=$(curl -s "$ANKI_CONNECT" -H 'Content-Type: application/json' \
  -d "{\"action\":\"modelTemplates\",\"version\":6,\"params\":{\"modelName\":\"$MODEL\"}}")

# Build JSON via python — discover existing template names (1 or 2; localized
# names like "卡片 1"/"卡片 2" stay intact) and map our on-disk files to them by
# index. AnkiConnect silently ignores writes to unknown template names.
PAYLOAD=$(MODEL="$MODEL" TPL_DIR="$TPL_DIR" HAS_CARD2="$HAS_CARD2" python3 -c '
import json, os, sys
tpl = os.environ["TPL_DIR"]
existing = json.loads(sys.stdin.read()).get("result") or {}
m = os.environ["MODEL"]
if not existing:
  sys.stderr.write("model not found: " + m + "\n"); sys.exit(1)
names = list(existing.keys())  # preserves insertion order (Python 3.7+)
with open(os.path.join(tpl, "Front.html"), encoding="utf-8") as f: front1 = f.read()
with open(os.path.join(tpl, "Back.html"),  encoding="utf-8") as f: back1  = f.read()
with open(os.path.join(tpl, "Styling.css"), encoding="utf-8") as f: css   = f.read()
templates = {names[0]: {"Front": front1, "Back": back1}}
if os.environ["HAS_CARD2"] == "1" and len(names) >= 2:
  with open(os.path.join(tpl, "Card2-Front.html"), encoding="utf-8") as f: front2 = f.read()
  with open(os.path.join(tpl, "Card2-Back.html"),  encoding="utf-8") as f: back2  = f.read()
  templates[names[1]] = {"Front": front2, "Back": back2}
sys.stderr.write("→ syncing templates: " + ", ".join(repr(n) for n in templates.keys()) + "\n")
out = {
  "templates": {"action": "updateModelTemplates", "version": 6,
                "params": {"model": {"name": m, "templates": templates}}},
  "styling": {"action": "updateModelStyling", "version": 6,
              "params": {"model": {"name": m, "css": css}}},
}
sys.stdout.write(json.dumps(out))
' <<<"$EXISTING")

TMPL_REQ=$(printf '%s' "$PAYLOAD" | python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin)["templates"]))')
STYL_REQ=$(printf '%s' "$PAYLOAD" | python3 -c 'import json,sys;print(json.dumps(json.load(sys.stdin)["styling"]))')

call() {
  local body="$1"
  curl -s "$ANKI_CONNECT" -H 'Content-Type: application/json' -d "$body"
}

echo "→ updating templates of '$MODEL'…"
RESP=$(call "$TMPL_REQ"); echo "  $RESP"
echo "$RESP" | grep -q '"error": null' || { echo "templates update failed" >&2; exit 1; }

echo "→ updating styling of '$MODEL'…"
RESP=$(call "$STYL_REQ"); echo "  $RESP"
echo "$RESP" | grep -q '"error": null' || { echo "styling update failed" >&2; exit 1; }

echo "✓ synced. In Anki, press R on a card to re-render."
