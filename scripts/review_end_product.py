#!/usr/bin/env python3
"""Gemini visual medical review for end-product videos (inbox / passed archive)."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from google.genai import types

from gemini_util import PROJECT_ROOT, get_client
from language_config import normalize_language
from prompts import FINISHED_VIDEO_MEDICAL_REVIEW_PROMPT
from prompt_store import require_str
from script_to_clips import extract_response_text

DEFAULT_MODEL = "gemini-2.5-flash"
MIN_VIDEO_BYTES = 1000
VIDEO_EXTENSIONS = {".mp4", ".mov"}


def parse_review_json(raw: str) -> dict:
    text = raw.strip()
    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)
    data = json.loads(text)
    if data.get("verdict") not in ("pass", "review", "fail"):
        raise ValueError("JSON must include verdict: pass, review, or fail")
    return data


def video_is_ready(path: Path) -> bool:
    return (
        path.is_file()
        and path.suffix.lower() in VIDEO_EXTENSIONS
        and path.stat().st_size >= MIN_VIDEO_BYTES
    )


def review_paths_for(video_path: Path) -> tuple[Path, Path]:
    stem = video_path.with_suffix("")
    return stem.with_suffix(".review.json"), stem.with_suffix(".review.txt")


def meta_path_for(video_path: Path) -> Path:
    return video_path.with_suffix(".meta.json")


def load_meta(video_path: Path) -> dict:
    path = meta_path_for(video_path)
    if not path.is_file():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}


def load_optional_text(path: Path, max_chars: int = 16000) -> str:
    if not path.is_file():
        return ""
    text = path.read_text(encoding="utf-8").strip()
    if len(text) > max_chars:
        return text[:max_chars] + "\n…[truncated]"
    return text


def load_clips_summary(project_dir: Path | None) -> str:
    if project_dir is None:
        return ""
    clips_path = project_dir / "clips.json"
    if not clips_path.is_file():
        return ""
    try:
        data = json.loads(clips_path.read_text(encoding="utf-8"))
        clips = data.get("clips") or []
        lines = []
        for clip in clips:
            cid = clip.get("id", "")
            label = clip.get("label", "")
            line = clip.get("script_line") or ""
            lines.append(f"- {cid} ({label}): {line}")
        return "\n".join(lines)
    except json.JSONDecodeError:
        return ""


def load_project_context(project_dir: Path | None) -> tuple[str, str, str, str]:
    if project_dir is None or not project_dir.is_dir():
        return "", "en", "", ""
    manifest_path = project_dir / "project.json"
    blog_url = ""
    language = "en"
    if manifest_path.is_file():
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        blog_url = str(manifest.get("blog_url") or "")
        language = normalize_language(manifest.get("language"))
    script_text = load_optional_text(project_dir / "script.txt")
    clips_summary = load_clips_summary(project_dir)
    verification_excerpt = ""
    verification_path = project_dir / "script_verification.json"
    if verification_path.is_file():
        try:
            verification = json.loads(verification_path.read_text(encoding="utf-8"))
            verification_excerpt = json.dumps(
                {
                    "verdict": verification.get("verdict"),
                    "summary": verification.get("summary"),
                },
                ensure_ascii=False,
            )
        except json.JSONDecodeError:
            verification_excerpt = load_optional_text(verification_path, max_chars=4000)
    return blog_url, language, script_text, clips_summary + (
        f"\n\nARTICLE CHECK:\n{verification_excerpt}" if verification_excerpt else ""
    )


def upload_video_and_wait(client, video_path: Path):
    uploaded = client.files.upload(file=str(video_path))
    while uploaded.state and uploaded.state.name == "PROCESSING":
        print(f"  Waiting for video processing ({video_path.name})…")
        time.sleep(3)
        uploaded = client.files.get(name=uploaded.name)
    state = uploaded.state.name if uploaded.state else "UNKNOWN"
    if state != "ACTIVE":
        raise RuntimeError(f"Video upload not ready (state={state})")
    return uploaded


def build_review_prompt(
    *,
    blog_url: str,
    language: str,
    script_text: str,
    context_extra: str,
    video_name: str,
) -> str:
    return f"""{FINISHED_VIDEO_MEDICAL_REVIEW_PROMPT}

FINISHED VIDEO FILE: {video_name}
BLOG URL: {blog_url or "(none)"}
LANGUAGE: {language}

FULL SCRIPT:
---
{script_text or "(no linked project script)"}
---

PROJECT CONTEXT:
---
{context_extra or "(none)"}
---

Watch the attached finished video and return JSON only.
"""


def format_review_text(data: dict) -> str:
    """Plain-text document for pasting into email, Docs, Slack, etc."""
    verdict = str(data.get("verdict", "review")).upper()
    lines = [
        "MEDICAL VIDEO REVIEW",
        "====================",
        "",
        f"Verdict: {verdict}",
        f"Video: {data.get('video_path', '')}",
        f"Reviewed: {data.get('reviewed_at', '')}",
    ]
    if data.get("blog_url"):
        lines.append(f"Blog: {data.get('blog_url')}")
    if data.get("language"):
        lines.append(f"Language: {data.get('language')}")
    lines += ["", "SUMMARY", "-------", str(data.get("summary", "")), ""]

    issues = data.get("issues") or []
    if issues:
        lines += ["ISSUES", "------"]
        for item in issues:
            sev = item.get("severity", "?")
            cat = item.get("category", "other")
            hint = item.get("timestamp_hint")
            prefix = f"[{sev}] {cat}"
            if hint:
                prefix += f" @ {hint}"
            lines.append(f"• {prefix}")
            lines.append(f"  {item.get('note', '')}")
            lines.append("")
        lines.append("")

    strengths = data.get("strengths") or []
    if strengths:
        lines += ["STRENGTHS", "---------"]
        for item in strengths:
            lines.append(f"• {item}")
        lines.append("")

    fixes = data.get("recommended_fixes") or []
    if fixes:
        lines += ["RECOMMENDED FIXES", "------------------"]
        for item in fixes:
            lines.append(f"• {item}")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def resolve_project_dir(video_path: Path, explicit: Path | None) -> Path | None:
    if explicit is not None:
        path = explicit.expanduser().resolve()
        return path if path.is_dir() else None
    meta = load_meta(video_path)
    raw = meta.get("project_path") or meta.get("project_dir")
    if not raw:
        return None
    path = Path(str(raw)).expanduser().resolve()
    return path if path.is_dir() else None


def review_video_file(
    *,
    video_path: Path,
    project_dir: Path | None,
    model: str,
) -> dict:
    blog_url, language, script_text, context_extra = load_project_context(project_dir)

    client = get_client()
    print(f"Uploading {video_path.name} ({video_path.stat().st_size // 1024} KB)…")
    uploaded = upload_video_and_wait(client, video_path)

    user_text = build_review_prompt(
        blog_url=blog_url,
        language=language,
        script_text=script_text,
        context_extra=context_extra,
        video_name=video_path.name,
    )

    print(f"Running medical review with {model}…")
    response = client.models.generate_content(
        model=model,
        contents=[uploaded, user_text],
        config=types.GenerateContentConfig(
            temperature=0.2,
            system_instruction=require_str("finished_video_review_system"),
            response_mime_type="application/json",
        ),
    )
    raw = extract_response_text(response)
    if not raw:
        raise RuntimeError("Empty response from Gemini visual review")

    data = parse_review_json(raw)
    data["video_path"] = video_path.name
    data["reviewed_at"] = datetime.now(timezone.utc).isoformat(timespec="seconds")
    data["language"] = language
    data["blog_url"] = blog_url
    data["model"] = model
    if project_dir:
        data["project_path"] = str(project_dir)
    return data


def save_review(video_path: Path, data: dict) -> tuple[Path, Path]:
    json_path, txt_path = review_paths_for(video_path)
    json_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    txt_path.write_text(format_review_text(data), encoding="utf-8")
    return json_path, txt_path


def today_folder() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def archive_passed(video_path: Path, passed_root: Path) -> Path:
    dest_dir = passed_root / today_folder()
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest_video = dest_dir / video_path.name
    if dest_video.exists():
        stamp = datetime.now(timezone.utc).strftime("%H%M%S")
        dest_video = dest_dir / f"{video_path.stem}-{stamp}{video_path.suffix}"

    shutil.move(str(video_path), str(dest_video))
    for extra in (meta_path_for(video_path), *review_paths_for(video_path)):
        if extra.is_file():
            shutil.move(str(extra), str(dest_dir / extra.name))
    print(f"  Archived (passed) → {dest_video}")
    return dest_video


def list_inbox_videos(inbox_dir: Path) -> list[Path]:
    if not inbox_dir.is_dir():
        return []
    return sorted(
        [p for p in inbox_dir.iterdir() if video_is_ready(p)],
        key=lambda p: p.stat().st_mtime,
    )


def review_one(
    video_path: Path,
    *,
    project_dir: Path | None,
    model: str,
    passed_root: Path | None,
    archive_passed_flag: bool,
) -> dict:
    video_path = video_path.expanduser().resolve()
    if not video_is_ready(video_path):
        raise FileNotFoundError(f"Video not ready: {video_path}")

    project_dir = project_dir or resolve_project_dir(video_path, None)
    print(f"\n=== Reviewing: {video_path.name} ===")
    if project_dir:
        print(f"  Linked project: {project_dir}")

    data = review_video_file(
        video_path=video_path,
        project_dir=project_dir,
        model=model,
    )
    json_path, txt_path = save_review(video_path, data)
    print(f"Verdict: {data['verdict'].upper()}")
    print(data.get("summary", ""))
    print(f"Saved → {json_path}")
    print(f"Saved → {txt_path}")

    if archive_passed_flag and data.get("verdict") == "pass" and passed_root is not None:
        archive_passed(video_path, passed_root)

    return data


def main() -> None:
    parser = argparse.ArgumentParser(description="Medical review for end-product videos.")
    parser.add_argument("--video", type=Path, help="Single video file (.mp4 or .mov)")
    parser.add_argument(
        "--project-dir",
        type=Path,
        help="Optional project folder for script context",
    )
    parser.add_argument(
        "--inbox",
        type=Path,
        help="Review all videos in this inbox folder",
    )
    parser.add_argument(
        "--passed-root",
        type=Path,
        help="Root for passed archive (default: sibling passed/ of inbox)",
    )
    parser.add_argument(
        "--archive-passed",
        action="store_true",
        help="Move passed videos to passed/YYYY-MM-DD/",
    )
    parser.add_argument("--model", default=DEFAULT_MODEL)
    args = parser.parse_args()

    if not args.video and not args.inbox:
        default_inbox = PROJECT_ROOT / "output" / "end-products" / "inbox"
        parser.error("Specify --video PATH or --inbox DIR")
        return

    passed_root = args.passed_root
    if args.archive_passed and passed_root is None:
        if args.inbox:
            passed_root = args.inbox.expanduser().resolve().parent / "passed"
        elif args.video:
            passed_root = args.video.expanduser().resolve().parent.parent / "passed"

    failed = 0
    try:
        if args.inbox:
            inbox = args.inbox.expanduser().resolve()
            videos = list_inbox_videos(inbox)
            if not videos:
                print(f"No videos in inbox: {inbox}", file=sys.stderr)
                sys.exit(1)
            print(f"Reviewing {len(videos)} video(s) in {inbox}")
            for video in videos:
                try:
                    review_one(
                        video,
                        project_dir=None,
                        model=args.model,
                        passed_root=passed_root,
                        archive_passed_flag=args.archive_passed,
                    )
                except Exception as exc:
                    failed += 1
                    print(f"FAILED {video.name}: {exc}", file=sys.stderr)
        else:
            review_one(
                args.video,
                project_dir=args.project_dir,
                model=args.model,
                passed_root=passed_root,
                archive_passed_flag=args.archive_passed,
            )
    except Exception as exc:
        print(f"\nFAILED: {exc}", file=sys.stderr)
        sys.exit(1)

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
