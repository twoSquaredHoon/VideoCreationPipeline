"""Canonical Modoc medical video script sections and clip id taxonomy.

Medical spoken structure (accuracy only — not engagement).
Replaces HOOK → BODY → RELIEF → CTA:

  CASE → WHAT_MATTERS → ACTION → EMERGENCY → SAFE_CTA
"""

from __future__ import annotations

import re

# Spoken script section headers (exact labels in script.txt).
SECTION_HEADERS = frozenset(
    {
        "CASE",
        "WHAT_MATTERS",
        "ACTION",
        "EMERGENCY",
        "SAFE_CTA",
        # Legacy (still parse old projects)
        "HOOK",
        "BODY",
        "RELIEF",
        "CTA",
    }
)

# Headers written by the new format (order for display / TTS timing hints).
CANONICAL_SECTION_ORDER = (
    "CASE",
    "WHAT_MATTERS",
    "ACTION",
    "EMERGENCY",
    "SAFE_CTA",
)

LEGACY_TO_CANONICAL = {
    "HOOK": "CASE",
    "BODY": "WHAT_MATTERS",
    "RELIEF": "ACTION",
    "CTA": "SAFE_CTA",
}


def normalize_section_header(line: str) -> str | None:
    """Return a section header token if this line is a section label."""
    normalized = line.strip().upper().strip(": ")
    # Allow "WHAT MATTERS" / "SAFE CTA" as aliases for underscore form.
    aliases = {
        "WHAT MATTERS": "WHAT_MATTERS",
        "SAFE CTA": "SAFE_CTA",
    }
    normalized = aliases.get(normalized, normalized)
    if normalized in SECTION_HEADERS:
        return normalized
    return None


def canonicalize_section(section: str) -> str:
    return LEGACY_TO_CANONICAL.get(section, section)


def clip_sort_key(clip_id: str) -> tuple:
    """Sort clips in spoken / timeline order (new + legacy ids)."""
    if clip_id in ("case", "hook"):
        return (0, 0)
    if clip_id.startswith("case_"):
        num = clip_id.split("_", 1)[-1]
        return (0, int(num) if num.isdigit() else 0)
    if clip_id in ("matters",) or clip_id.startswith("matters_"):
        num = clip_id.split("_", 1)[-1] if "_" in clip_id else "0"
        return (1, int(num) if str(num).isdigit() else 0)
    if clip_id.startswith("body_"):
        num = clip_id.split("_", 1)[-1]
        return (1, int(num) if num.isdigit() else 0)
    if clip_id.startswith("action_"):
        num = clip_id.split("_", 1)[-1]
        return (2, int(num) if num.isdigit() else 0)
    if clip_id == "action":
        return (2, 0)
    if clip_id.startswith("explain_"):
        num = clip_id.split("_", 1)[-1]
        return (2, 100 + (int(num) if num.isdigit() else 0))
    if clip_id.startswith("emergency_") or clip_id.startswith("signs_"):
        num = clip_id.split("_", 1)[-1]
        return (3, int(num) if num.isdigit() else 0)
    if clip_id in ("emergency", "signs"):
        return (3, 0)
    if clip_id == "relief":
        return (2, 50)
    if clip_id in ("safe_cta", "cta"):
        return (4, 0)
    if clip_id.startswith("custom_"):
        num = clip_id.split("_", 1)[-1]
        return (3, 500 + (int(num) if num.isdigit() else 0))
    return (99, 0)


def is_emergency_clip_id(clip_id: str) -> bool:
    return bool(re.match(r"^(emergency|signs)(_\d+)?$", clip_id))


def is_explain_clip_id(clip_id: str) -> bool:
    return bool(re.match(r"^explain_\d+$", clip_id))
