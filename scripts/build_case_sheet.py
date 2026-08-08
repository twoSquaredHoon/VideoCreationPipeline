#!/usr/bin/env python3
"""Build case_sheet.txt — structured summary of important facts from the blog article.

This is the Studio “Article summary” workflow step (replaces script-vs-article check).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from blog_to_script import fetch_blog_text
from case_sheet import extract_case_sheet, save_case_sheet
from language_config import normalize_language

DEFAULT_MODEL = "gemini-2.5-flash"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Extract a medical case sheet (article summary) for a project."
    )
    parser.add_argument("--url", required=True, help="Original blog URL")
    parser.add_argument(
        "--output-dir",
        type=Path,
        required=True,
        help="Project folder (writes case_sheet.txt and source_article.txt)",
    )
    parser.add_argument(
        "--language",
        default="en",
        choices=["en", "ko", "es"],
    )
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument(
        "--use-cached-article",
        action="store_true",
        help="Reuse source_article.txt if present",
    )
    args = parser.parse_args()

    url = args.url.strip()
    if not url.startswith(("http://", "https://")):
        print("URL must start with http:// or https://", file=sys.stderr)
        sys.exit(1)

    out_dir = args.output_dir.expanduser().resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    language = normalize_language(args.language)
    article_cache = out_dir / "source_article.txt"

    try:
        if args.use_cached_article and article_cache.is_file():
            print(f"Using cached article: {article_cache}")
            article_text = article_cache.read_text(encoding="utf-8").strip()
        else:
            article_text = fetch_blog_text(url)
            article_cache.write_text(article_text + "\n", encoding="utf-8")
            print(f"  Cached article → {article_cache}")

        sheet = extract_case_sheet(
            article_text,
            model=args.model,
            source_url=url,
            language=language,
        )
        sheet_path = save_case_sheet(
            out_dir / "case_sheet.txt",
            sheet,
            source_url=url,
            language=language,
        )
    except Exception as exc:
        print(f"\nFAILED: {exc}", file=sys.stderr)
        sys.exit(1)

    print("\n" + "=" * 40 + " CASE SHEET " + "=" * 28 + "\n")
    print(sheet)
    print("\n" + "=" * 40)
    print(f"Saved → {sheet_path}")


if __name__ == "__main__":
    main()
