"""Load video-creation prompts from config/video_prompts.json (edited in the UI)."""

from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path
from typing import Any

_REPO_ROOT = Path(__file__).resolve().parent.parent
_DEFAULT_PATH = _REPO_ROOT / "config" / "video_prompts.json"


class PromptConfigError(RuntimeError):
    """Missing or invalid video prompts config."""


def prompts_path() -> Path:
    return _DEFAULT_PATH


def clear_prompt_cache() -> None:
    load_prompts.cache_clear()


@lru_cache(maxsize=1)
def load_prompts() -> dict[str, Any]:
    path = prompts_path()
    if not path.is_file():
        raise PromptConfigError(
            f"Missing video prompts config at {path}. "
            "Open Modoc Studio → Prompts and save the prompts file."
        )
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise PromptConfigError(f"Invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise PromptConfigError(f"Expected a JSON object in {path}")
    return data


def require(key: str) -> Any:
    data = load_prompts()
    if key not in data:
        raise PromptConfigError(
            f"Missing key {key!r} in {prompts_path()}. Edit it in Modoc Studio → Prompts."
        )
    return data[key]


def require_str(key: str) -> str:
    value = require(key)
    if not isinstance(value, str) or not value.strip():
        raise PromptConfigError(
            f"Key {key!r} in {prompts_path()} must be a non-empty string."
        )
    return value


def require_dict(key: str) -> dict[str, Any]:
    value = require(key)
    if not isinstance(value, dict):
        raise PromptConfigError(f"Key {key!r} in {prompts_path()} must be an object.")
    return value


def lang_str(section: str, language: str) -> str:
    mapping = require_dict(section)
    if language not in mapping:
        raise PromptConfigError(
            f"Missing {section!r}[{language!r}] in {prompts_path()}."
        )
    value = mapping[language]
    if not isinstance(value, str) or not value.strip():
        raise PromptConfigError(
            f"{section!r}[{language!r}] in {prompts_path()} must be a non-empty string."
        )
    return value
