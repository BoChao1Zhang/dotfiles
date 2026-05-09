#!/usr/bin/env python3
"""Small CLI for Jina AI Reader (r.jina.ai and s.jina.ai)."""

from __future__ import annotations

import argparse
import json
import os
import re
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


DEFAULT_TIMEOUT = 60


def default_ssl_context() -> ssl.SSLContext:
    for cafile in (
        os.environ.get("SSL_CERT_FILE"),
        "/opt/homebrew/etc/ca-certificates/cert.pem",
        "/etc/ssl/cert.pem",
    ):
        if cafile and Path(cafile).exists():
            return ssl.create_default_context(cafile=cafile)
    return ssl.create_default_context()


def load_api_key(explicit: str | None, no_token: bool) -> str | None:
    if no_token:
        return None
    if explicit:
        return explicit.strip()
    for name in ("JINA_API_KEY", "JINA_TOKEN"):
        value = os.environ.get(name)
        if value:
            return value.strip()
    for path in (Path("~/.config/jina-reader/api_key").expanduser(), Path("~/.jina_api_key").expanduser()):
        try:
            if path.exists():
                value = path.read_text(encoding="utf-8").strip()
                if value:
                    return value
        except OSError:
            pass
    return None


def parse_extra_headers(values: list[str]) -> dict[str, str]:
    headers: dict[str, str] = {}
    for value in values:
        if ":" not in value:
            raise SystemExit(f"Invalid --header value, expected 'Name: value': {value}")
        name, header_value = value.split(":", 1)
        name = name.strip()
        header_value = header_value.strip()
        if not name or not header_value:
            raise SystemExit(f"Invalid --header value, expected 'Name: value': {value}")
        headers[name] = header_value
    return headers


def build_headers(args: argparse.Namespace) -> dict[str, str]:
    headers = {
        "User-Agent": "codex-jina-reader-skill/1.0",
    }
    api_key = load_api_key(getattr(args, "api_key", None), getattr(args, "no_token", False))
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    if getattr(args, "json", False):
        headers["Accept"] = "application/json"
    if getattr(args, "stream", False):
        headers["Accept"] = "text/event-stream"
    if getattr(args, "respond_with", None):
        headers["x-respond-with"] = args.respond_with
    if getattr(args, "with_generated_alt", False):
        headers["x-with-generated-alt"] = "true"
    if getattr(args, "no_cache", False):
        headers["x-no-cache"] = "true"
    if getattr(args, "cache_tolerance", None) is not None:
        headers["x-cache-tolerance"] = str(args.cache_tolerance)
    if getattr(args, "target_selector", None):
        headers["x-target-selector"] = args.target_selector
    if getattr(args, "wait_for_selector", None):
        headers["x-wait-for-selector"] = args.wait_for_selector
    if getattr(args, "reader_timeout", None) is not None:
        headers["x-timeout"] = str(args.reader_timeout)
    headers.update(parse_extra_headers(getattr(args, "header", []) or []))
    return headers


def request_text(url: str, headers: dict[str, str], timeout: int, data: bytes | None = None) -> str:
    req = urllib.request.Request(url=url, data=data, headers=headers, method="POST" if data else "GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=default_ssl_context()) as resp:
            charset = resp.headers.get_content_charset() or "utf-8"
            return resp.read().decode(charset, errors="replace")
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise SystemExit(f"Jina request failed with HTTP {exc.code}: {body[:2000]}") from exc
    except urllib.error.URLError as exc:
        raise SystemExit(f"Jina request failed: {exc}") from exc


def write_output(text: str, output: str | None) -> None:
    if output:
        path = Path(output)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        print(str(path))
    else:
        print(text, end="" if text.endswith("\n") else "\n")


def reader_url_for(target_url: str) -> str:
    if target_url.startswith("https://r.jina.ai/") or target_url.startswith("http://r.jina.ai/"):
        return target_url
    return "https://r.jina.ai/" + target_url


def slug_for_url(url: str, index: int) -> str:
    parsed = urllib.parse.urlparse(url)
    raw = f"{parsed.netloc}{parsed.path}".strip("/") or f"url-{index}"
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", raw).strip("-")
    return slug[:120] or f"url-{index}"


def cmd_read(args: argparse.Namespace) -> None:
    headers = build_headers(args)
    data = None
    endpoint = reader_url_for(args.url)
    if args.post or "#" in args.url:
        endpoint = "https://r.jina.ai/"
        data = urllib.parse.urlencode({"url": args.url}).encode("utf-8")
        headers.setdefault("Content-Type", "application/x-www-form-urlencoded")
    text = request_text(endpoint, headers=headers, timeout=args.request_timeout, data=data)
    write_output(text, args.output)


def cmd_search(args: argparse.Namespace) -> None:
    headers = build_headers(args)
    encoded_query = urllib.parse.quote(args.query, safe="")
    query_params: list[tuple[str, str]] = []
    for site in args.site or []:
        query_params.append(("site", site))
    suffix = ""
    if query_params:
        suffix = "?" + urllib.parse.urlencode(query_params)
    endpoint = f"https://s.jina.ai/{encoded_query}{suffix}"
    text = request_text(endpoint, headers=headers, timeout=args.request_timeout)
    write_output(text, args.output)


def cmd_batch(args: argparse.Namespace) -> None:
    input_path = Path(args.input)
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    urls = []
    for line in input_path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            urls.append(stripped)
    manifest = []
    for index, url in enumerate(urls, start=1):
        child = argparse.Namespace(**vars(args))
        child.url = url
        child.output = str(out_dir / f"{index:03d}-{slug_for_url(url, index)}.{ 'json' if args.json else 'md' }")
        cmd_read(child)
        manifest.append({"url": url, "output": child.output})
    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(str(out_dir / "manifest.json"))


def add_common_options(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--api-key", help="Jina API key override. Prefer JINA_API_KEY.")
    parser.add_argument("--no-token", action="store_true", help="Do not send Authorization.")
    parser.add_argument("--json", action="store_true", help="Request application/json.")
    parser.add_argument("--stream", action="store_true", help="Request text/event-stream.")
    parser.add_argument("--respond-with", choices=("markdown", "html", "text", "screenshot"))
    parser.add_argument("--with-generated-alt", action="store_true", help="Generate missing image alt text.")
    parser.add_argument("--no-cache", action="store_true", help="Bypass Jina cache.")
    parser.add_argument("--cache-tolerance", type=int, help="Cache tolerance in seconds.")
    parser.add_argument("--target-selector", help="CSS selector to extract.")
    parser.add_argument("--wait-for-selector", help="CSS selector to wait for.")
    parser.add_argument("--reader-timeout", type=int, help="x-timeout header in seconds.")
    parser.add_argument("--request-timeout", type=int, default=DEFAULT_TIMEOUT, help="Local HTTP timeout in seconds.")
    parser.add_argument("--header", action="append", default=[], help="Extra request header, e.g. 'x-set-cookie: a=b'.")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Fetch readable web content through Jina AI Reader.")
    sub = parser.add_subparsers(dest="command", required=True)

    read = sub.add_parser("read", help="Read one URL through r.jina.ai.")
    read.add_argument("url")
    read.add_argument("-o", "--output")
    read.add_argument("--post", action="store_true", help="POST url=... to r.jina.ai, useful for hash routes.")
    add_common_options(read)
    read.set_defaults(func=cmd_read)

    search = sub.add_parser("search", help="Search and read results through s.jina.ai.")
    search.add_argument("query")
    search.add_argument("-o", "--output")
    search.add_argument("--site", action="append", help="Restrict search to a site/domain. Repeatable.")
    add_common_options(search)
    search.set_defaults(func=cmd_search)

    batch = sub.add_parser("batch", help="Read many URLs from a text file.")
    batch.add_argument("input")
    batch.add_argument("--out-dir", required=True)
    batch.add_argument("--post", action="store_true")
    add_common_options(batch)
    batch.set_defaults(func=cmd_batch)
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
