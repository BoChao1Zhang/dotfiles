---
name: siyuan-sisyphus-cli
description: Operate SiYuan Note through the SiYuan Sisyphus MCP tools by default. Use when Codex needs to inspect, search, create, edit, organize, export, or manage SiYuan notes, blocks, notebooks, attribute views/databases, tags, assets, flashcards, or system info. Prefer MCP for ordinary SiYuan work; use the `siyuan-sisyphus` / `siyuan` CLI only when the user explicitly asks for CLI/shell usage, when MCP tools are unavailable, when a needed operation is not exposed by MCP, or when scripting against SiYuan is required.
---

# SiYuan Sisyphus MCP

Use the SiYuan Sisyphus MCP tools as the default path for SiYuan reads and writes. Do not check CLI availability before ordinary MCP work, and do not switch to the CLI just because shell commands feel convenient. The MCP server and CLI are backed by the same SiYuan Sisyphus plugin settings and notebook permissions.

Use the `siyuan-sisyphus` or `siyuan` CLI only when the user explicitly asks for CLI/shell commands, when the MCP tools are unavailable, when the requested operation is not exposed by MCP, or when a repeatable shell script is the task itself. For exact fallback command conventions, read `references/cli-reference.md`.

## Workflow

1. Use MCP tools first for SiYuan operations. Prefer `fs` for human-readable document paths, and use lower-level tools when block IDs, document IDs, database IDs, or specialized actions are needed.
2. Start with read-only discovery before writing:
   - notebooks: `notebook(action="list")`
   - documents and paths: `fs(action="ls"|"tree"|"read"|"search")`, `document(action="lookup"|"search_docs"|"get_doc"|"list_tree")`
   - blocks: `block(action="info"|"get_kramdown"|"get_children")`
   - databases: `av(action="search"|"get"|"render"|"get_attribute_view_keys")`
   - search: `search(action="fulltext"|"query_sql"|"get_backlinks")`
3. Execute the smallest needed MCP mutation, then verify with a read-only MCP call.
4. Use the CLI fallback only after confirming MCP is unavailable or insufficient, or when the user asked for a command-line workflow.

Prefer structured MCP responses over parsing rendered text. When using the CLI fallback, prefer `--json` for outputs Codex will parse.

## MCP Tool Map

- `fs`: ordinary document file operations by human-readable workspace path. Use this first for list, tree, read, write, replace, and search.
- `notebook`: notebook list, create, open/close, rename, config, icons, and permissions.
- `document`: document lookup, create, rename, duplicate, tree, daily notes, and document/block conversions.
- `block`: block insert, append, update, attributes, breadcrumbs, children, and kramdown.
- `av`: attribute view/database reads, rows, columns, and cell updates.
- `search`: full-text search, SQL reads, backlinks, references, assets, and find/replace.
- `tag`: list, rename, and remove tags.
- `file`: assets, export, templates, OCR, and unused asset cleanup.
- `system`: SiYuan version, config, time, network, and notifications.

## Common MCP Patterns

List notebooks:

```text
notebook(action="list")
```

Read a document by human-readable path:

```text
fs(action="read", path="/Notebook/Folder/Document")
```

Create or overwrite a document body by path:

```text
fs(action="write", path="/Notebook/Folder/Document", markdown="...", overwrite=true)
```

Append markdown to a document or block:

```text
block(action="append", parentID="<doc-or-block-id>", dataType="markdown", data="- item")
```

Search content:

```text
search(action="fulltext", query="keyword", pageSize=20)
```

Run a read-only SQL query:

```text
search(action="query_sql", stmt="SELECT id, content FROM blocks WHERE type='h' LIMIT 5")
```

## Safety Rules

Respect the MCP tool descriptions and ask for explicit user confirmation before actions marked destructive or broad. In particular, confirm before:

- `notebook remove`
- `notebook set_permission`
- `document remove`
- `document move`
- `block delete`
- `block move`
- `search find-replace`
- `file upload-asset`
- `file remove-unused-assets`
- `file delete-asset`

Before path-based document mutations, prefer `fs` with human-readable paths. For lower-level `document` operations, resolve whether the action expects a human-readable path, document ID, or storage path.

Never expose or print the user's SiYuan token in final answers. Prefer config profiles or environment variables over inline `--token` when sharing commands.

## Markdown Authoring Rules

- When creating a document, the SiYuan path/title already becomes the document title. Do not start the markdown body with the same `# Title`; begin with a short intro paragraph/blockquote, then use `##` for sections.
- Keep related prompt examples or commands in one continuous fenced code block. Avoid multiple adjacent fenced blocks under the same label such as "示例：" or "常用请求："; SiYuan renders each fence as a separate block, which makes the content look fragmented.
- If examples need visual separation inside one code block, separate them with blank lines or comment markers inside the same fence.

## CLI Fallback

Use the CLI only for explicit CLI requests, MCP outages, missing MCP coverage, or shell scripting tasks. Check availability with:

```bash
command -v siyuan-sisyphus || command -v siyuan
```

If missing, tell the user the CLI can be installed with `npm i -g siyuan-sisyphus`; do not install globally unless the user asked for setup.

CLI command shape:

```bash
siyuan-sisyphus <tool> <action> [--flag value ...]
siyuan <tool> <action> [--flag value ...]
```

Read `references/cli-reference.md` only when exact CLI syntax, flags, or examples are needed.

## Configuration

MCP connectivity is normally handled by the Codex MCP server configuration. The SiYuan Sisyphus plugin must be installed and enabled in SiYuan, and plugin permissions must allow the requested tool/action and target notebook.

CLI fallback config lives at `~/.siyuan-sisyphus/config.json`; older `~/.siyuan-mcp/config.json` may be read as a fallback.

## Troubleshooting

- If MCP tools are not present in the session, say so and use the CLI fallback when available.
- If MCP reports a permission or disabled-action error, check the SiYuan Sisyphus plugin settings and notebook permissions.
- If reads work but writes fail, check notebook permission: `r` is read-only, `rw` permits writes, `rwd` permits delete, and `none` blocks access.
- If a tool/action is absent from MCP, use the CLI fallback only if the CLI exposes it or the user asks for command-line setup.
