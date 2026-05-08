# Jina Reader API Notes

Sources checked:

- Jina Reader product page: https://jina.ai/reader/
- Jina Reader repository README: https://github.com/jina-ai/reader
- Jina API dashboard: https://jina.ai/api-dashboard/

## Endpoints

- `https://r.jina.ai/<url>` reads a single URL and converts it into LLM-friendly content.
- `https://s.jina.ai/<encoded query>` searches the web, fetches the top results, and applies Reader extraction to each result.
- In-site search uses repeated `site` query params, for example:

```bash
curl 'https://s.jina.ai/When%20was%20Jina%20AI%20founded%3F?site=jina.ai&site=github.com'
```

## Authentication

Use:

```bash
Authorization: Bearer $JINA_API_KEY
```

The script reads `JINA_API_KEY` by default. Keep the key in the environment or a local private config file, not in skill prose or committed artifacts.

## Output Modes

Default output is Markdown-like text. Request JSON with:

```bash
Accept: application/json
```

For `r.jina.ai`, JSON content may appear directly as `url`, `title`, and `content`, or wrapped in a response object under `data` with `code` and `status`. For `s.jina.ai`, `data` is typically a list of search results with similar fields.

Change extraction with `x-respond-with`:

- `markdown`: markdown without readability filtering
- `html`: `documentElement.outerHTML`
- `text`: `document.body.innerText`
- `screenshot`: screenshot URL

## Useful Headers

- `x-with-generated-alt: true`: generate image captions for images without alt text.
- `x-no-cache: true`: bypass cached page.
- `x-cache-tolerance: <seconds>`: customize cache tolerance.
- `x-target-selector: <css>`: extract only a selected element.
- `x-wait-for-selector: <css>`: wait until an element appears.
- `x-timeout: <seconds>`: wait longer for dynamic pages.
- `x-set-cookie: <cookie>`: forward cookies. Avoid unless the user explicitly provides cookies.
- `x-proxy-url: <url>`: use a proxy. Avoid unless needed and approved.

## SPA And Dynamic Pages

Hash routes are not sent to servers by normal GET requests. Use POST:

```bash
curl -X POST 'https://r.jina.ai/' -d 'url=https://example.com/#/route'
```

If content appears late, try `x-wait-for-selector` first when you know the selector, otherwise try `x-timeout`.

## Streaming

Streaming can help when standard mode returns partial content:

```bash
curl -H 'Accept: text/event-stream' 'https://r.jina.ai/https://example.com'
```

Each later chunk is usually more complete than earlier chunks. For most Codex tasks, prefer non-streaming unless normal output is incomplete.
