---
name: learning-prereqs
description: Pre-flight a learning material such as a paper, blog post, book chapter, or code tutorial by extracting assumed prerequisites, running a multi-round adaptive diagnostic, publishing targeted briefs into SiYuan, then guiding formal close reading section by section with original media preserved, likely sticking points explained, important code snippets collected, and a 5-12 question mastery check. Triggers when the user wants to study a document but struggles with background, e.g. 帮我学这篇 PPO 论文, 看不懂这段 CUDA 的 SM/warp, 这个引理是什么意思, 补一下这篇文章的前置知识, 精读这篇文章, 带我逐段读, study X but I don't get the math, explain prereqs for this paper. Use aggressively when the user shares a paper/PDF/URL/code and signals a background wall or wants guided close reading. Output goes to SiYuan as diagnostic, brief, guided-reading, and mastery-check documents; flashcards run only on explicit request.
---

# Learning Prereqs To Guided Reading

The user has a learning material and a knowledge gap. The first job is **not** to summarize the material and **not** to dump every adjacent topic. Identify the **specific concepts the material assumes the reader already knows**, find which of those the user is shaky on through a real quiz, and write the minimum set of briefs that close those gaps. After those briefs exist, continue into the material itself: guide the reader through the original in order, preserving its media, adding local explanations at likely confusion points, and checking mastery after reading.

All durable outputs live in SiYuan under a single `Learning Prereqs` hub document, so the user can read, link, search, and revisit them in their notes. Memorization of key facts is a separate, **user-initiated** step that hands off to the `flashcards` skill. Every Anki card's `Source` field should point back to the originating SiYuan document, preferably as `siyuan://blocks/<doc-id>` plus the document title.

## Workflow

The flow is **ingest → map prereqs → quiz → diagnose → write briefs → publish to SiYuan → formal reading → mastery check → hand off**. Do not shortcut steps 3-4. Without the diagnostic, the briefs become generic background, which is exactly what the user is already drowning in.

### 1. Ingest The Material

| Source | Tool |
|---|---|
| Local PDF | `python3 scripts/ocr.py <pdf> <out_dir>` (Mistral OCR; preserves layout, math, tables, and extracts figures into `out_dir/images/`). Requires `MISTRAL_API_KEY`. |
| Web URL | Default: Jina MCP server (`mcp__jina-mcp-server__*`). On first use, load deferred schemas via `ToolSearch query:"select:mcp__jina-mcp-server__read_url,mcp__jina-mcp-server__search_web" max_results:5`, then call the read-url tool and save markdown to `<out_dir>/document.md`. Fallback if disconnected: `curl -sL "https://r.jina.ai/<url>" -o <out_dir>/document.md`. Escalate JS-heavy / anti-bot pages to `firecrawl scrape <url> -o <out_dir>/document.md` sparingly. |
| Pasted text / code | Use as-is in memory; write a local draft only if needed for iteration. |

After ingest, verify that `<out_dir>/document.md` and any `<out_dir>/images/` assets are available. If `MISTRAL_API_KEY` is missing for a PDF, stop and show the export instruction; there is no local fallback by design.

### 2. Map The Prerequisite Surface

Skim the material and produce an internal list of **assumed concepts**: things the author cites, uses, or builds on without rederiving. Aim for 5-15. For each, capture:

- name, e.g. `KL divergence`, `GAE (generalized advantage estimation)`, `SIMT execution model`
- one-line role in *this* material
- difficulty ceiling: whether a typical reader would be expected to know it cold, or whether the author hand-waves a deeper topic

Domain playbooks live in `references/domains/`. Load the relevant one (`ml.md`, `systems.md`, `math.md`, `physics.md`) before this step. If the domain is not covered, reason from the material.

### 3. Quiz The User

A single round only tells you whether the user is at the assumed level or below; it cannot tell you **how far below**. Run **up to 3 rounds**. Stop earlier when every cold concept has a clear floor, or when the user signals fatigue. Cap total questions at about 15.

Round 1:

- Pick the most load-bearing 5-7 concepts.
- Ask one mid-hard question per concept.
- Mix short answers, spot-the-wrong-claim prompts, small derivations, code-output predictions, and close-definition choices.
- Present all questions at once and wait. If the user wants to skip, push back once and invite `idk` answers.

Round 2:

- Score round 1 with the rubric in step 4.
- For each `cold` concept, build a tiny prereq tree and ask 1-2 questions one layer down.
- For `shaky` concepts, ask one question that targets the exact misunderstanding.
- For `solid` concepts, ask an edge-case probe only when the first answer may have been guessed.

Round 3:

- Ask 1-2 more questions only when a cold concept still has an ambiguous floor.
- After round 3, commit even with imperfect information.

Asking style:

- Tell the user upfront that the diagnostic is what makes the briefs targeted.
- Acknowledge correct reasoning between rounds.
- Treat `idk` as useful signal, not failure.

### 4. Diagnose

After all rounds, record a compact diagnosis per top-level concept:

```text
concept: msign
status:  cold
floor:   knows orthogonal matrices, does not know SVD
bridge:  SVD basics -> eigen-decomp of M^T M -> msign as Sigma -> I
```

Rubric:

| Bucket | Signal |
|---|---|
| solid | answer right, reasoning right, no hesitation in wording, and any edge probe holds |
| shaky | partial answer, right answer for the wrong reason, or close wrongness |
| cold | `idk`, flat-wrong, or guessed right with no reasoning |

Group cold concepts with similar floors. If three concepts all bottom out at "doesn't know SVD shape", write one foundation brief instead of three.

### 5. Write Briefs

Default: **one main brief**. If complex or multi-area, write **2-3 foundation briefs plus the main brief**. Each brief opens just above the user's floor and bridges up to where the original material picks up. Local drafts under `/tmp/learning-prereqs/<material-slug>/` are fine for iteration, but the user-facing output must be published to SiYuan.

Each brief uses this skeleton:

```markdown
# <concept name>

## What it is, in one paragraph

...

## Why <material> needs it

...specific to the user's material...

## The minimum mental model

...the smallest facts/relations that let the user follow the original...

## Worked example

...concrete numbers, code, or derivation...

## Common gotchas

...first-time failure modes...

## Further if you want it

...optional links / chapters...
```

Visual rules:

- Reuse figures the original PDF shipped when useful; they are in `<out_dir>/images/`.
- Structural / flow diagrams: use `mermaid` code blocks.
- Math plots: pipe Python to `~/.claude/skills/flashcards/scripts/render-viz.sh <out>/figs/<name>.png`. Reuse the `flashcards` skill's `.venv`; do not duplicate it here.
- Pictorial / abstract images: call `codex` MCP (`gpt-image-1`, prompt suffix: `flat ink illustration, monochrome, paper texture, hand-drawn lines, no text labels`). When `gpt-image-2` lands, swap the model id only.
- Math: use KaTeX-style inline / display math.

Keep each brief as short as possible. If a brief passes about 800 words, cut unless the user's floor genuinely requires the extra bridge.

### 5b. SiYuan Publishing

Every artifact this skill produces lives in **SiYuan**, not another note app and not the local filesystem. Read `references/siyuan-publishing.md` before the first publish in a session.

Use `siyuan-sisyphus` / `siyuan` CLI when available. If the `$siyuan-sisyphus-cli` skill is installed, follow its safety and command-discovery rules. If the CLI is missing, tell the user to install/configure it or connect the SiYuan Sisyphus MCP plugin; hold drafts under `/tmp/learning-prereqs/<slug>/` until publishing can resume.

Tree shape inside the selected writable notebook:

```text
Learning Prereqs
└── <material slug> (<short title>)
    ├── 00 - Material overview
    ├── 01 - Diagnostic
    ├── 02 - Brief - <main concept>
    ├── 03 - Brief - <foundation>
    ├── 04 - Brief - <foundation>
    ├── 05 - Guided Reading
    └── 06 - Mastery Check
```

For long materials, split guided reading into numbered child documents instead of one giant page:

```text
    ├── 05 - Reading - Section 1
    ├── 06 - Reading - Section 2
    └── 07 - Mastery Check
```

Notebook choice:

- If the user named a notebook, use it.
- Otherwise run `siyuan-sisyphus notebook list --json` and choose the single open notebook with write permission if there is exactly one obvious choice.
- If multiple writable notebooks are plausible, ask the user which notebook should hold `Learning Prereqs`; do not publish to an arbitrary notebook.

Publishing rules:

- Create or reuse `/Learning Prereqs`.
- Create one material document per study session.
- Create child documents for diagnostic, briefs, guided reading, and mastery check.
- Store the original URL/PDF citation and a 3-line summary in the material page.
- Store all quiz rounds and the per-concept diagnosis table in `01 - Diagnostic`.
- After each create, capture the returned document/block id, then verify with `document lookup` or `document list-tree`.
- Use `siyuan://blocks/<doc-id>` as the shareable Source link for flashcards and final handoff; include the human-readable path as fallback.

Content format:

- Pass markdown to `document create`; for large drafts, keep the markdown in `/tmp/learning-prereqs/<slug>/` and pass its contents through a subprocess argument rather than hand-escaping shell strings.
- Mermaid code blocks and KaTeX-style math should remain in markdown.
- For local images, prefer `file upload-asset` only after explicit user confirmation because it reads local files. If image upload is not confirmed or unavailable, leave `[fig: /absolute/path/to/file.png]` placeholders in the SiYuan brief.

### 6. Formal Reading

After the briefs are published, transition into formal reading. If the user wants time to read the briefs first, pause cleanly and resume when they say they are ready. If they asked to be guided through the material end-to-end, start immediately after the brief handoff.

Read the original in order, chunked by the material's natural structure:

- For papers/books: title/abstract/context, then section by section; split dense sections into paragraph groups.
- For blog posts/tutorials: heading by heading; split long headings into coherent paragraph groups.
- For code tutorials/repos: explain the prose and the code path together; connect snippets to the surrounding explanation.

For each reading chunk, create a SiYuan guided-reading entry with:

~~~markdown
## <section or paragraph range>

**Original anchor:** <short title, equation number, figure number, or a short quoted phrase>

**What this part is doing**
...

**Likely sticking points**
- ...

**Connection to the briefs**
- ...

**Code worth watching**

```<language>
...
```

Why it matters: ...

**Media**
- ...
~~~

Close-reading rules:

- Preserve the original order. Do not reshuffle the author's argument into a generic summary.
- Use short anchors instead of long verbatim reproduction. For copyrighted or web sources, quote only the minimum phrase needed to identify the location, then explain in your own words.
- Add explanations at points where a reader is likely to wonder "why?", "how did they get that?", "what assumption changed?", or "what does this symbol/API do here?".
- Do not re-explain every sentence. Spend attention where the material compresses reasoning, switches notation, depends on a figure, uses an unexplained theorem/API, or makes a non-obvious implementation choice.
- Keep a running `Code worth watching` list when code appears. Include only snippets that teach control flow, data shape, API usage, numerical subtlety, performance behavior, or a likely source of bugs.

Media preservation rules:

- Preserve useful original images, tables, diagrams, audio, and video at the nearest relevant reading chunk.
- For remote media, keep the source URL or markdown embed from `document.md` when available.
- For PDF figures extracted to `<out_dir>/images/`, reuse the figure paths next to the related explanation. If publishing to SiYuan requires upload, follow the local-image confirmation rule in step 5b.
- For audio/video, keep the original URL or embed link and add a one-line note about what the reader should attend to. Do not transcribe long media unless the user asks.
- If ingestion lost media that the source clearly depends on, try a better ingest path once. If still unavailable, mark `[media unavailable: <source location>]` rather than pretending it was not needed.

### 7. Mastery Check

After the reader has finished the guided reading, ask **5-12 questions** to check understanding. Ask them all at once and wait for answers. Tune the count to the material's size and difficulty; default to 8.

Question mix:

- 2-4 conceptual questions over the central argument.
- 1-3 figure/table/equation interpretation questions when the material contains them.
- 1-3 code, implementation, or data-shape questions when code is present.
- 1-2 transfer questions that ask the reader to apply the idea to a nearby case.
- 1 calibration question that targets a likely misconception from the guided reading.

Scoring rules:

- Mark each answer `solid`, `shaky`, or `cold`.
- For `shaky` and `cold`, give a targeted correction and point back to the exact guided-reading section or brief.
- Publish the questions, the user's answers, the score table, and the next-step recommendations in the `Mastery Check` SiYuan document.
- Do not create flashcards unless the user explicitly asks.

### 8. Hand Off

Tell the user the SiYuan targets, one line each:

```text
✓ Material hub:        /Learning Prereqs/<slug>  (siyuan://blocks/<id>)
  └─ Diagnostic:       /Learning Prereqs/<slug>/01 - Diagnostic  (siyuan://blocks/<id>)
  └─ Brief 1: <title>  /Learning Prereqs/<slug>/02 - Brief - ...  (siyuan://blocks/<id>)
  └─ Brief 2: <title>  /Learning Prereqs/<slug>/03 - Brief - ...  (siyuan://blocks/<id>)
  └─ Guided reading:   /Learning Prereqs/<slug>/05 - Guided Reading  (siyuan://blocks/<id>)
  └─ Mastery check:    /Learning Prereqs/<slug>/06 - Mastery Check  (siyuan://blocks/<id>)
```

Add a one-line summary per brief and guided-reading document. If formal reading has not started yet, say: "The briefs are ready; when you are ready, we will read the original section by section." If formal reading and mastery check are complete, summarize the user's strongest and weakest areas. Then say: "When you want flashcards over the key facts, say so."

Do **not** automatically invoke `flashcards`.

### 9. Flashcards Handoff

When the user says "make flashcards", "扔进 anki", "memorize these", or similar, invoke the `flashcards` skill. Pass each SiYuan brief as input with `fields.Source` set to that brief's SiYuan link, e.g. `siyuan://blocks/<brief-doc-id> - <brief title>`.

The mapping is one SiYuan source document to many Anki notes. Every note derived from a given brief, guided-reading page, or mastery correction gets the same Source so review can click back to the original context. The user still confirms cards before push.

## Output Style

Write briefs in the user's preferred language: Chinese if the conversation is Chinese, English if English, mixed if the source is mixed. Keep math symbols and code identifiers in their original form.

Use second person sparingly. Aim for the voice of a colleague who has done the same struggle and is now back-explaining the smallest delta you needed.

## Degradation

- **`MISTRAL_API_KEY` missing**: stop, point user at `https://console.mistral.ai/`, and show the `export` line.
- **PDF too large for Mistral OCR (>50 MB)**: ask the user to pre-split with `pdftk` or `qpdf`; OCR chunks and concatenate the resulting `document.md` files.
- **Material is self-contained**: step 2 still maps prereqs, but if step 4 has no cold concepts, skip step 5 and tell the user honestly that the material already defines its prerequisites.
- **User refuses the quiz**: push back once. If they still refuse, write with all step-2 concepts treated as `shaky`, and put an `untargeted - quiz skipped` callout at the top of each SiYuan brief.
- **User only wants prereq briefs**: stop after publishing briefs and hand off with a clear note that formal reading can resume later from the material hub.
- **User refuses the final mastery check**: push back once. If they still refuse, publish the guided reading and add `mastery check skipped by user` to the material overview.
- **Original media cannot be preserved**: record which images/audio/video were missing and where they belonged. Do not silently omit load-bearing media.
- **SiYuan CLI/MCP unavailable**: stop before final handoff, explain that SiYuan publishing is blocked, and keep drafts in `/tmp/learning-prereqs/<slug>/` for retry. Do not silently fall back to any other app or local files as the final output.

## Files In This Skill

| Path | Role |
|---|---|
| `SKILL.md` | This file. |
| `scripts/ocr.py` | Mistral OCR three-step pipeline: upload, signed URL, OCR. Saves `document.md` and `images/`. |
| `references/ocr.md` | Mistral API reference, JSON shape, edge cases. |
| `references/quizzing.md` | Multi-round adaptive diagnostic protocol. |
| `references/siyuan-publishing.md` | SiYuan hub structure, CLI checks, publish commands, verification, and Source-link convention. |
| `references/domains/ml.md` | ML / RL prereqs commonly assumed by papers. |
| `references/domains/systems.md` | GPU / CUDA / parallel-systems prereqs. |
| `references/domains/math.md` | Common lemmas / inequalities / proof techniques. |
| `references/domains/physics.md` | Mechanics / thermo / E&M / QM prereqs. |
| `evals/` | Test prompts for skill-creator iteration. |

## Companion Skill

`flashcards` runs only after explicit user request. When called from this skill, pass each SiYuan brief link as the Anki `Source` field. The two skills share the same scientific-Python `.venv` under `~/.claude/skills/flashcards/.venv` for figure rendering and share no other state.
