---
name: flashcards
description: Extract atomic flashcards from documents/conversations and write them into local Anki via AnkiConnect, using a React-rendered paper-note card template with markdown, collapsible code, KaTeX, and mermaid. Triggers on "flashcards", "flash", "抽认卡", "anki".
---

# Flashcards → Anki

Turn arbitrary source material (PDF, conversation, pasted text) into atomic flashcards in a local Anki deck. Cards render through a React bundle that lives in Anki's media folder, so any markdown body — including fenced code, math, mermaid diagrams, and images — renders consistently with a paper-note aesthetic.

## Authoring rules — read first

Before drafting any cards, load `references/authoring.md`. It encodes the
minimum-information principle, active-recall framing, the note-type decision
tree, per-domain playbooks (math / programming / language / history / procedure
/ paper-reading), and an explicit list of negative patterns to refuse. Every
card you draft must survive those gates **before** the user-confirmation step
in Workflow §4 — don't ship the smell and rely on the user to catch it.

## Note types

| Type | Status | Fields | Use when |
|---|---|---|---|
| `PaperNotes` | live | `Front`, `Back`, `Source`, optional `Reverse?` | Atomic Q&A; set `Reverse?` to any non-empty value when both directions are worth recalling. |
| `PaperCloze` | live (`isCloze: true`) | `Text` (with `{{c1::…}}`), `Extra`, `Source` | Fill-in-the-blank for formulas, syntax tokens, dates. Each `cN` index spawns one card sharing the same context. |
| `PaperCode` | live | `Task`, `Solution`, `Hint`, `Lang`, `Source` | Programming exercises — Front shows the task, Back inlines task + optional hint + a fenced `Lang` code block (auto-collapses past 12 lines). |

All three share the same React bundle and CSS — only the Anki templates differ.
Tags always include `flashcards` plus a source slug. **Do not** add ad-hoc
Code/Image fields — markdown in `Back` carries everything renderable.

## Markdown features (rendered by the React bundle)

| Syntax | Renders as |
|---|---|
| `**bold**`, `*italic*`, `~~strike~~`, lists, tables, blockquote | GFM, paper-style typography |
| ` ```python\n…\n``` ` | Highlighted, paper-toned code block. **>12 lines auto-collapses with a 展开/收起 toggle.** |
| `` `inline code` `` | Inline mono with subtle paper-tone box |
| `$E=mc^2$` / `$$…$$` | KaTeX inline / display math |
| ` ```mermaid\nflowchart…\n``` ` | Lazy-loaded mermaid SVG (neutral theme) |
| `![alt](flashcards_<sha1>.png)` | Image from Anki media folder |
| `[link](https://…)` | Opens externally |

## Workflow

The flow is **draft → user confirms → push**. Never call `addNotes` before the user has approved the draft, even when the request sounds urgent — pushing unwanted cards into Anki creates manual cleanup work.

1. **Parse input.** File path → `Read`/`pdftotext`; "current conversation" → quote relevant turns; pasted text → use as-is.
2. **Scope check** with the user (one short turn, ask only for what you can't infer):
   - Target deck (default `Inbox::flashcards`; verify with `mcp__ankimcp__listDecks`, create with `mcp__ankimcp__createDeck` if missing).
   - Card count (default 5–10).
   - Granularity: "atomic facts" (one idea per card) vs. "concepts" (a theorem + its statement together).
3. **Draft cards** (no Anki writes yet). Apply the rules in `references/authoring.md` — minimum-information, active recall, the note-type decision tree, the per-domain playbook. For each card decide its **note type** (`PaperNotes` / `PaperCloze` / `PaperCode`) and produce the type's fields as markdown strings. Decide image needs while drafting:
   - Structural / flow → `mermaid` block embedded inline (no media file).
   - Math / scientific plot → pipe Python source to `scripts/render-viz.sh /abs/path/flashcards_<sha1>.png`. The first invocation triggers `setup-env.sh` and provisions the `.venv` (matplotlib, seaborn, plotly + kaleido, sympy, numpy, scipy, pandas, networkx, graphviz, statsmodels, Pillow); subsequent runs are <1s. The user code receives `OUT_PATH` and writes the PNG itself.
   - Abstract / pictorial → call codex MCP to generate a PNG via OpenAI Images (`gpt-image-1`, prompt suffix: `flat ink illustration, monochrome, paper texture, hand-drawn lines, no text labels`). Same filename convention.
   Embed via `![](flashcards_<sha1>.png)`. Hold PNG bytes in memory; do not upload to Anki yet.
4. **Show the draft and gate.** Render as a numbered table — `# | Type | Front-or-Text | Back-summary | Source`. Then ask explicitly: *approve all? drop indices? edit any field? change deck or tags?* Do not proceed past this step until the user replies with approval or edits — "looks good" suffices, silence does not.
5. **Apply edits** if requested, and re-show the affected cards. Loop until approved.
6. **Push to Anki** (only after approval):
   - Upload media: for each held PNG, `mcp__ankimcp__storeMediaFile` with base64 + deterministic filename.
   - Add notes: group by note type, one `mcp__ankimcp__addNotes` call per type (`PaperNotes` fields `{Front, Back, Source, Reverse?}`; `PaperCloze` fields `{Text, Extra, Source}`; `PaperCode` fields `{Task, Solution, Hint, Lang, Source}`). Tags `["flashcards", "<source-slug>"]` on every note.
   - Sync: `mcp__ankimcp__sync`.
7. **Report** deck name, count added (broken down by type), and first three fronts so the user can verify quickly in Anki.

## Degradation

- **AnkiConnect unreachable** (`curl localhost:8765` fails): point the user at `SETUP.md` step 1; offer to dump cards to `~/Downloads/flashcards-<timestamp>.apkg` via `genanki` (`uv run --with genanki - <<'PY' …`).
- **Bundle not installed in media folder** (cards render plain text): run `bash ~/.claude/skills/flashcards/scripts/install-media.sh`; tell the user to "Tools → Check Media → no action needed" — the leading `_` keeps the files.
- **codex MCP disabled or no `OPENAI_API_KEY`**: skip step 3's image branch entirely; mermaid still works because that's local. Mention to the user that pictorial illustrations were skipped.
- **gpt-image-1 unavailable in user region**: retry once with `dall-e-3`; if that also fails, drop to mermaid-only.

## Building / updating the bundle

```bash
cd ~/.claude/skills/flashcards/app && pnpm install && pnpm build
bash ~/.claude/skills/flashcards/scripts/install-media.sh   # copies dist/_*.{js,css} → Anki media
bash ~/.claude/skills/flashcards/scripts/sync-template.sh   # pushes templates/*.html + Styling.css into Anki via AnkiConnect
```

`install-media.sh` takes an optional profile name (default `User 1`); if Anki uses a localized default like `账户 1`, pass it explicitly. Anki stores card templates inside `collection.anki2`, not on disk — without `sync-template.sh`, edits to `templates/*.html` don't take effect. The bundle lives at `~/.claude/skills/flashcards/dist/`; files are committed, rebuild only when React source changes.

## Files in this skill

| Path | Role |
|---|---|
| `SETUP.md` | One-time configuration walkthrough (AnkiConnect plugin, App Nap, PaperNotes import, MCP wiring). **Read first if user has not configured the skill yet.** |
| `references/authoring.md` | Card-authoring playbook: minimum-information principle, active recall, note-type decision tree, per-domain rules (math / programming / language / history / procedure / paper-reading), negative patterns. **Load before drafting cards.** |
| `app/` | React + Vite source (`pnpm build`). |
| `dist/_flashcards.js`, `_flashcards.css`, `_flashcards-*.js` | Built bundle. Goes into Anki media folder. |
| `templates/Front.html`, `Back.html`, `Styling.css` | `PaperNotes` Card 1 templates + shared placeholder/body CSS. |
| `templates/Card2-Front.html`, `Card2-Back.html` | `PaperNotes` Card 2 (reverse-gated by `{{#Reverse?}}…{{/Reverse?}}`). |
| `templates/Cloze-Front.html`, `Cloze-Back.html` | `PaperCloze` template. Uses `{{cloze:Text}}` so Anki injects `<span class="cloze">…</span>` HTML before the React layer sees the field. |
| `templates/Code-Front.html`, `Code-Back.html` | `PaperCode` template. Back assembles markdown of `Task` + optional `**Hint**` line + ` ```{{Lang}}\n{{Solution}}\n``` ` so the React `CollapsibleCode` component takes over. |
| `examples/cards.md` | Markdown reference: every supported feature on a single page. |
| `scripts/install-media.sh` | Copy bundle into `~/Library/Application Support/Anki2/<profile>/collection.media/`. Pass profile name if not `User 1`. |
| `scripts/sync-template.sh` | Push `templates/*.html` + `Styling.css` into the `PaperNotes` model via AnkiConnect. Auto-detects card-template names (`Card 1` / `卡片 1`); pushes Card 2 if `Card2-*.html` exist locally. |
| `scripts/setup-env.sh` | One-time bootstrap: creates `.venv` (Python 3.12 via uv) and installs the scientific stack (matplotlib, seaborn, plotly + kaleido, sympy, numpy, scipy, pandas, networkx, graphviz, statsmodels, Pillow). Idempotent — marker file at `.venv/.flashcards-deps-ok`. |
| `scripts/render-viz.sh`, `scripts/render-viz.py` | Run user Python (stdin) inside the venv, producing a PNG at `$1`. Auto-runs `setup-env.sh` if `.venv` is missing. User code uses the global `OUT_PATH` and saves the figure with whichever lib it likes. |
| `.venv/` | uv-managed scientific Python venv. Created on first call to `render-viz.sh`. Not committed; `setup-env.sh` regenerates from scratch. |

## When this skill triggers

User says "flashcards", "flash", "抽认卡", "anki", or asks to "make cards from this", "memorize this", "扔进 Anki". Don't trigger on generic mentions of memory or learning that aren't asking for cards.
