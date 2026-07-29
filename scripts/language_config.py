"""Language settings for script generation and TTS — prompts from config/video_prompts.json."""

from __future__ import annotations

from dataclasses import dataclass

from prompt_store import lang_str, require_dict
from prompts import script_rules

SUPPORTED_LANGUAGES = frozenset({"en", "ko", "es"})


@dataclass(frozen=True)
class LanguageSettings:
    code: str
    label: str
    script_rules: str
    script_system: str
    tts_language_code: str
    tts_voice: str
    uses_syllable_pacing: bool


def normalize_language(code: str | None) -> str:
    if not code:
        return "en"
    key = code.strip().lower().replace("_", "-")
    if key in ("ko", "ko-kr", "kr"):
        return "ko"
    if key in ("es", "es-es", "es-us", "es-mx", "es-419", "spanish"):
        return "es"
    if key in ("en", "en-us", "en-gb"):
        return "en"
    if key in SUPPORTED_LANGUAGES:
        return key
    raise ValueError(f"Unsupported language {code!r}. Use: en, ko, es")


def get_language(code: str | None) -> LanguageSettings:
    lang = normalize_language(code)
    voices = require_dict("tts_voices")
    if lang not in voices or not isinstance(voices[lang], dict):
        raise ValueError(f"Missing tts_voices[{lang}] in video prompts config")
    voice_cfg = voices[lang]
    return LanguageSettings(
        code=lang,
        label=str(voice_cfg.get("label") or lang),
        script_rules=script_rules(lang),
        script_system=lang_str("script_system", lang),
        tts_language_code=str(voice_cfg.get("language_code") or ""),
        tts_voice=str(voice_cfg.get("voice") or ""),
        uses_syllable_pacing=bool(voice_cfg.get("uses_syllable_pacing", False)),
    )


# Lazy mapping for callers that still iterate LANGUAGES — built on access.
class _LanguagesProxy(dict):
    def __getitem__(self, key: str) -> LanguageSettings:
        return get_language(key)

    def items(self):
        for code in ("en", "ko", "es"):
            yield code, get_language(code)

    def keys(self):
        return ("en", "ko", "es")

    def values(self):
        for code in ("en", "ko", "es"):
            yield get_language(code)

    def __contains__(self, key: object) -> bool:
        return key in SUPPORTED_LANGUAGES

    def __iter__(self):
        return iter(("en", "ko", "es"))


LANGUAGES = _LanguagesProxy()
