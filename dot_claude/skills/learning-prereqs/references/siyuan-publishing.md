# SiYuan Publishing

Use this reference after the diagnostic and brief drafts are ready. The final output for this skill is a SiYuan document tree.

## Preflight

Check the CLI and connection:

```bash
command -v siyuan-sisyphus || command -v siyuan
siyuan-sisyphus --version
siyuan-sisyphus config list
siyuan-sisyphus notebook list --json
```

If `siyuan-sisyphus` is unavailable but `siyuan` exists, use `siyuan` in the same command shape. If neither exists, stop and ask the user to install/configure the SiYuan Sisyphus CLI or connect the MCP plugin.

Use the `$siyuan-sisyphus-cli` skill when available for command discovery, safety rules, and troubleshooting.

## Notebook Selection

Use the user-specified notebook when provided. Otherwise inspect:

```bash
siyuan-sisyphus notebook list --json
siyuan-sisyphus notebook get-permissions --json
```

If exactly one open notebook is writable, use it. If multiple writable notebooks are plausible, ask before publishing.

## Document Tree

Create or reuse this human-readable path tree:

```text
/Learning Prereqs
/Learning Prereqs/<slug> (<short title>)
/Learning Prereqs/<slug> (<short title>)/00 - Material overview
/Learning Prereqs/<slug> (<short title>)/01 - Diagnostic
/Learning Prereqs/<slug> (<short title>)/02 - Brief - <main concept>
/Learning Prereqs/<slug> (<short title>)/03 - Brief - <foundation>
```

Slug examples: `ppo-paper`, `cuda-sm-warp`, `chernoff-subgaussian`.

## Create And Verify

Create documents with markdown:

```bash
siyuan-sisyphus document create --notebook <notebook-id> --path "/Learning Prereqs" --markdown "# Learning Prereqs"
siyuan-sisyphus document create --notebook <notebook-id> --path "/Learning Prereqs/<slug> (<title>)" --markdown "<material markdown>"
siyuan-sisyphus document create --notebook <notebook-id> --path "/Learning Prereqs/<slug> (<title>)/01 - Diagnostic" --markdown "<diagnostic markdown>"
siyuan-sisyphus document create --notebook <notebook-id> --path "/Learning Prereqs/<slug> (<title>)/02 - Brief - <concept>" --markdown "<brief markdown>"
```

For large markdown bodies, avoid manual shell escaping. Keep drafts under `/tmp/learning-prereqs/<slug>/` and pass file contents to the CLI through a subprocess argument in the active shell or a small one-off script. Do not paste huge markdown into the final user answer.

After each create, capture the returned id if present. Verify with one of:

```bash
siyuan-sisyphus document lookup --notebook <notebook-id> --hpath "/Learning Prereqs/<slug> (<title>)/02 - Brief - <concept>" --include id --include path --json
siyuan-sisyphus document list-tree --notebook <notebook-id> --max-depth 3 --json
```

If `document create` fails because the parent does not exist, create the parent first and retry.

## Existing Documents

Before creating the top-level hub or material page, search/lookup to avoid duplicates:

```bash
siyuan-sisyphus document lookup --notebook <notebook-id> --hpath "/Learning Prereqs" --include id --json
siyuan-sisyphus document search-docs --notebook <notebook-id> --query "<slug>" --json
```

If a material page already exists from the same session, append missing briefs as child documents rather than creating a duplicate material hub.

## Image Handling

Markdown can contain figure placeholders while publishing is blocked:

```markdown
[fig: /tmp/learning-prereqs/<slug>/figs/example.png]
```

To upload real assets, ask for explicit confirmation because the CLI reads local files:

```bash
siyuan-sisyphus file upload-asset --assets-dir-path "/assets/" --local-file-path "/absolute/path/to/figure.png" --json
```

Then replace the placeholder with the returned asset path using normal markdown image syntax. If upload is not available, leave placeholders and mention them in the handoff.

## Source Links

For handoff and flashcards, prefer:

```text
siyuan://blocks/<doc-id> - <document title>
```

Also keep the human-readable path:

```text
/Learning Prereqs/<slug> (<title>)/02 - Brief - <concept>
```

If a deep link cannot be verified in the user's environment, still set Anki `Source` to the document id plus hpath so the user can find it through SiYuan search.

## Safety

Ask before running commands that delete, move, batch replace, upload local files, export to local paths, or change notebook permissions. Publishing new documents under `/Learning Prereqs` is allowed once the target notebook is established.
