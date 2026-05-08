# Flashcards skill — one-time setup

Run these once. The skill assumes all six are done.

## 1. Install AnkiConnect

In Anki: **Tools → Add-ons → Get Add-ons…** → paste `2055492159` → OK → restart Anki.

Smoke test:

```bash
curl -s -X POST http://127.0.0.1:8765 \
  -d '{"action":"version","version":6}'
# → {"result":6,"error":null}
```

## 2. Disable App Nap on Anki (macOS only)

Without this, macOS suspends Anki after a few minutes and AnkiConnect stops responding.

**System Settings → Battery → Application Energy Use → Anki → Toggle off "App Nap"**

(Or via CLI: `defaults write net.ichi2.anki NSAppSleepDisabled -bool true` then restart Anki.)

## 3. Create the `PaperNotes` note type

In Anki: **Tools → Manage Note Types → Add → Add: Basic → name it `PaperNotes` → OK**.

Select `PaperNotes` then:

**Fields…** — make the field list exactly:

| # | Field |
|---|---|
| 1 | Front |
| 2 | Back |
| 3 | Source |

(Delete any other fields. Order matters — Anki uses field 1 for the sort key.)

**Cards…** — paste these three windows verbatim (file paths are inside this skill folder, `~/.claude/skills/flashcards/templates/`):

| Window | Source file |
|---|---|
| Front Template | `templates/Front.html` |
| Back Template | `templates/Back.html` |
| Styling | `templates/Styling.css` |

## 4. Build and install the React bundle

```bash
cd ~/.claude/skills/flashcards/app
pnpm install
pnpm build
bash ../scripts/install-media.sh
```

That copies `dist/_flashcards.js`, `_flashcards.css`, the `_flashcards-*.js` chunks, and KaTeX font files into `~/Library/Application Support/Anki2/User 1/collection.media/`. Filenames start with `_`, so Anki's "Check Media" sweep leaves them alone.

If you use a non-default profile: `bash ../scripts/install-media.sh "Your Profile Name"`.

## 5. Wire up the anki MCP server

The npm package is `@ankimcp/anki-mcp-server`. Edit `~/.claude.json` and add this entry under `mcpServers` (top level, sibling of `projects`):

```json
"mcpServers": {
  "ankimcp": {
    "command": "npx",
    "args": ["-y", "@ankimcp/anki-mcp-server"]
  }
}
```

Restart Claude Code. Verify: ask "list my Anki decks" — Claude should call `mcp__ankimcp__deckNames` and return an array.

## 6. Enable the codex plugin (optional — only needed for AI illustrations)

The codex plugin lets the skill call `gpt-image-1` for pictorial cards.

1. Edit `~/.claude/settings.json`. Find `enabledPlugins["codex@openai-codex"]` and set it to `true`.
2. Export `OPENAI_API_KEY` in your shell's startup file (or in the codex plugin config — see `~/.claude/plugins/cache/openai-codex/*/README.md` for the exact mechanism on your installed version).
3. Restart Claude Code.

Skip this if you only want text/code/mermaid cards — mermaid renders client-side from text, no API key required.

## End-to-end smoke test

In Claude Code, paste:

> /flashcards 试一下：快速排序的最坏时间复杂度是 O(n²)，因为当 pivot 总落在数组最值时，每轮只缩减 1 个元素。常见 mitigation：随机选 pivot 或三数取中。

Expected outcome:

- Two or three cards land in deck `Inbox::flashcards` (or whichever you confirm).
- Open Anki, switch to that deck, hit **Browse** → cards show paper background, serif body, code in the answer is highlighted, the mermaid block (if produced) renders as SVG.
- **Tools → Sync** pushes them to AnkiWeb.

If the front shows raw `**bold**` instead of styled text, the React bundle isn't loading — re-run step 4 and confirm `_flashcards.js` exists in the media folder.
