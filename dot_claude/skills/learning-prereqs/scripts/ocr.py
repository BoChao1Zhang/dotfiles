"""OCR a local PDF via the Mistral OCR API and save markdown + figures.

Usage:
    ocr.py <input.pdf> <output_dir>

Requires the env var MISTRAL_API_KEY. Writes:
    <output_dir>/document.md         all pages, markdown, page-separated
    <output_dir>/images/<id>.jpeg    figures extracted by Mistral
    <output_dir>/raw_response.json   the full OCR response (for debugging)

The flow is the canonical three-step Mistral pattern, because /v1/ocr only
accepts URLs (or data URIs that blow up past a few MB):
    1. POST /v1/files          upload PDF, get file id
    2. GET  /v1/files/<id>/url temporary signed URL
    3. POST /v1/ocr            run OCR against that URL
"""
from __future__ import annotations

import base64
import json
import mimetypes
import os
import sys
import urllib.request
import uuid
from pathlib import Path

API_BASE = "https://api.mistral.ai/v1"
OCR_MODEL = "mistral-ocr-latest"


def _http(method: str, url: str, *, headers: dict, body: bytes | None = None) -> dict:
    req = urllib.request.Request(url, method=method, data=body, headers=headers)
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())


def _multipart(fields: dict[str, str], files: dict[str, tuple[str, bytes, str]]) -> tuple[bytes, str]:
    boundary = "----flashboundary" + uuid.uuid4().hex
    parts: list[bytes] = []
    for name, value in fields.items():
        parts.append(
            f"--{boundary}\r\nContent-Disposition: form-data; name=\"{name}\"\r\n\r\n{value}\r\n".encode()
        )
    for name, (filename, content, ctype) in files.items():
        parts.append(
            (
                f"--{boundary}\r\nContent-Disposition: form-data; "
                f"name=\"{name}\"; filename=\"{filename}\"\r\n"
                f"Content-Type: {ctype}\r\n\r\n"
            ).encode()
        )
        parts.append(content)
        parts.append(b"\r\n")
    parts.append(f"--{boundary}--\r\n".encode())
    return b"".join(parts), boundary


def upload(pdf: Path, key: str) -> str:
    ctype = mimetypes.guess_type(pdf.name)[0] or "application/pdf"
    body, boundary = _multipart(
        {"purpose": "ocr"},
        {"file": (pdf.name, pdf.read_bytes(), ctype)},
    )
    resp = _http(
        "POST",
        f"{API_BASE}/files",
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": f"multipart/form-data; boundary={boundary}",
        },
        body=body,
    )
    return resp["id"]


def signed_url(file_id: str, key: str) -> str:
    resp = _http(
        "GET",
        f"{API_BASE}/files/{file_id}/url?expiry=24",
        headers={"Authorization": f"Bearer {key}", "Accept": "application/json"},
    )
    return resp["url"]


def ocr(url: str, key: str) -> dict:
    body = json.dumps(
        {
            "model": OCR_MODEL,
            "document": {"type": "document_url", "document_url": url},
            "include_image_base64": True,
        }
    ).encode()
    return _http(
        "POST",
        f"{API_BASE}/ocr",
        headers={
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        body=body,
    )


def save_outputs(resp: dict, out_dir: Path) -> tuple[int, int]:
    out_dir.mkdir(parents=True, exist_ok=True)
    img_dir = out_dir / "images"
    img_dir.mkdir(exist_ok=True)

    (out_dir / "raw_response.json").write_text(json.dumps(resp, ensure_ascii=False, indent=2))

    md_parts: list[str] = []
    n_images = 0
    for page in resp.get("pages", []):
        idx = page.get("index", len(md_parts))
        md_parts.append(f"<!-- page {idx} -->\n\n{page.get('markdown', '').rstrip()}\n")
        for img in page.get("images", []) or []:
            iid = img.get("id") or f"page-{idx}-img-{n_images}.jpeg"
            data = img.get("image_base64")
            if not data:
                continue
            if "," in data:
                data = data.split(",", 1)[1]
            (img_dir / iid).write_bytes(base64.b64decode(data))
            n_images += 1

    (out_dir / "document.md").write_text("\n\n---\n\n".join(md_parts), encoding="utf-8")
    return len(md_parts), n_images


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        sys.stderr.write("usage: ocr.py <input.pdf> <output_dir>\n")
        return 2
    pdf = Path(argv[1]).expanduser().resolve()
    out_dir = Path(argv[2]).expanduser().resolve()

    key = os.environ.get("MISTRAL_API_KEY")
    if not key:
        sys.stderr.write(
            "error: MISTRAL_API_KEY not set. Get one at https://console.mistral.ai/, "
            "then `export MISTRAL_API_KEY=...` (add to ~/.zshrc to persist).\n"
        )
        return 1
    if not pdf.is_file():
        sys.stderr.write(f"error: not a file: {pdf}\n")
        return 1

    print(f"→ uploading {pdf.name} ({pdf.stat().st_size // 1024} KB)")
    file_id = upload(pdf, key)
    print(f"  file id: {file_id}")

    url = signed_url(file_id, key)
    print("→ running OCR (mistral-ocr-latest)…")
    resp = ocr(url, key)

    pages, images = save_outputs(resp, out_dir)
    print(f"✓ wrote {pages} pages, {images} images → {out_dir}")
    print(f"  markdown: {out_dir / 'document.md'}")
    print(f"  figures:  {out_dir / 'images'}/")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
