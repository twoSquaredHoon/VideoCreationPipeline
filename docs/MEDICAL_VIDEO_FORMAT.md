# Medical video format (current)

Source of truth for production rules: `config/video_prompts.json`.

**Product goal:** medically accurate parenting videos only. Do not optimize for engagement, retention, comments, or dramatic openers.

## Spoken structure

Replaces `HOOK → BODY → RELIEF → CTA` with:

`CASE → WHAT_MATTERS → ACTION → EMERGENCY → SAFE_CTA`

| Section | Target | Role |
|---|---|---|
| CASE | 0–8s | Established facts only; calm and factual — not a scare opener |
| WHAT_MATTERS | 8–20s | One clinical question / one main message |
| ACTION | 20–32s | Recommended action early; dosing/home-care one line each |
| EMERGENCY | 32–42s | Separate doctor-today vs ER-now; one sign per line; never invent |
| SAFE_CTA | 42–45s | Medical close only (seek care / situation match) — no comments, tags, or share-bait |

## Pipeline

`Blog → case_sheet.txt → script.txt → clips → voiceover → Veo`

- Case sheet is extracted before the script (`scripts/blog_to_script.py`) and shown in Studio as **Article summary**.
- Global prompts: `config/video_prompts.json` (editable in Studio Prompts).
- Clip ids: `case` / `matters_*` / `action_*` / `explain_*` / `emergency_*` / `safe_cta` (legacy `hook`/`body_*`/`relief`/`cta`/`signs_*` still sort).
- Voiceover: calm clinical tone — not social-media or ad energy.

## Core rules

1. Medical accuracy is the only goal  
2. Never merge separate clinical facts or timelines  
3. Never simplify uncertainty  
4. Never turn one case into a universal threshold  
5. One video = one medical message  
6. No engagement CTAs, scare hooks, or invented urgency  
