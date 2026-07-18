# Future features (not implemented)

Notes for planned work. **Do not build until explicitly requested.**

---

## Finished-video folder + Gemini visual medical review

**Requested:** 2026-07-06  
**Implemented:** 2026-07-07

### What shipped

- **Inbox:** `output/end-products/inbox/` — drop `.mp4` or `.mov`
- **Drag** → import + run one medical review immediately
- **Review all in inbox** button for batch
- **Passed archive:** `output/end-products/passed/YYYY-MM-DD/` when verdict is pass
- Sidecar files: `{name}.meta.json`, `{name}.review.json`, `{name}.review.txt`
- Optional project link for script context (`Link project…`)
- Python: `scripts/review_end_product.py` + `./review-finished-video.sh`

### Original goal (reference)

Add a **new pipeline step after the video is finished** — a Gemini-based **visual medical review** of the completed clips/videos, in addition to the existing text/article checks.

### Workflow (concept)

1. User finishes a video (Veo clips generated, project at Ready or equivalent).
2. User places finished output in a **designated folder** inside the program (location TBD — e.g. per-project `finished/` or a global inbox under `output/`).
3. App sends the **video(s) + full pipeline context** to Gemini (chat / multimodal API):
   - Script, article check results, clip prompts, blog URL, voiceover metadata, etc. — everything already produced in the pipeline.
   - **Plus** the actual video files for **visual** review.

### What the review should check (examples)

- Correct **method for giving medicine** (technique, dosing context visible in scene).
- Appropriate **clothing / PPE / setting** for the medical situation depicted.
- Visual consistency with script and source article.
- Other medically relevant visual errors (unsafe demonstrations, wrong props, misleading imagery).

Output: structured review (pass/fail, issues list, timestamps or clip IDs) stored on the project and visible in Modoc Studio (similar to article check / Stats pass-fail patterns).

### Open design questions

- Folder UX: drag-and-drop vs auto-detect when all clips in `videos/` are marked final.
- One review per clip vs one review per full video / project.
- Model: Gemini multimodal (video input limits, cost, batch vs interactive chat UI).
- Whether review blocks “publish ready” or is advisory only.
- KO / ES: same visual checks with language-appropriate prompts.

### Related existing pieces

- `compare_script_to_article.py` — text/article check (already in pipeline).
- Stats **Completed Articles** pass/fail + notes — possible UX pattern for review outcomes.
- KPI denominator already includes **medical review** time ([REQUIREMENTS.md](./REQUIREMENTS.md)).

---

*Add new future items below as needed.*
