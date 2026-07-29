"""Prompt templates loaded from config/video_prompts.json (editable in the UI)."""

from __future__ import annotations

from prompt_store import lang_str, require_dict, require_str


def script_rules(language: str) -> str:
    return lang_str("script_rules", language)


# Backward-compatible names used elsewhere — resolve at call time via properties below.
def _rules(lang: str) -> str:
    return script_rules(lang)


def clip_decision_prompt(cast_bible: str) -> str:
    return require_str("clip_decision_prompt").format(cast_bible=cast_bible)


def clip_detail_json_instruction(cast_bible: str) -> str:
    return require_str("clip_detail_json_instruction").format(cast_bible=cast_bible)


def script_verification_prompt() -> str:
    return require_str("script_verification_prompt")


def script_line_rewrite_prompt() -> str:
    return require_str("script_line_rewrite_prompt")


def visual_medical_review_prompt() -> str:
    return require_str("visual_medical_review_prompt")


def finished_video_medical_review_prompt() -> str:
    return require_str("finished_video_medical_review_prompt")


# Legacy module-level names: some scripts still import constants.
# These are functions disguised — use the getters above for new code.
# Keep attribute access working via __getattr__.


def __getattr__(name: str):
    mapping = {
        "SCRIPT_RULES": lambda: script_rules("en"),
        "SCRIPT_RULES_KO": lambda: script_rules("ko"),
        "SCRIPT_RULES_ES": lambda: script_rules("es"),
        "CLIP_DECISION_PROMPT": lambda: require_str("clip_decision_prompt"),
        "CLIP_DETAIL_JSON_INSTRUCTION": lambda: require_str("clip_detail_json_instruction"),
        "SCRIPT_VERIFICATION_PROMPT": script_verification_prompt,
        "SCRIPT_LINE_REWRITE_PROMPT": script_line_rewrite_prompt,
        "VISUAL_MEDICAL_REVIEW_PROMPT": visual_medical_review_prompt,
        "FINISHED_VIDEO_MEDICAL_REVIEW_PROMPT": finished_video_medical_review_prompt,
    }
    if name in mapping:
        return mapping[name]()
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
