#!/usr/bin/env python3
"""Fetch a blog post URL and generate a spoken video script via Gemini."""

from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import urlparse

import trafilatura
from google.genai import types

from case_sheet import extract_case_sheet, save_case_sheet
from gemini_util import PROJECT_ROOT, get_client
from language_config import get_language, normalize_language

DEFAULT_MODEL = "gemini-2.5-flash"
OUTPUT_DIR = PROJECT_ROOT / "output" / "scripts"


def fetch_blog_text(url: str) -> str:
    print(f"Fetching: {url}")
    downloaded = trafilatura.fetch_url(url)
    if not downloaded:
        raise RuntimeError("Could not download the page. Check the URL and try again.")

    text = trafilatura.extract(
        downloaded,
        include_comments=False,
        include_tables=False,
        favor_precision=True,
    )
    if not text or len(text.strip()) < 200:
        text = trafilatura.extract(
            downloaded,
            include_comments=False,
            include_tables=False,
            favor_precision=False,
        )
    if not text or len(text.strip()) < 200:
        raise RuntimeError(
            "Could not extract enough article text from that page. "
            "The site may block bots or use a layout trafilatura cannot read."
        )
    print(f"  Extracted {len(text)} characters of article text.")
    return text.strip()


def slug_from_url(url: str) -> str:
    path = urlparse(url).path.strip("/")
    slug = path.split("/")[-1] if path else "blog-post"
    slug = re.sub(r"[^\w\-]+", "-", slug.lower()).strip("-")
    return slug[:60] or "blog-post"


def generate_script(
    blog_text: str,
    *,
    model: str,
    source_url: str,
    language: str = "en",
    case_sheet: str | None = None,
) -> str:
    client = get_client()
    lang = get_language(language)
    print(f"Writing script with {model} ({lang.label})...")

    sheet_block = ""
    if case_sheet:
        sheet_block = f"""
CASE SHEET (authoritative — do not contradict or strengthen beyond this):
---
{case_sheet}
---

If the case sheet says BLOCK_SCRIPT: yes, output only:
NEEDS_MEDICAL_REVIEW:
[reasons from the case sheet]
Do not write CASE/WHAT_MATTERS/ACTION/EMERGENCY/SAFE_CTA spoken lines.
"""

    user_message = f"""Blog URL: {source_url}

Blog article text:
---
{blog_text}
---
{sheet_block}
{lang.script_rules}
"""

    response = client.models.generate_content(
        model=model,
        contents=user_message,
        config=types.GenerateContentConfig(
            temperature=0.2,
            system_instruction=lang.script_system,
        ),
    )
    script = (response.text or "").strip()
    if not script:
        raise RuntimeError("Gemini returned an empty script.")
    return script


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Read a blog URL and generate a medically accurate video script."
    )
    parser.add_argument("url", help="Blog post URL")
    parser.add_argument(
        "--model",
        default=DEFAULT_MODEL,
        help=f"Gemini model (default: {DEFAULT_MODEL})",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Save script to this file (default: output/scripts/<slug>-<date>.txt)",
    )
    parser.add_argument(
        "--language",
        default="en",
        choices=["en", "ko", "es"],
        help="Script language: en (English), ko (Korean), or es (Spanish). Default: en",
    )
    parser.add_argument(
        "--print-only",
        action="store_true",
        help="Print script to terminal only; do not save a file.",
    )
    args = parser.parse_args()

    url = args.url.strip()
    if not url.startswith(("http://", "https://")):
        print("URL must start with http:// or https://", file=sys.stderr)
        sys.exit(1)

    try:
        language = normalize_language(args.language)
        blog_text = fetch_blog_text(url)
        case_sheet = extract_case_sheet(
            blog_text, model=args.model, source_url=url, language=language
        )
        print("\n" + "=" * 40 + " CASE SHEET " + "=" * 28 + "\n")
        print(case_sheet)
        script = generate_script(
            blog_text,
            model=args.model,
            source_url=url,
            language=language,
            case_sheet=case_sheet,
        )
    except Exception as exc:
        print(f"\nFAILED: {exc}", file=sys.stderr)
        sys.exit(1)

    print("\n" + "=" * 40 + " SCRIPT " + "=" * 32 + "\n")
    print(script)

    if args.print_only:
        return

    out_path = args.output
    if out_path is None:
        stamp = datetime.now().strftime("%Y%m%d")
        out_path = OUTPUT_DIR / f"{slug_from_url(url)}-{stamp}.txt"

    out_path.parent.mkdir(parents=True, exist_ok=True)
    lang = normalize_language(args.language)
    header = (
        f"# Source: {url}\n"
        f"# Language: {lang}\n"
        f"# Generated: {datetime.now().isoformat(timespec='seconds')}\n\n"
    )
    out_path.write_text(header + script + "\n", encoding="utf-8")

    if out_path.name == "script.txt" or (out_path.parent / "project.json").is_file():
        sheet_path = out_path.parent / "case_sheet.txt"
    else:
        sheet_path = out_path.with_name(out_path.stem + "-case_sheet.txt")
    save_case_sheet(sheet_path, case_sheet, source_url=url, language=lang)
    print("\n" + "=" * 40)
    print(f"Saved script to {out_path}")
    print(f"Saved case sheet to {sheet_path}")


if __name__ == "__main__":
    main()
