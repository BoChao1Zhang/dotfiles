# Mistral OCR — operating notes

`scripts/ocr.py` wraps the canonical three-step flow. This file is the
reference for when something looks off in the output.

## API surface

Endpoint: `POST https://api.mistral.ai/v1/ocr`

Auth: `Authorization: Bearer $MISTRAL_API_KEY` on every call.

Model: `mistral-ocr-latest` (alias; resolves to the current dated build, e.g.
`mistral-ocr-2503`). Pin the dated build only if you're locking down a
reproducibility-sensitive pipeline.

## Three-step flow for local PDFs

`/v1/ocr` only accepts URLs. Data URIs work for tiny inputs but bloat past a
few MB, so for any real PDF the path is:

1. **Upload**. `POST /v1/files` (multipart) with `purpose=ocr` → returns
   `{"id": "file-…"}`.
2. **Signed URL**. `GET /v1/files/<id>/url?expiry=24` → returns
   `{"url": "https://…"}`. The `expiry` is hours; 24 is plenty for a single
   OCR run.
3. **OCR**. `POST /v1/ocr` with body
   ```json
   {
     "model": "mistral-ocr-latest",
     "document": {"type": "document_url", "document_url": "<signed url>"},
     "include_image_base64": true
   }
   ```

`include_image_base64` is what makes figures come back inline; without it you
only get bounding boxes.

## Response shape

```json
{
  "pages": [
    {
      "index": 0,
      "markdown": "## …\n\n…",
      "images": [
        {
          "id": "img-0.jpeg",
          "top_left_x": 123, "top_left_y": 456,
          "bottom_right_x": 789, "bottom_right_y": 1011,
          "image_base64": "data:image/jpeg;base64,…"
        }
      ],
      "dimensions": {"dpi": 200, "height": 2200, "width": 1700}
    }
  ],
  "model": "mistral-ocr-2503",
  "usage_info": {"pages_processed": 12, "doc_size_bytes": 982341}
}
```

Per-page `markdown` is what you usually want. Tables come through as GFM,
math as LaTeX delimited by `$…$` / `$$…$$`. Image references in markdown
look like `![img-0.jpeg](img-0.jpeg)` — those filenames match the saved
files in `<out>/images/`.

## What `scripts/ocr.py` writes

```
<out_dir>/
├── document.md          all pages concatenated, separated by `---` rules and
│                        `<!-- page N -->` HTML comments so you can grep back
├── images/
│   ├── img-0.jpeg
│   ├── img-1.jpeg
│   └── …
└── raw_response.json    full API response for debugging or for re-running
                         downstream steps without burning more credits
```

## Cost / rate

~$1 per 1000 pages on the public price sheet (verify on
`https://docs.mistral.ai/capabilities/document_ai/basic_ocr/`). Free-tier
keys process ~5 pages/min; paid keys are practically rate-limited per
account. For a 30-page paper, expect <10 s end-to-end.

## Edge cases

- **Scanned-with-handwriting** → math goes through fine; handwritten Chinese
  is hit-or-miss. Tell the user the figures are reliable but proofread the
  prose.
- **Multi-column** layouts → reading order is usually right; if it's not,
  the page's markdown will interleave columns visibly. Drop back to a
  single-column re-export from the original (or accept the noise).
- **Pages > 50 MB total** → `/v1/files` rejects with 413. Pre-split with
  `qpdf --split-pages=N input.pdf out_%d.pdf` and OCR per chunk.
- **Cyrillic / Arabic / CJK** → all fine. The output is UTF-8.
- **Equations** → preserved as raw LaTeX; downstream KaTeX renders them as
  long as you wrap with `$…$` (already done by the model).
- **Empty `images` array** but the page clearly has a figure → almost always
  a vector figure embedded as PDF marks; Mistral rasterizes most of them but
  occasionally misses one. Drop to extracting via `pdfimages -png input.pdf
  out_dir/img` as a fallback for that single page.

## Why no local fallback

We deliberately don't ship a mineru / marker / nougat fallback. The skill's
quality floor depends on the OCR being good enough that the prereq-mapping
step in `SKILL.md` step 2 actually sees the math and figures the way the
author wrote them. A "good enough offline" path would silently degrade
those steps and the user would only notice when the briefs miss the point.
If `MISTRAL_API_KEY` isn't set, fail loudly — that's a feature.
