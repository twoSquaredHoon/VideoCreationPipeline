# Modoc AI 숏폼 육아 영상 스크립트 생성 프롬프트 (v2)

## 왜 바뀌었나 (요약)
이전 사고 원인은 크게 두 가지였음.
1. 블로그가 "특정 사례에 대한 1:1 답변"인데, 프롬프트가 이를 무조건 "일반 대중 대상 위험신호 체크리스트" 포맷(HOOK-BODY-SIGNS-RELIEF)에 끼워 넣도록 강제해서, 그 사례에만 해당하는 수치(7일, 24시간 등)가 마치 모든 아이에게 적용되는 일반 기준처럼 둔갑함.
2. 블로그 자체에 있던 부정확/맥락의존적 서술(동시 투여 표현, 검사 요구, 곁가지로 언급된 약 성분)을 검증 없이 그대로 스크립트에 옮김.
→ 해결책: 스크립트를 바로 쓰지 않고, **STEP 0(블로그 분석)** 을 먼저 강제해서 "이 블로그를 이해했는지"를 구조화된 형태로 먼저 확인받고, 그 결과만 STEP 1(스크립트 작성)의 재료로 쓰게 함.

---

## STEP 0 — BLOG COMPREHENSION & FACT AUDIT (스크립트 작성 전 필수, 별도 출력)

이 단계의 결과물은 사람이 먼저 검토할 수 있어야 함. 이 단계를 건너뛰고 바로 스크립트를 쓰지 말 것.

다음 항목을 블로그 원문 기준으로 채울 것. 모르면 추측하지 말고 "명시 안 됨"이라고 쓸 것.

1. **콘텐츠 유형**
   - [ ] 일반 교육형 글 (해당 연령대 아이 전체에 적용 가능한 일반 정보)
   - [ ] 개별 사례 Q&A (특정 아이의 특정 상황에 대한 1:1 답변)
   - 판단 근거 한 줄로 적기.

2. **명시된 나이/연령대**: (블로그에 정확히 쓰인 숫자만. 예: "8세")

3. **일반화해도 되는 사실** — 블로그가 "누구에게나 적용된다"는 취지로 말한 내용만 여기 나열. 이것만 SIGNS/일반 안전 정보로 쓸 수 있음.

4. **이 사례에만 해당하는 사실** — "이미 7일째다", "이미 응급실에 다녀왔다", "이미 항생제를 먹고 있다" 같은, 이 환자의 타임라인/상황에 종속된 정보. 이런 것은 일반 시청자용 "위험 신호" 기준으로 절대 재서술하지 말 것. 서사(있었던 일)로만 언급하거나, 일반화가 안 되면 생략.

5. **애매하거나 조건부인 서술 플래그** — "의학적으로 가능하지만 일반적이진 않다", "제한적으로 사용된다" 처럼 헷갈리게 쓰인 문장 나열. 이런 문장은 스크립트에서 단정형으로 바꾸지 말 것. 확신도가 낮으면 생략을 우선 고려.

6. **곁가지로만 언급된 항목** — 본 주제(발열 관리)와 직접 관련 없는데 질문자가 이미 쓰고 있어서 언급된 약/성분/조치. (예: 기침약 성분) 이런 항목은 HOOK이나 헤드라인성 문장에 절대 쓰지 말 것. 쓰더라도 원래 맥락(왜 언급됐는지)을 잃지 않게 한 줄로만.

7. **진짜 응급 신호가 블로그에 있는가** — 있으면 나열. 없으면 "블로그에 없음 — 사람 검토 필요"라고만 쓰고, 임의로 만들어 넣지 말 것. (없다고 조용히 빼먹지도 말 것 — 사람이 결정하도록 플래그만 남김)

8. **불명확해서 스크립트에서 뺄 항목** — 목록으로.

---

## STEP 1 — SCRIPT GENERATION

You are writing a short-form parenting video script for Modoc AI.

**소스 제약**: STEP 0 결과물만 사실의 근거로 사용한다. STEP 0에서 "이 사례에만 해당"으로 분류된 내용을 일반 기준으로 재서술하지 않는다. STEP 0에서 "애매함"으로 플래그된 문장은 단정적 표현으로 쓰지 않는다.

RULE: BE MEDICALLY ACCURATE. Use ONLY facts marked as general/verified in STEP 0. Do not invent symptoms, causes, treatments, statistics, or thresholds not explicitly stated as general in the blog. If STEP 0 marks something as case-specific, ambiguous, or "블로그에 없음", omit it rather than guess or generalize.

**콘텐츠 유형에 따라 구조를 다르게 쓴다**:
- STEP 0에서 "개별 사례 Q&A"로 분류된 경우: SIGNS 블록에는 STEP 0의 "일반화해도 되는 사실"에 있는 것만 넣는다. 만약 일반화 가능한 기준이 없다면 SIGNS 블록을 만들지 말고, 대신 "이런 상황이었습니다" 식 사례 서술 + "지속되거나 걱정되면 소아과 진료를 받으세요" 같은 비수치형 권고로 대체한다. 이 사례 하나의 타임라인(예: 7일, 24시간)을 마치 모든 아이에게 적용되는 임계값처럼 말하지 않는다.
- "일반 교육형 글"로 분류된 경우: 기존 구조(HOOK-BODY-SIGNS-RELIEF-CTA) 그대로 사용 가능.

LANGUAGE: Write the entire spoken script in natural Korean (한국어). Short spoken sentences. Parent-friendly tone — not stiff translationese. If the blog is in English, translate faithfully without adding medical claims.

SCRIPT RULES:
- No medical jargon parents won't understand. Short sentences only. Written to be SPOKEN out loud.
- Under 45 seconds total when read aloud in Korean.
- If the blog mentions a specific age or age group, every reference to a child in the script MUST reflect that age. If no age is mentioned, default to school-age children 5–12.
- CRITICAL FOR VIDEO: State the child's exact age (e.g. "7개월 아기") at least once in the BODY section. Under 12 months = "개월" — never describe an infant as a school-age child.
- **약/성분은 발열 관리와 직접 관련된 지침일 때만 BODY의 EXPLAIN 줄에 넣는다. STEP 0에서 "곁가지 언급"으로 분류된 약/성분은 HOOK이나 독립된 안전 단정 문장으로 쓰지 않는다.**
- **검사(혈액검사, X-ray 등)나 특정 조치를 "요청하세요/demand" 식으로 쓰지 않는다. "상담하세요/문의하세요" 같은 권유형으로 쓴다.** (검사 여부는 의료진이 진찰로 결정하는 것이지 시청자가 요구할 사항이 아님)
- 이 사례에서 나온 회복 지연 우려(항생제 반응 없음 등)를 다룰 때, 실제 응급 신호(STEP 0의 7번 항목)가 있으면 그것을 우선 전달하고, 없으면 "블로그에 없음"을 이유로 임의의 응급 신호를 만들어 넣지 않는다.

When writing each section keep the visuals in mind:

**HOOK (0–3 seconds):**
Start with an urgent, true statement grounded in what STEP 0 confirmed as general or as this specific case (clearly framed as such). Use urgent Korean phrasing like "지금 당장 확인하세요", "대부분의 부모는 이걸 모릅니다". **단, 이 사례 하나의 특수한 상황을 "모든 아이에게 해당되는 위험"처럼 일반화한 문구는 금지.** 곁가지 약 성분을 훅으로 쓰지 않는다.

**BODY (3–35 seconds):**
필수: 한 문장당 한 줄 — 긴 단락 금지.
순서:
  1) 상황 설명 (STEP 0의 사례/맥락 기준)
  2) EXPLAIN 줄 — 발열 관리와 직접 관련된 홈케어/복용 지침만, 한 줄에 하나 (위험 신호 블록 앞)
  3) (일반화 가능한 신호가 있을 때만) 위험 신호 도입 줄 + 콜론 (예: "다만, 이런 위험 신호가 보이면:")
  4) 위험 신호는 한 줄에 하나 — STEP 0에서 "일반화해도 되는 사실"로 분류된 것만

예시 BODY 형태 (블로그에 맞게 수정; 해당 없으면 생략):
```
7개월 아기 열이 반복되면 무섭습니다.
아기에게 가벼운 옷을 입히세요.
4시간마다 아세트아미노펜을 줄 수 있습니다.
다만, 이런 위험 신호가 보이면:
3일 넘게 열이 지속될 때.
숨쉬기가 어렵거나 호흡이 빠를 때.
평소 절반 이하로 수유할 때.
8시간 넘게 소변을 보지 않을 때.
```

**RELIEF (35–42 seconds):**
Give clear action steps supported by STEP 0. Do NOT say vague phrases like "그런 증상이 보이면" without naming the signs again. Briefly repeat the signs in short form, THEN say what to do — 단, "응급실행" vs "오늘 안에 진료"의 기준이 블로그에 명시되어 있을 때만 그 기준을 말한다. 명시되어 있지 않으면 "걱정되면 바로 병원에 가서 확인받으세요" 같은 비수치형 권고로 마무리한다.

**CTA (last 3 seconds):**
End with a comment-bait question in Korean like "우리 아이도 이런 적 있나요? 댓글로 알려주세요" or "꼭 봐야 할 부모님 태그해 주세요".

OUTPUT FORMAT (use these exact section labels in English):
```
STEP0_AUDIT:
[completed checklist from STEP 0]

HOOK:
[spoken lines in Korean]
BODY:
[spoken lines in Korean, one sentence per line]
RELIEF:
[spoken lines in Korean]
CTA:
[spoken lines in Korean]
```
