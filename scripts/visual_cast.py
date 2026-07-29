"""Locked visual cast for consistent clip characters per target market."""

from __future__ import annotations

import re
from dataclasses import dataclass

from language_config import normalize_language
from prompt_store import require_dict, require_str


def _cast_templates() -> dict[str, dict[str, str]]:
    raw = require_dict("visual_cast")
    out: dict[str, dict[str, str]] = {}
    for lang, template in raw.items():
        if not isinstance(template, dict):
            raise ValueError(f"visual_cast[{lang}] must be an object in video prompts config")
        out[lang] = {str(k): str(v) for k, v in template.items()}
    return out


@dataclass(frozen=True)
class ChildAgeProfile:
    """Resolved child age from script/blog — drives infant vs school-age visuals."""

    label: str
    category: str  # infant | toddler | preschool | school_age
    months: int | None = None
    years: int | None = None

    @property
    def is_infant(self) -> bool:
        return self.category == "infant"

    @property
    def is_toddler(self) -> bool:
        return self.category == "toddler"


@dataclass(frozen=True)
class VisualCast:
    language: str
    market: str
    age: ChildAgeProfile
    child: str
    parent: str
    parent_secondary: str
    setting: str
    consistency_rules: str

    @property
    def child_age(self) -> str:
        return self.age.label

    def format_bible(self) -> str:
        age_rules = format_age_rules(self.age)
        return require_str("cast_bible_template").format(
            market=self.market,
            age_rules=age_rules,
            child=self.child,
            parent=self.parent,
            parent_secondary=self.parent_secondary,
            setting=self.setting,
            consistency_rules=self.consistency_rules,
        )


def format_age_rules(age: ChildAgeProfile) -> str:
    """Shared age mandate injected into cast bible and clip prompts."""
    lines = [
        "MANDATORY CHILD AGE (from blog/script — overrides any model default):",
        f"- Exact age for every clip: {age.label}",
        f"- Developmental category: {age.category.replace('_', ' ')}",
    ]
    if age.is_infant:
        lines.extend(
            [
                "- MUST depict an INFANT BABY (0–12 months), NOT a toddler, preschooler, or school-age child.",
                "- Infant body: large head, chubby cheeks, short limbs, cannot walk or stand unsupported.",
                "- Typical settings: crib, changing table, parent holding baby in arms, nursing chair.",
                "- FORBIDDEN: school desks, running, walking independently, school-age proportions.",
            ]
        )
    elif age.is_toddler:
        lines.extend(
            [
                "- MUST depict a toddler (1–3 years), NOT an infant or school-age child.",
                "- May walk unsteadily; clearly smaller than a school-age child.",
            ]
        )
    elif age.category == "preschool":
        lines.extend(
            [
                "- MUST depict a preschool-age child (3–5 years), NOT an infant or older school child.",
            ]
        )
    else:
        lines.extend(
            [
                "- MUST depict a school-age child (typically 5–12 years), NOT an infant or toddler.",
            ]
        )
    lines.append(
        "- Every veo_prompt and SUBJECT line must state this exact age in the first sentence."
    )
    return "\n".join(lines)


def _category_from_months(months: int) -> str:
    if months < 12:
        return "infant"
    if months < 36:
        return "toddler"
    if months < 72:
        return "preschool"
    return "school_age"


def _category_from_years(years: int) -> str:
    if years < 1:
        return "infant"
    if years <= 3:
        return "toddler"
    if years <= 5:
        return "preschool"
    return "school_age"


def extract_child_age_profile(text: str) -> ChildAgeProfile:
    """
    Parse child age from script, headers, and blog URL.
    Month patterns are checked BEFORE year patterns (7-month vs 7-year).
    """
    month_patterns = [
        r"(\d+)\s*[\-]?\s*month[\s-]*old",
        r"(\d+)\s*[\-]?\s*months?\s*old",
        r"(\d+)\s*[\-]?\s*mo\b",
        r"(\d+)\s*month[\s-]old\s*baby",
        r"(\d+)\s*mes(?:es)?\s*(?:de\s+edad|old)?",
        r"(\d+)\s*개월",
        r"baby\s*(?:is\s*)?(\d+)\s*months?",
        r"(\d+)\s*month[\s-]old",
    ]
    for pattern in month_patterns:
        match = re.search(pattern, text, re.I)
        if match:
            months = int(match.group(1))
            category = _category_from_months(months)
            noun = "infant baby" if category == "infant" else "child"
            return ChildAgeProfile(
                label=f"{months}-month-old {noun}",
                category=category,
                months=months,
            )

    year_patterns = [
        r"(\d+)\s*[\-]?\s*(?:year|yr)s?\s*old",
        r"(\d+)\s*(?:세|살)\b",
        r"(\d+)\s*años",
        r"(\d+)\s*year[\s-]old\s*child",
    ]
    for pattern in year_patterns:
        match = re.search(pattern, text, re.I)
        if match:
            years = int(match.group(1))
            category = _category_from_years(years)
            return ChildAgeProfile(
                label=f"{years}-year-old child",
                category=category,
                years=years,
            )

    if re.search(r"\bnewborn\b", text, re.I):
        return ChildAgeProfile("newborn infant under 1 month old", "infant", months=0)
    if re.search(r"\b(?:infant|baby)\b", text, re.I):
        return ChildAgeProfile(
            "infant baby under 12 months old",
            "infant",
            months=6,
        )

    return ChildAgeProfile("7-year-old school-age child", "school_age", years=7)


def extract_child_age(script: str) -> str:
    return extract_child_age_profile(script).label


def _build_child_description(profile: ChildAgeProfile, lang: str) -> str:
    template = _cast_templates()[lang]
    features = template["child_features"]

    if profile.is_infant:
        clothing = template["infant_clothing"]
        return (
            f"A {profile.label}. CRITICAL: this is an INFANT BABY (not a toddler or "
            f"school-age child). Infant proportions — large head, chubby cheeks, sparse fine "
            f"hair, cannot walk or stand. {features}. Wearing {clothing}. "
            f"Often shown in crib, on changing table, or held in parent's arms."
        )
    if profile.is_toddler:
        clothing = template["toddler_clothing"]
        return (
            f"A {profile.label}. Toddler proportions — shorter than school-age, may walk "
            f"unsteadily. {features}. Wearing {clothing}."
        )
    if profile.category == "preschool":
        clothing = template["preschool_clothing"]
        return (
            f"A {profile.label}. Preschool-age child. {features}. Wearing {clothing}."
        )
    clothing = template["school_clothing"]
    return (
        f"A {profile.label}. School-age child. {features}. Wearing {clothing}."
    )


def _setting_for_age(profile: ChildAgeProfile, lang: str) -> str:
    base = _cast_templates()[lang]["setting"]
    if profile.is_infant:
        return (
            f"{base} For this infant: nursery with crib, changing table, soft blankets, "
            f"or parent holding baby — never a school classroom or playground for older kids."
        )
    return base


def _consistency_for_age(profile: ChildAgeProfile, lang: str) -> str:
    base = _cast_templates()[lang]["consistency"]
    age_line = (
        f"- AGE IS MANDATORY: every clip must show {profile.label} — same developmental "
        f"stage ({profile.category.replace('_', ' ')}) in every shot. Never age-up or age-down.\n"
    )
    return age_line + base


def get_visual_cast(language: str | None, script: str) -> VisualCast:
    lang = normalize_language(language)
    template = _cast_templates()[lang]
    age = extract_child_age_profile(script)
    child = _build_child_description(age, lang)
    return VisualCast(
        language=lang,
        market=template["market"],
        age=age,
        child=child,
        parent=template["parent"],
        parent_secondary=template["parent_secondary"],
        setting=_setting_for_age(age, lang),
        consistency_rules=_consistency_for_age(age, lang),
    )


def language_from_script_header(text: str) -> str | None:
    for line in text.splitlines()[:25]:
        stripped = line.strip()
        if stripped.lower().startswith("# language:"):
            try:
                return normalize_language(stripped.split(":", 1)[1].strip())
            except ValueError:
                return None
    return None
