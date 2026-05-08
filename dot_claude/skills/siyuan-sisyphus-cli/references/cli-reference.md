# SiYuan Sisyphus CLI Fallback Reference

Use this reference only when the main skill has triggered and exact CLI syntax is needed for an explicit CLI request, MCP outage, missing MCP coverage, or a shell scripting task.

## Prerequisites

- Install and enable the `siyuan-plugins-mcp-sisyphus` plugin in SiYuan.
- Configure notebook permissions in the plugin settings.
- Run a SiYuan instance reachable over HTTP, usually `http://127.0.0.1:6806`.
- Provide the SiYuan API token through `siyuan-sisyphus init`, a config profile, `SIYUAN_TOKEN`, or `--token`.

Install command, when setup is explicitly requested:

```bash
npm i -g siyuan-sisyphus
```

One-off command:

```bash
npx -p siyuan-sisyphus siyuan-sisyphus --help
```

## Help Discovery

```bash
siyuan-sisyphus --help
siyuan-sisyphus --version
siyuan-sisyphus list
siyuan-sisyphus list block
siyuan-sisyphus help block append
```

## Flag Rules

- Kebab, camel, and snake names map to schema fields: `--parent-id`, `--parentId`, and `--parent_id` are equivalent when the schema field is `parentID`.
- Action names accept snake or kebab in many cases: `set_open_state` or `set-open-state`.
- Boolean flags accept `--opened`, `--opened=false`, or `--no-opened`.
- Arrays can be repeated, comma-separated, or passed as JSON: `--ids a --ids b`, `--ids a,b`, or `--ids-json '["a","b"]'`.
- Complex objects use JSON sidecar flags: `--assets-json '[{"name":"a"}]'`.
- If a plain flag and its `--<key>-json` sidecar are both present, the JSON sidecar wins.

## Tool Summary

| Tool | Use |
|---|---|
| `notebook` | List, create, open/close, icon, and permission operations |
| `document` | Create, lookup, read, rename, move, duplicate, tree, daily notes |
| `block` | Insert, append, update, delete, move, attrs, children, kramdown |
| `av` | Attribute view/database rows, columns, cells, and reads |
| `search` | Full-text search, SQL, refs, backlinks, assets, find/replace |
| `tag` | List, rename, remove tags |
| `file` | Assets, export, templates, OCR, unused asset cleanup |
| `system` | Version, time, config summary, fonts, notifications |
| `flashcard` | Decks, due cards, review, create/add/remove cards |
| `mascot` | Mascot state, shop, and buy actions |

## Read-Only Examples

```bash
siyuan-sisyphus system get-version --json
siyuan-sisyphus notebook list --json
siyuan-sisyphus document search-docs --notebook <id> --query "proposal" --json
siyuan-sisyphus document list-tree --notebook <id> --max-depth 2 --json
siyuan-sisyphus document lookup --id <doc-id> --include path --json
siyuan-sisyphus document get-doc --id <doc-id> --mode markdown --json
siyuan-sisyphus block info --id <block-id> --json
siyuan-sisyphus block get-kramdown --id <block-id> --json
siyuan-sisyphus block get-children --id <block-id> --json
siyuan-sisyphus search fulltext --query "TODO" --page 1 --page-size 20 --json
siyuan-sisyphus search query-sql --stmt "SELECT id, content FROM blocks WHERE type='h' LIMIT 5" --json
```

## Mutation Examples

Create a notebook:

```bash
siyuan-sisyphus notebook create --name "Work" --icon 1f4d4
```

Create a document:

```bash
siyuan-sisyphus document create --notebook <notebook-id> --path "/Inbox/Daily" --markdown "# Today"
```

Append content:

```bash
siyuan-sisyphus block append --parent-id <doc-or-block-id> --data-type markdown --data "- [ ] Todo item"
```

Update one block:

```bash
siyuan-sisyphus block update --id <block-id> --data-type markdown --data "Replacement text"
```

Set attributes:

```bash
siyuan-sisyphus block set-attrs --id <block-id> --attrs-json '{"custom-status":"active"}'
```

Add content to today's daily note:

```bash
siyuan-sisyphus block add-to-daily-note --notebook <notebook-id> --data-type markdown --data "- note" --position append
```

## Attribute View Notes

Use `av get` to inspect an attribute view before changing it. For cell updates, prefer IDs returned directly from `av add-rows` or `av get`.

```bash
siyuan-sisyphus av get --id <av-id> --json
siyuan-sisyphus av add-rows --av-id <av-id> --block-ids-json '["<block-id>"]'
siyuan-sisyphus av set-cells --av-id <av-id> --row-id <row-item-id> --column-id <column-id> --value-type text --text "value"
```

Important distinction: a source block ID, a row binding ID, and a cell value ID can be different. For `set-cells`, use the writable row item ID and `columnID`/`--column-id`.

## Config Commands

```bash
siyuan-sisyphus init
siyuan-sisyphus config list
siyuan-sisyphus config set work --url http://127.0.0.1:6806 --token <token>
siyuan-sisyphus config use work
siyuan-sisyphus config get work
siyuan-sisyphus --profile work notebook list
```

Default config shape:

```json
{
  "currentProfile": "default",
  "profiles": {
    "default": {
      "apiUrl": "http://127.0.0.1:6806",
      "token": "<siyuan-token>"
    }
  }
}
```

## Path Semantics

Human-readable paths are useful for creation and lookup:

```bash
siyuan-sisyphus document create --notebook <id> --path "/Inbox/Weekly Note" --markdown "# Weekly Report"
```

Storage paths may be required for path-based rename, move, and remove. Resolve before mutating:

```bash
siyuan-sisyphus document lookup --id <doc-id> --include path --json
```

## Confirmation Checklist

Before running a self-selected destructive or broad mutation, confirm:

- exact target notebook/document/block/asset IDs or paths
- action name and command to run
- whether the operation can delete, move, overwrite, upload local files, export files, or batch replace content
- expected verification command after completion
