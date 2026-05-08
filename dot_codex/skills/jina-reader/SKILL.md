---
name: jina-reader
description: Fetch, crawl, and search web content through Jina AI Reader. Use when Codex needs to convert URLs, PDFs, JavaScript-rendered pages, or search results into LLM-friendly Markdown/text/JSON with r.jina.ai or s.jina.ai; when the user says scrape, crawl, fetch this page, read this webpage, use Jina Reader, jina.ai crawler, or wants higher-rate authenticated Jina requests.
---

# Jina Reader

Use Jina AI Reader for fast URL-to-Markdown extraction and search-grounded page retrieval. Prefer this skill when a user asks for web page content, a URL scrape, or Jina-specific crawling.

## Quick Start

Use the bundled script first:

```bash
python3 scripts/jina_reader.py read "https://example.com" -o /tmp/page.md
python3 scripts/jina_reader.py search "cuda programming guide" --site docs.nvidia.com --json -o /tmp/search.json
python3 scripts/jina_reader.py batch urls.txt --out-dir /tmp/jina-pages
```

The script automatically sends `Authorization: Bearer ...` when it finds an API key in:

1. `JINA_API_KEY`
2. `JINA_TOKEN`
3. `~/.config/jina-reader/api_key`
4. `~/.jina_api_key`

Do not print or paste the token. If the user asks to "use my token", rely on those locations or ask them to set `JINA_API_KEY`; do not hard-code secrets into `SKILL.md`.

## Operations

### Read One URL

```bash
python3 scripts/jina_reader.py read "https://example.com/article" -o article.md
```

Useful options:

- `--json`: request JSON (`url`, `title`, `content`).
- `--respond-with markdown|html|text|screenshot`: bypass or change the extractor output.
- `--with-generated-alt`: ask Jina to caption images lacking alt text.
- `--no-cache`: bypass cached content.
- `--target-selector "main"`: return only a CSS-selected region.
- `--wait-for-selector "#content"`: wait for client-rendered content.
- `--timeout 30`: wait longer for slow dynamic pages.
- `--post`: use POST body `url=...`, especially for URLs containing hash routes.

### Search And Read Results

```bash
python3 scripts/jina_reader.py search "latest CUDA programming guide" --json
python3 scripts/jina_reader.py search "Jina Reader API" --site jina.ai --site github.com
```

Use `s.jina.ai` when discovery is part of the task. It searches the web, fetches the top results, and returns readable page content.

### Batch URLs

```bash
python3 scripts/jina_reader.py batch urls.txt --out-dir /tmp/jina-pages --json
```

The input file should contain one URL per line. Empty lines and `#` comments are ignored.

## Decision Guide

- Use `read` for a known URL.
- Use `search` when the user gives a topic, not a URL.
- Use `--post` for SPA hash routes like `https://example.com/#/docs`.
- Use `--wait-for-selector` or `--timeout` when the page returns preload, shell, or incomplete content.
- Use `--respond-with html` only when Markdown loses structure you need.
- Use `--with-generated-alt` only when image meaning matters; it can increase latency.
- If Jina returns incomplete or blocked output after selector/timeout attempts, fall back to a browser-capable scraper.

## Reference

Read `references/reader-api-notes.md` when you need official endpoint behavior, headers, SPA handling, JSON mode, or troubleshooting details.
