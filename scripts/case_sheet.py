"""Extract a structured medical case sheet from a blog article.

Used by:
- blog_to_script.py (before writing the spoken script)
- build_case_sheet.py / Article summary step in Modoc Studio
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

from gemini_util import get_client
from google.genai import types

DEFAULT_MODEL = "gemini-2.5-flash"

CASE_SHEET_PROMPT = """Extract a structured CASE SHEET from the blog for a medically accurate video.
Do not write the video script. Do not optimize for engagement.
Use ONLY facts in the article. If unknown, write "unknown" — never guess.
Never merge separate facts (e.g. fever duration + peak temperature at ER).

Fill every field:

Child age:
Main problem:
Symptom duration:
Highest reported temperature:
Timing of highest temperature:
Temperature pattern: (once / repeated / continuous / unknown)
Medication use:
Antibiotic use:
Treatment response: (improving / not improving / unknown)
Medical setting: (clinic / ER / hospital / unknown)
Main video question: (ONE clinical question only)
Secondary questions to exclude:
Same-day action: (only if source supports)
ER triggers: (only if source supports; else "none in source")
Unclear facts:
Parent-reported facts vs author recommendations: (briefly separate)

STOP CONDITIONS that would block a medically safe script (conflicts, unclear urgency, etc.).
If scripting should not proceed: BLOCK_SCRIPT: yes
Otherwise: BLOCK_SCRIPT: no
"""


def extract_case_sheet(
    blog_text: str,
    *,
    model: str = DEFAULT_MODEL,
    source_url: str = "",
    language: str = "en",
) -> str:
    client = get_client()
    print(f"Extracting case sheet with {model}...")
    user_message = f"""Blog URL: {source_url or "(unknown)"}

Blog article text:
---
{blog_text}
---

Language hint for quoting the source: {language}

{CASE_SHEET_PROMPT}
"""
    response = client.models.generate_content(
        model=model,
        contents=user_message,
        config=types.GenerateContentConfig(
            temperature=0.2,
            system_instruction=(
                "You extract structured medical case facts for accuracy-first parenting videos. "
                "Ignore engagement. Never merge separate timelines or temperatures. Never invent facts. "
                "Output plain text fields only."
            ),
        ),
    )
    sheet = (response.text or "").strip()
    if not sheet:
        raise RuntimeError("Gemini returned an empty case sheet.")
    return sheet


def save_case_sheet(
    path: Path,
    sheet: str,
    *,
    source_url: str = "",
    language: str = "en",
) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    stamped = datetime.now(timezone.utc).isoformat(timespec="seconds")
    header = (
        f"# Case sheet (article summary for medical video)\n"
        f"# Source: {source_url}\n"
        f"# Language: {language}\n"
        f"# Generated: {stamped}\n\n"
    )
    path.write_text(header + sheet.rstrip() + "\n", encoding="utf-8")
    return path


def load_case_sheet(path: Path) -> str:
    if not path.is_file():
        return ""
    return path.read_text(encoding="utf-8").strip()
