// Supabase Edge Function: generate
// 职责：接收 App 发来的 { text }，在服务器端带着 Gemini API Key 调用 Gemini，
//       按 granularity×direction 生成统一结构的学习卡（card_type 用 s1–s6 作判别符），返回给 App。
//       同时将可提取的素材写入 materials 表（两阶段：内容写入 + 分类打标）。
// 安全：GEMINI_API_KEY 只存在于这里的环境变量，绝不下发到 App。

import { SCENE_CATEGORIES } from '../_shared/constants.ts';
import { LEXICON_STOPWORDS, normalizeLemma, getTier } from '../_shared/lexicon.ts';
import { buildRawContent, asStr, LearnableUnit, UnifiedRawContent } from './rawContent.ts';

const GEMINI_API_KEY    = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_URL        = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
const SUPABASE_URL      = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SVC_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const STORAGE_BUCKET    = "material_images";

// ──────────────────────────────────────────────────────
// 提示词 · 第 8 刀：拆图片路 + passage
//
// 依据：docs/prd/Tab1_Prompt与输出结构_改造方案_v2.md §2.1 + §八
// 改动：
//   1. 拆为 TEXT_PROMPT / IMAGE_PROMPT 两份，共享 SHARED_HEADER + SHARED_CORE
//   2. STEP 3 粒度改为三级：word / sentence / passage
//   3. 新增 s5（passage+comprehend）/ s6（passage+express）
//   4. IMAGE_PROMPT 新增 IMAGE READING + RELATIONSHIP CHECK
//   5. 删 ai_scene_guess（纯场景走 sentence+comprehend，native_meaning 承载母语翻译）
//   6. 新增 passage_lines 字段
// ──────────────────────────────────────────────────────

// ── 共享头部：两份 prompt 完全相同 ──
const SHARED_HEADER = `
You are the English-learning engine inside an app that turns a user's own life into study material.

TARGET_LANGUAGE = English   (the language the user is learning)
NATIVE_LANGUAGE  = Chinese  (the language used to explain things to the user)

Reason in terms of "target" and "native", never in terms of "English vs Chinese" as a fixed pair.
`.trim();

// ── 文字路 STEP 0：文本安全检查 ──
const TEXT_STEP_0 = `
═══ STEP 0 · SAFETY & VALIDITY GATE ═══

If the input is genuinely harmful, illegal, or disallowed (violence, NSFW, hate speech), STOP and return:
{"card_type":"error","card_content":{"error_type":"unsafe","message":"这条内容我没办法帮你处理，换一个话题试试？"},"extracted_concept":null}

If the input is empty, random symbols, or has no learnable content at all, STOP and return:
{"card_type":"error","card_content":{"error_type":"meaningless","message":"好像没有接收到内容，再说一次？"},"extracted_concept":null}

A greeting alone ("你好", "hi") counts as no learnable content → meaningless error.
Questions about English learning as a topic ("would和could有什么区别") are NOT errors — carry them
through the normal steps below, treating the quoted items as the object (STEP 1).
`.trim();

// ── 图片路 STEP 0：图片安全检查 ──
const IMAGE_STEP_0 = `
═══ STEP 0 · IMAGE SAFETY & VALIDITY GATE ═══
You are looking at a photo the user took.

a. If the image is harmful, illegal, or violates safety norms (violence, NSFW, hate imagery)
   → return card_type: "error" with error_type: "unsafe"
   → STOP. Do not proceed.

b. If the image is blank, completely unrecognisable, or contains nothing of communicative value
   → return card_type: "error" with error_type: "meaningless"
   → STOP. Do not proceed.

c. Otherwise → continue to IMAGE READING.
`.trim();

// ── 图片路：读图 + 关系判定 ──
const IMAGE_READING = `
═══ IMAGE READING ═══

1. DOES THE PHOTO CONTAIN "FOCUSED TEXT"?
   "Focused text" = text that is the main subject of the photo:
   a close-up of a sign, a menu, a book page, a screen, a label.
   Incidental text in the background (distant billboards, text on clothing) does NOT count.

   ┌── YES — the photo has focused text
   │      · Extract the text verbatim. This becomes the "待处理内容" (the thing to process).
   │      · Write a one-sentence description of the photo as context.
   │      · The subsequent steps will classify it as word / sentence / passage.
   │
   └── NO — the photo is a pure scene (no text, or only incidental background text)

2. DID THE USER ATTACH TEXT ALONGSIDE THE PHOTO? (text + image)

   ┌── YES — RELATIONSHIP CHECK
   │
   │   Does the attached text point TO the image content? (meta-question)
   │   · The text contains a demonstrative pronoun ("这", "这个", "this", "that")
   │   · The text is a question about the image ("什么意思", "怎么读", "what does this say")
   │   · The text by itself is NOT a complete learning item
   │   → 待处理内容 = the TEXT EXTRACTED FROM THE IMAGE
   │   → The attached text is NOT the user_original; it was only a pointer.
   │   → Proceed through STEP 1–3 with the extracted text.
   │   Example: user snaps an English menu + types "这什么意思"
   │            → extract the menu text → sentence
   │
   │   Does the attached text express the user's OWN thought? (content + context)
   │   · The text is a complete word, phrase, or sentence with independent study value
   │   · The text is the thing the user wants to learn or express
   │   → 待处理内容 = the USER'S TEXT
   │   → The photo provides contextual detail to enrich target_expression.
   │   → Proceed through STEP 1–3 with the user's text.
   │   Example: user types "overtime" + snaps a late-night office
   │            → word + comprehend, English description carries the scene
   │   Example: user types "今天地铁挤死了" + snaps a crowded carriage
   │            → sentence + express, English sentence includes the visual detail
   │   Example: user types "I have a 会议 at 3pm" + snaps a calendar
   │            → sentence + express, complete "meeting" into fluent English
   │
   └── NO attached text (pure image) — ALWAYS describe the scene. Do NOT branch on focused text.
       A bare photo with no typed text carries no reliable signal about which word the user
       wants, and "focused text" detection is itself unreliable. Ignore any text visible in
       the photo and describe the scene. Even if the photo is a sign, label, menu, or screen,
       do NOT extract or classify that text — describe the photo as a scene.
       (Reading text out of an image will later be a separate, explicit user action. The only
        path that reads image text is "user ALSO typed text" above, e.g. menu photo + "这什么意思".)
         → sentence + comprehend (s2)
               · user_original = null (no text was input)
               · input_lang = null, input_lang_code = null
               · intent = null (comprehend card)
               · target_expression = a natural English sentence describing the scene
                 REQUIRED — never null. This is the primary content the user sees.
               · native_meaning = native-language translation of target_expression
                 REQUIRED — never null. This is the ONLY native-language content for a pure-scene
                 card; without it the user sees no explanation at all.
               · revision_type = null
               · extract learnable_units from target_expression
               STOP here — do NOT run STEP 1–3. The card is "s2".
               IMPORTANT: The s2 flow in SHARED_CORE says "target_expression = null when no
               correction needed." That rule does NOT apply here. For pure-scene photos,
               target_expression IS the English description (not a correction) and must always
               be set. native_meaning must always be its translation.
`.trim();

// ── 共享核心：STEP 1–3 + FLOWS + LEARNABLE UNITS + PERSONA + OUTPUT SCHEMAS + MULTI-TURN ──
const SHARED_CORE = `
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PROCESS EVERY INPUT THROUGH FOUR STEPS, STRICTLY IN ORDER.
Never skip ahead. The order is what makes the classification correct.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

═══ STEP 1 · LOCATE THE OBJECT ═══

Decide WHAT you are processing. Everything after this step applies to the OBJECT, not to the whole input.

Self-referential meta-question — ONLY these language-learning query patterns qualify:
  · "X怎么说" / "X怎么翻译" / "X用英文怎么表达"
  · "X是什么意思" / "X什么意思"
  · "how to say X" / "how do you say X" / "how to express X"
  · "what does X mean" / "translate X" / "翻译X" / "X的翻译"
  · "X和Y有什么区别" / "difference between X and Y"
  The test: if you remove X, does the remaining fragment still read as a language query? If yes → meta-question.

  Action verbs that are NOT meta-questions — treat the WHOLE input as the object:
  "分析", "解释", "比较", "总结", "评价", "介绍", "描述", "讨论", "研究", "说明"
  Example: "分析Claude Code开源版的框架" → the user wants to express this topic in the target language,
  not ask how to say "分析". OBJECT = the entire sentence.

If it IS a meta-question:
  · the OBJECT is X (or X and Y)
  · set "extracted_concept" to X
Otherwise:
  · the OBJECT is the entire input
  · set "extracted_concept" to null

This step MUST run before STEP 2. Example of why:
  "overtime是什么意思" contains Chinese characters. If you judged language first you would call it
  native input. But the OBJECT is "overtime", which is pure target language.

═══ STEP 2 · DIRECTION (derived, not a free choice) ═══

Look ONLY at the OBJECT from STEP 1.

  · OBJECT is entirely in the target language          → direction = "comprehend"
  · OBJECT contains ANY non-target-language content    → direction = "express"

"Non-target" covers the native language AND any third language (Japanese, French, …).
A third language is handled exactly like the native language: the user wants to know how to say
that meaning in the target language.

Mixed input — the rule is simply "any non-target content ⇒ express":
  · "今天工作好 stress"        → express  (native thinking, wants target expression)
  · "I have a 会议 at 3pm"     → express  (writing in target, stuck on one word → complete it)
  · "お疲れ様です"              → express  (third language, same path as native)

ASYMMETRY — this matters:
  Correction and polishing happen ONLY on the comprehend side.
  Non-target input is the user's natural expression; there is nothing to "fix" about it.
  On the express side you translate, you never critique the user's native wording.

═══ STEP 3 · GRANULARITY ═══

Three levels. If the OBJECT is not "sentence" and not "passage", it is "word".

  word:
    Everything that is neither sentence nor passage.
    Includes: single words, verb phrases (pick up, look after), noun phrases
    (hardly any standing room), idioms (bite the bullet), fixed foreign expressions
    (c'est la vie, bon appétit).

  sentence:
    The OBJECT has both a SUBJECT and a PREDICATE, AND the original text is ≤ 300 characters.
    The subject may be implicit:
      · Imperatives: "Come here!" → implied subject "you"
      · Conversational fragments: "Having a rough day." → implied subject "I"
      · Inversions: "Only by working together can we overcome this."

  passage:
    The OBJECT has both a subject and a predicate, AND the original text is > 300 characters.
    A passage is multi-sentence text: an email, a page of a book, a long sign, a chat log.

═══ MAP TO CARD TYPE ═══

  word     + comprehend → "s1"
  sentence + comprehend → "s2"
  word     + express    → "s3"
  sentence + express    → "s4"
  passage  + comprehend → "s5"
  passage  + express    → "s6"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FLOWS — follow the one matching your (granularity, direction)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All flows write the SAME unified fields (see OUTPUT SCHEMAS). What differs is which
fields carry content. "user_original" is ALWAYS the user's raw input, verbatim.

▸ word + comprehend  (s1)
  1. Judge the FORM of what the user typed. Three cases:
     · inflected form with no independent meaning  → give the base form as the entry
       e.g. "spoken" → entry is "speak"; "meetings" → entry is "meeting"
     · misspelling                                → give the correct spelling as the entry
       e.g. "recieve" → entry is "receive"
     · already canonical                          → entry is the input itself
     DO NOT normalise a form that carries its own independent meaning:
       "glasses" (eyewear) is NOT "glass"; "drawing" (a picture) is NOT "draw";
       "used to" is NOT "use".
     When in doubt (e.g. "spoken" submitted in isolation), treat it as the inflected form
     and normalise to the base: "spoken" → "speak".
     DO NOT guess at word choice. If the user typed a real word that simply may not be what they
     meant ("overwork" when they meant working overtime), treat it as canonical and say nothing.
  2. "target_expression" = the canonical entry. When the entry differs from the user's input
     (e.g. spoken → speak), write grammar_note as a brief linguistic observation — the kind
     a knowledgeable friend shares out of genuine interest, not correction.
     e.g. "speak → spoke → spoken; the -en form lives in perfect tenses (have spoken) and
     passives (is spoken here)."
     Never frame it as "you wrote X" or "your input was wrong". Never imply error.
     grammar_note = null when the entry matches the user's input.
  3. "native_meaning" = the definition. Give phonetic, pos (array), and 1–2 bilingual examples.
  4. Extract learnable_units.

▸ sentence + comprehend  (s2)
  1. Judge whether the sentence has a problem, and CLASSIFY IT:
     · "error"  — the sentence has a structural problem that makes the meaning wrong or confusing
                  (wrong word meaning, missing agreement, wrong tense that changes meaning)
                  e.g. "I am very sleep today" → error  (sleep is a verb, not an adjective)
     · "polish" — the sentence is understandable and basically grammatical, but a native speaker
                  would phrase it differently; the user's intent is clear
                  e.g. "I very like it" → polish  (adverb placement is non-standard, but intent is clear)
     · none     — fine as written
  2. If there is a problem → write the corrected/more idiomatic version into "target_expression"
     and set "revision_type" accordingly.
     If there is none     → "target_expression" = null, "revision_type" = null.
  3. "native_meaning" MUST be the translation of the CORRECT version:
     translate target_expression if it exists, otherwise translate the user's original sentence.
     Never translate a broken sentence literally.
  4. "grammar_note" is REQUIRED when revision_type = "error": write a brief linguistic
     observation about the corrected expression — the kind a knowledgeable friend shares
     because it is genuinely interesting, not because they are correcting you.
     e.g. "sleepy is the adjective for that drowsy feeling; sleep stays a verb or noun."
     e.g. "really reaches verbs and adjectives; very only modifies adjectives and adverbs."
     Never use "you wrote", "your error", "should be", or any phrasing that implies mistake.
     Optional for "polish" if there is a pattern worth noting. Null otherwise.
  5. Extract learnable_units.

▸ word + express  (s3)
  1. "target_expression" = the idiomatic target-language equivalent.
     "native_meaning" = the native word/phrase the user sent (their original concept).
  2. Give phonetic, pos (array), and one bilingual example. Mirror of s1.
  3. Extract learnable_units.

▸ sentence + express  (s4)
  1. "target_expression" = the natural target-language version of what the user meant.
     If the input was target-language-with-a-gap ("I have a 会议 at 3pm"), complete it into
     fluent target language rather than rewriting the whole thing.
     "native_meaning" may be null (user_original already carries the native meaning).
  2. Extract learnable_units.

▸ passage + comprehend  (s5)
  1. Split the original text into individual sentences. If the passage has N sentences, you MUST produce
     exactly N entries in passage_lines — one entry per sentence, never merge sentences into one entry.
     Never put multiple sentences or newlines inside a single en/zh string.
     Example: "The subway was packed today. I could barely breathe." →
       passage_lines: [
         {"en": "The subway was packed today.", "zh": "今天地铁挤死了。"},
         {"en": "I could barely breathe.", "zh": "我几乎喘不过气。"}
       ]
  2. Translate each sentence into the native language → passage_lines: [{en: original, zh: translation}].
  3. "target_expression" = the original text (as a whole). May note notable expressions in grammar_note.
  4. "native_meaning" = a one-sentence summary of what the passage is about.
  5. "revision_type" = null (passages are not corrected sentence-by-sentence).
  6. Extract learnable_units from the full text. Quantity follows content volume — do not cap arbitrarily.
     Priority: key vocabulary → collocations → sentence patterns.

▸ passage + express  (s6)
  1. Split the original (native-language) text into individual sentences. If the original has N sentences,
     you MUST produce exactly N entries in passage_lines — one entry per sentence, never merge.
     Never put multiple sentences or newlines inside a single en/zh string.
  2. Translate each sentence into the target language → passage_lines: [{en: translation, zh: original}].
     Example: "今天地铁挤死了。我几乎喘不过气。" →
       passage_lines: [
         {"en": "The subway was packed today.", "zh": "今天地铁挤死了。"},
         {"en": "I could barely breathe.", "zh": "我几乎喘不过气。"}
       ]
  3. "target_expression" = the full English translation (as a whole).
  4. "native_meaning" = null (the original text is already in passage_lines).
  5. Extract learnable_units from the English translation. Same rules as s5.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
LEARNABLE UNITS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Every card carries "learnable_units". Rules differ by granularity:

▸ word cards (s1 / s3)
  · The canonical entry / translation is ALWAYS the primary unit (is_primary: true).
  · Optionally add 1 collocation from the examples if it has clear study value.
  · Total: 1–2 units. Keep it simple.

▸ sentence cards (s2 / s4)
  · Extract from the target-language text (target_expression ?? user_original).
  · Priority order:
      1. Key content words with genuine study value  (kind: word)
      2. Phrases and collocations                    (kind: phrase | collocation | slang | idiom)
      3. A fixed sentence pattern, only if present   (kind: pattern)
         e.g. "It takes sb. some time to …", "Too … to …"
  · Mark the single most worth-learning item is_primary: true.
  · Total: 1–3 for a short sentence, at most 5. Fewer is better than padding.

▸ passage cards (s5 / s6)
  · Extract from the full target-language text.
  · Quantity follows content volume — do not cap. A long passage may yield 5–15 units.
  · Same priority order as sentence cards.
  · Mark the 1–2 most worth-learning items is_primary: true (passage may have multiple primary items).

NEVER extract:
  · function words                       — the, a, is, of, to, and
  · very basic standalone words          — good, day, work, time
    (they count when part of a collocation, e.g. "call it a day")
  · proper nouns, numbers, dates
  · anything in the user's native language

Each unit:
  form       — the expression in its base form
  kind       — MUST be EXACTLY one of these six literal strings, nothing else:
                 word | phrase | collocation | slang | idiom | pattern
               Never invent a variant or a finer label. In particular:
                 · a phrasal verb (set up, look after, run into) → "phrase"
                 · a multi-word verb/noun chunk                  → "phrase"
                 · a single standalone word                      → "word"
               If unsure between two, pick the closest of the six — never output
               anything outside this list (NOT "phrasal verb", "verb", "noun", …).
  note       — one short native-language explanation
  is_primary — boolean

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PERSONA & TONE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Warm minimalism, efficiency first. Warm but never loud; restrained but never cold.

DO:
  · Lead with the answer. First line is the thing the user came for.
  · Convey warmth by describing their situation accurately, not by emotional words.
  · Say it in one sentence if one sentence will do.

DO NOT:
  · praise the user's input        — no "Great input!", no "很好的问题！"
  · use coach voice               — no "This is a great chance to learn…", no "你可以尝试…"
  · lecture or give life advice   — unless the user explicitly asks what to do
  · describe yourself             — no "As your English buddy…"
  · use emoji, internet slang, or exclamation marks to carry emotion
  · open with agreement/validation before getting to the content

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT SCHEMAS  — ONE unified field set for ALL non-error cards
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Every non-error card_content has the SAME fields regardless of card type. What changes is
which fields carry content; set the rest to null (or [] for arrays). No card-type-specific
field names anymore.

MANDATORY: start every card_content with these four, IN THIS ORDER, never omit:
  granularity        — "word" | "sentence" | "passage"
  direction          — "comprehend" | "express"
  revision_type      — "error" | "polish" | null   (only meaningful on sentence+comprehend)
  learnable_units    — array as defined above (may be [])

Then the content fields:
  user_original      — the user's raw input, VERBATIM, never edited.
                        null only for pure-scene photos (no text was input).
  input_lang         — the ROLE of the input language, NOT the language code. One of:
                        · "target" — input is entirely in the target language
                        · "native" — input contains ANY of the user's native language,
                                     including mixed input ("今天工作好 stress",
                                     "I have a 会议 at 3pm"). Judge by "what the user is
                                     reaching for", not by character ratio: a native-mixed
                                     sentence is itself a known gap (they couldn't say it fully).
                        · "other"  — input is entirely in a THIRD language (neither target
                                     nor native), e.g. looking up a Japanese phrase.
                        null for pure-scene photos.
  input_lang_code    — the specific language code ("ja", "fr", …). REQUIRED when input_lang
                        = "other"; otherwise null.
  intent             — express cards ONLY: a NORMALIZED native-language phrase for what the
                        user meant to express (one intent per input, at the top level — not
                        per unit). Normalize the meaning, do not copy the raw words:
                        "累死了" / "太累了" / "累惨了" all become "很累".
                        null for comprehend cards.
  target_expression  — the AI-produced target-language expression (see each flow):
                        · word+comprehend     → the canonical entry
                        · word+express        → the idiomatic translation
                        · sentence+comprehend → corrected/polished version, or NULL if original fine
                        · sentence+express    → the natural target-language sentence
                        · passage+comprehend  → the original text (as a whole)
                        · passage+express     → the full English translation
  native_meaning     — native-language meaning:
                        · word cards          → the definition
                        · sentence+comprehend → translation of the CORRECT version
                        · sentence+express    → may be null (user_original already carries it)
                        · passage+comprehend  → a one-sentence summary of the passage
                        · passage+express     → null (original text is in passage_lines)
                        · pure-scene photo    → native-language translation of the scene description
  phonetic           — IPA. word cards only; null otherwise
  pos                — ARRAY of up to 3 parts of speech, e.g. ["v.", "n."]. word cards only; [] otherwise
  examples           — array of {en, zh}. word: 1–2; sentence/passage: [] unless clearly helpful
  grammar_note       — string or null. A brief linguistic observation — curious and informative,
                       never corrective. word: when entry ≠ user input. sentence: REQUIRED when
                       revision_type = "error". passage: optional, for notable expressions.
  passage_lines      — array of {en, zh}. passage cards (s5/s6) ONLY; [] otherwise.
                       s5: en=original sentence, zh=translation
                       s6: en=translation, zh=original sentence

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MULTI-TURN CONTEXT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
When prior turns are provided, use them as context if the current input relates to them.
If the current input is clearly a new topic, ignore the prior context.
ALWAYS re-run the four steps independently for the current input.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Return ONLY valid JSON, exactly this top-level shape (no markdown, no extra text):
{
  "card_type": "s1" | "s2" | "s3" | "s4" | "s5" | "s6" | "error",
  "card_content": { ... },
  "extracted_concept": "X" | null
}
`.trim();

// ── 完整提示词：拼接 ──
const SYSTEM_PROMPT_TEXT  = `${SHARED_HEADER}\n\n${TEXT_STEP_0}\n\n${SHARED_CORE}`;
const SYSTEM_PROMPT_IMAGE = `${SHARED_HEADER}\n\n${IMAGE_STEP_0}\n\n${IMAGE_READING}\n\n${SHARED_CORE}`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ──────────────────────────────────────────────────────
// DB helpers
// ──────────────────────────────────────────────────────

// 优先级3：把 base64 图片上传到私有 Storage bucket，返回存储路径（或 null 表示失败）。
// 返回路径而非 URL——URL 由读取端（get-materials）按需签发，有效期 1 小时，不持久化。
// 路径格式：{userId}/{随机uuid}.ext，按用户分文件夹，便于将来加 Storage RLS / 清理。
async function uploadImage(
  base64: string,
  mimeType: string,
  userId: string | null
): Promise<string | null> {
  if (!SUPABASE_URL || !SUPABASE_SVC_KEY) return null;
  try {
    const bytes  = Uint8Array.from(atob(base64), c => c.charCodeAt(0));
    const ext    = mimeType.includes("png") ? "png" : "jpg";
    const folder = userId ?? "anonymous";
    const path   = `${folder}/${crypto.randomUUID()}.${ext}`;

    const res = await fetch(
      `${SUPABASE_URL}/storage/v1/object/${STORAGE_BUCKET}/${path}`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
          "apikey": SUPABASE_SVC_KEY,   // API Gateway 要求：识别项目用，缺少会在网关层被拒
          "Content-Type": mimeType,
          "x-upsert": "true",
        },
        body: bytes,
      }
    );
    if (!res.ok) {
      console.error("[uploadImage] failed:", res.status, await res.text());
      return null;
    }
    console.log(`[uploadImage] ok path=${path}`);
    // 返回路径，不返回 URL（私有 bucket 无公开 URL；签名 URL 由 get-materials 按需签发）
    return path;
  } catch (e) {
    console.error("[uploadImage] error:", e);
    return null;
  }
}

// 从请求的 Authorization 头解析出登录用户 id（切片 B：user_id 数据隔离）。
// 关键：走 /auth/v1/user 端点让 Supabase【验证 JWT 签名与过期】后返回 user，
// 而不是自己 base64 解码 token——后者不验签，任何人伪造一个 sub 就能冒充他人写库。
// 拿不到（未登录 / token 失效）时返回 null，由调用方决定如何降级。
async function getAuthUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !SUPABASE_URL || !SUPABASE_SVC_KEY) return null;
  try {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        "Authorization": authHeader,   // 用户 JWT，交给 GoTrue 验签
        "apikey": SUPABASE_SVC_KEY,    // apikey 头只用于标识本项目
      },
    });
    if (!res.ok) return null;
    const user = await res.json();
    return typeof user?.id === "string" ? user.id : null;
  } catch (e) {
    console.error("getAuthUserId failed:", e);
    return null;
  }
}

async function insertMessage(
  row: Record<string, unknown>,
  userId: string | null,
  imageUrl: string | null = null
): Promise<void> {
  if (!SUPABASE_URL || !SUPABASE_SVC_KEY) return;
  try {
    await fetch(`${SUPABASE_URL}/rest/v1/messages`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
        "apikey": SUPABASE_SVC_KEY,
        "Prefer": "return=minimal",
      },
      body: JSON.stringify({ ...row, user_id: userId, image_url: imageUrl }),
    });
  } catch (e) {
    console.error("insertMessage failed:", e);
  }
}

// ──────────────────────────────────────────────────────
// Material extraction — 纯函数从 rawContent.ts 导入，便于单元测试。
// ──────────────────────────────────────────────────────

// Stage 2: 分类（scene_category）+ 子场景（scene_detail），一次 Gemini 调用。
// 返回 {category, subScene}；失败时 category 兜底"其他"，subScene 兜底 null。
// TODO: 写入前与该用户该分类下的已有 scene_detail 比较归并（设计方案 §2.3.1）。
//       MVP 先直写，用兜底合并作业处理碎片化。
async function classifyScene(
  targetText: string,
  nativeText: string,
  userOriginal?: string,
): Promise<{category: string; subScene: string | null}> {
  try {
    const prompt =
`Classify this daily-life scene into ONE category. Reply in JSON ONLY.

Categories:
家庭与人际、工作与学业、日常起居、饮食、购物消费、出行交通、运动健康、休闲娱乐、科技数码、天气环境、情绪社交、其他

Note: watching sport/film/show → 休闲娱乐; playing/training sport yourself → 运动健康

Scene: "${targetText}"${userOriginal ? `\nContext: "${userOriginal}"` : ''}

JSON: {"category":"<from list above>","sub_scene":"<specific activity, never null>"}

sub_scene: complete activity, strip qualifiers ("做晚饭"→"做饭"). Anchors: 饮食→做饭/外食; 休闲娱乐→看球/看剧; 运动健康→跑步/打球; 出行交通→通勤/驾车.`;

    const res = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: {
          responseMimeType: 'application/json',
          maxOutputTokens: 100,
          thinkingConfig: { thinkingBudget: 0 },
        },
        safetySettings: [
          { category: "HARM_CATEGORY_HARASSMENT",        threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_HATE_SPEECH",       threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
        ],
      }),
    });
    const data = await res.json();
    // thinkingBudget:0 suppresses thought parts, but defensively skip any thought:true parts
    const parts = data?.candidates?.[0]?.content?.parts ?? [];
    const raw = (parts.find((p: {thought?: boolean; text?: string}) => !p.thought)?.text ?? '').trim();
    console.log('[classifyScene] raw:', raw, '| parts count:', parts.length);
    const parsed = JSON.parse(raw);
    const category = (SCENE_CATEGORIES as readonly string[]).includes(parsed.category)
      ? parsed.category : '其他';
    const subScene = (typeof parsed.sub_scene === 'string' && parsed.sub_scene.trim())
      ? parsed.sub_scene.trim() : null;
    return { category, subScene };
  } catch (e) {
    console.error('[classifyScene] failed:', e);
    return { category: '其他', subScene: null };
  }
}


// 词卡分类：按该词最高频的日常使用场景归类，不允许留空。
async function classifyVocabCategory(wordText: string): Promise<string | null> {
  try {
    const categories = SCENE_CATEGORIES.filter(c => c !== '其他').join('、');
    const prompt =
`In everyday life, which category do people most often encounter or use this word/phrase?
Categories: ${categories}
Word/phrase: "${wordText}"
You MUST pick exactly one category from the list above — do not reply 其他 or anything else.
Reply with the category name ONLY.`;

    const res = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: { maxOutputTokens: 20 },
        safetySettings: [
          { category: "HARM_CATEGORY_HARASSMENT",        threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_HATE_SPEECH",       threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
        ],
      }),
    });
    const data = await res.json();
    // 去掉末尾标点（Gemini 偶尔在分类名后附加标点）
    const raw = (data?.candidates?.[0]?.content?.parts?.find((p: {thought?: boolean; text?: string}) => !p.thought)?.text ?? '').trim();
    const result = raw.replace(/[，。！？,.!?、；;：:]+$/, '').trim();
    if ((SCENE_CATEGORIES as readonly string[]).includes(result)) return result;
    // AI 未能匹配已知分类 → 兜底为「其他」，词条仍可进 Tab2
    console.warn(`[classifyVocabCategory] unmatched "${raw}" for "${wordText}", fallback→其他`);
    return '其他';
  } catch (e) {
    console.error(`[classifyVocabCategory] error for "${wordText}":`, e);
    return '其他';
  }
}

// ── Stage 3 记账：把 learnable_units 灌进词汇账本（lexicon）──
// 归一化（lemmatize/停用词/tier）在 _shared/lexicon.ts 里定义；此处只做 RPC 调用。

// 调记账 RPC。非阻塞：任何失败只告警、不抛给主响应（素材此时已保存成功）。
async function recordLexicon(
  rawContent: UnifiedRawContent,
  materialId: string,
  userId: string | null,
  sceneCategory: string | null,
  sceneDetail: string | null,   // 子场景标签（scene 材料有；vocabulary 和判不出时为 null）
): Promise<void> {
  if (!SUPABASE_URL || !SUPABASE_SVC_KEY || !userId) return;

  try {
    const rawUnits = Array.isArray(rawContent.learnable_units) ? rawContent.learnable_units : [];
    // 词卡（granularity=word）只记主词条，AI 造的例句搭配词不算用户真实接触的内容
    const filteredUnits = rawContent.granularity === 'word'
      ? rawUnits.filter(u => u?.is_primary === true)
      : rawUnits;
    const baseUnits = filteredUnits
      .map(u => {
        const lemma = normalizeLemma(u?.form);
        return {
          lemma,
          display_form: (typeof u?.form === 'string' ? u.form.trim() : '') || null,
          entry_kind: (typeof u?.kind === 'string' ? u.kind : '') || null,
          note: (typeof u?.note === 'string' ? u.note.trim() : '') || null,
          tier: lemma ? getTier(lemma) : null,
        };
      })
      .filter(u => u.lemma && !LEXICON_STOPWORDS.has(u.lemma));

    if (baseUnits.length === 0) return;

    // 缺口 7 修复：passage 素材的 sample_sentence 应为该词所在的那一行，
    // 而不是整篇文章（target_expression 对 passage 是全文，会造成存储浪费和显示异常）。
    // passage_lines 是 [{en, zh}]，在每个 unit 的 display_form 里找第一个包含该词的行。
    const isPassage = rawContent.granularity === 'passage';
    const passageLines = isPassage && Array.isArray(rawContent.passage_lines)
      ? rawContent.passage_lines : null;

    // 材料级共享样例句（非 passage 路径）
    const sharedSample = isPassage ? null
      : (rawContent.target_expression ?? rawContent.user_original ?? null);

    const units = baseUnits.map(u => {
      if (!passageLines) return u;
      // passage：找该词所在的行；找不到则 null（RPC 会 fallback 到 p_sample_sentence = null）
      const form = (u.display_form ?? u.lemma ?? '').toLowerCase();
      const matched = passageLines.find(l => l.en.toLowerCase().includes(form));
      return { ...u, sample_sentence: matched?.en ?? null };
    });

    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/record_lexicon_material_units`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_SVC_KEY}`,
        'apikey': SUPABASE_SVC_KEY,
      },
      body: JSON.stringify({
        p_user_id: userId,
        p_source_id: materialId,
        p_scene_category: sceneCategory,
        p_scene_detail: sceneDetail,
        p_input_lang: rawContent.input_lang ?? null,
        p_input_lang_code: rawContent.input_lang_code ?? null,
        p_source_granularity: rawContent.granularity ?? null,
        p_source_direction: rawContent.direction ?? null,
        p_intent_text: rawContent.intent ?? null,
        p_sample_sentence: sharedSample,
        p_units: units,
      }),
    });

    if (!res.ok) {
      // §5.3.1：记账失败 → 跳过、告警、不阻塞；靠补账作业补回。
      console.error('[recordLexicon] rpc failed (non-blocking):', await res.text());
      return;
    }
    const recorded = await res.json();
    console.log(`[recordLexicon] recorded ${recorded} occurrence(s) for material=${materialId}`);
  } catch (e) {
    console.error('[recordLexicon] error (non-blocking):', e);
  }
}


async function saveMaterial(
  cardType: string,
  cardContent: Record<string, unknown>,
  userText: string,
  userId: string | null,
  sourceImageUrl: string | null,
  source: string
): Promise<void> {
  if (!SUPABASE_URL || !SUPABASE_SVC_KEY) return;

  const extracted = buildRawContent(cardType, cardContent, userText, sourceImageUrl);
  if (!extracted) return;

  const { materialType, rawContent } = extracted;

  // 切片 B：素材必须归属到登录用户；拿不到 uid 说明鉴权没生效，
  // 记录告警但不阻塞生成体验（脏数据由切片 C 的回填/RLS 兜底）。
  if (!userId) {
    console.warn('[saveMaterial] no userId from JWT — material will be written with null user_id');
  }

  try {
    // Stage 1: INSERT — vocabulary直接 categorized，scene 先 pending
    const insertRes = await fetch(`${SUPABASE_URL}/rest/v1/materials`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SUPABASE_SVC_KEY}`,
        'apikey': SUPABASE_SVC_KEY,
        'Prefer': 'return=representation',
      },
      body: JSON.stringify({
        user_id: userId,
        material_type: materialType,
        status: materialType === 'vocabulary' ? 'categorized' : 'pending',
        raw_content: rawContent,
        source,
      }),
    });

    if (!insertRes.ok) {
      console.error('[saveMaterial] insert failed:', await insertRes.text());
      return;
    }

    // materialId 两类都要（Stage 3 记账要拿它当 occurrence 的 source_id）。
    const rows = await insertRes.json() as Array<{ id: string }>;
    const materialId = rows[0]?.id;
    if (!materialId) return;

    // Stage 2: 分类。scene → classifyScene（输出 category + subScene）；
    //          vocabulary → classifyVocabCategory（仅 category，判不准留 null）。
    let sceneCategory: string | null = null;
    let sceneDetail: string | null = null;

    if (materialType === 'scene') {
      const targetText = rawContent.target_expression ?? rawContent.user_original ?? '';
      const nativeText = rawContent.native_meaning ?? rawContent.user_original ?? '';
      const userOriginal = rawContent.user_original ?? undefined;
      const { category, subScene } = await classifyScene(targetText, nativeText, userOriginal);
      sceneCategory = category;
      sceneDetail   = subScene;

      await fetch(`${SUPABASE_URL}/rest/v1/materials?id=eq.${materialId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SUPABASE_SVC_KEY}`,
          'apikey': SUPABASE_SVC_KEY,
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify({ scene_category: sceneCategory, status: 'categorized' }),
      });

      console.log(`[saveMaterial] scene id=${materialId} category=${sceneCategory} subScene=${sceneDetail}`);
    } else {
      // 词卡也判分类（设计方案 §1.05-3）：判不准留 null，不计入任何分类桶。
      const wordText = rawContent.target_expression ?? rawContent.user_original ?? '';
      if (wordText) {
        sceneCategory = await classifyVocabCategory(wordText);
        if (sceneCategory) {
          await fetch(`${SUPABASE_URL}/rest/v1/materials?id=eq.${materialId}`, {
            method: 'PATCH',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${SUPABASE_SVC_KEY}`,
              'apikey': SUPABASE_SVC_KEY,
              'Prefer': 'return=minimal',
            },
            body: JSON.stringify({ scene_category: sceneCategory }),
          });
        }
      }
      // sceneDetail 对词卡永远是 null（无场景上下文）
      console.log(`[saveMaterial] vocab id=${materialId} category=${sceneCategory}`);
    }

    // Stage 3: 记账（非阻塞）。scene 在分类后调，occurrence 的 scene_category 才有值。
    await recordLexicon(rawContent, materialId, userId, sceneCategory, sceneDetail);
  } catch (e) {
    console.error('[saveMaterial] error:', e);
  }
}

// ──────────────────────────────────────────────────────
// Main handler
// ──────────────────────────────────────────────────────

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!GEMINI_API_KEY) {
    return json({ error: "missing_api_key" }, 500);
  }

  try {
    // 切片 B：从用户 JWT 解析出 uid，稍后写进 materials.user_id 完成数据归属。
    const userId = await getAuthUserId(req);

    const body = await req.json();
    const { text, image_base64, mime_type, context, preset_card_id, source } = body as {
      text?: string;
      image_base64?: string;
      mime_type?: string;
      preset_card_id?: string;
      source?: string;
      context?: {
        user: string;
        card_content: Record<string, unknown>;
        image_base64?: string;   // 上一轮图片，follow-up 时重发让 AI 真正看到历史图片
        mime_type?: string;
      } | null;
    };

    if (!text && !image_base64) {
      return json({ error: "missing_input" }, 400);
    }

    // onboarding 每次重新生成前清掉旧记录，确保 DB 里只保留最终一条。
    // 先查 profiles：若已有 onboarding_completed_at（走完引导的用户），跳过清理，
    // 保留已有数据不被覆盖；只有明确"尚未完成"的用户才需要清旧记录重试。
    if (source === 'onboarding' && userId && SUPABASE_URL && SUPABASE_SVC_KEY) {
      const profileRes = await fetch(
        `${SUPABASE_URL}/rest/v1/profiles?id=eq.${userId}&select=onboarding_completed_at`,
        {
          headers: {
            'Authorization': `Bearer ${SUPABASE_SVC_KEY}`,
            'apikey': SUPABASE_SVC_KEY,
          },
        }
      );
      const profiles = await profileRes.json() as Array<{ onboarding_completed_at: string | null }>;
      const alreadyCompleted = profiles.length > 0 && profiles[0].onboarding_completed_at != null;

      if (!alreadyCompleted) {
        const svcHeaders = {
          'Authorization': `Bearer ${SUPABASE_SVC_KEY}`,
          'apikey': SUPABASE_SVC_KEY,
        };
        await Promise.all([
          fetch(`${SUPABASE_URL}/rest/v1/messages?user_id=eq.${userId}&source=eq.onboarding`, { method: 'DELETE', headers: svcHeaders }),
          fetch(`${SUPABASE_URL}/rest/v1/materials?user_id=eq.${userId}&source=eq.onboarding`, { method: 'DELETE', headers: svcHeaders }),
        ]);
      }
    }

    // 在 AI 调用之前就锁定 user 消息时间戳，确保比 assistant 的 now() 早，与异步顺序无关
    const userCreatedAt = new Date().toISOString();

    // Build current-turn Gemini parts（同步，不阻塞）
    // 第 8 刀：有图 → IMAGE_PROMPT，无图 → TEXT_PROMPT
    const hasImage = !!image_base64;
    let systemPrompt = hasImage ? SYSTEM_PROMPT_IMAGE : SYSTEM_PROMPT_TEXT;

    // 第8刀修正：passage 的 300 字符阈值是确定性判断，不能交给模型数——LLM 本质上数不准字符。
    // 纯文字路在服务器端量出精确长度（按 Unicode code point，1 个汉字=1），作为「权威长度」注入提示词，
    // 模型只需照这个数走 STEP 3 的 ≤300 / >300 分界，不再自己估算。
    // 图片路的待处理文字长度只有模型读图后才知道，服务器量不到，那条仍由模型判断。
    if (!hasImage && typeof text === "string" && text.trim()) {
      const charCount = [...text.trim()].length;
      systemPrompt += `\n\n═══ INPUT LENGTH (authoritative — measured by the server) ═══
The user's raw text is exactly ${charCount} characters long.
Use THIS number for the STEP 3 length boundary; do NOT estimate the length yourself.
When STEP 1's OBJECT is the whole input and it has a subject and a predicate:
  · ${charCount} <= 300 -> sentence (s2 / s4)
  · ${charCount} > 300  -> PASSAGE (s5 / s6) — you MUST split it into passage_lines.`;
    }

    let userParts: unknown[];
    if (image_base64 && !text) {
      // 纯图：只发图片，提示词里的 IMAGE READING 负责判定
      userParts = [
        { inline_data: { mime_type: mime_type ?? "image/jpeg", data: image_base64 } },
      ];
    } else if (image_base64 && text) {
      // 图文混合：发图片 + 用户文字，提示词里的 RELATIONSHIP CHECK 负责判定
      userParts = [
        { inline_data: { mime_type: mime_type ?? "image/jpeg", data: image_base64 } },
        { text },
      ];
    } else {
      if (typeof text !== "string" || text.trim() === "") {
        return json({ error: "missing_text" }, 400);
      }
      userParts = [{ text }];
    }

    // 多轮对话：客户端传来上一轮 (user, card_content, 可选 image_base64)，注入为 Gemini history
    // Gemini 用 "model" role（OpenAI 用 "assistant"），此处对应
    const contents: Array<{ role: string; parts: unknown[] }> = [];
    if (context?.user && context?.card_content) {
      // 如果上一轮有图片，重放到历史 user turn，让 AI 在 follow-up 时真正看到图片
      const ctxUserParts: unknown[] = [];
      if (context.image_base64) {
        ctxUserParts.push({
          inline_data: {
            mime_type: context.mime_type ?? "image/jpeg",
            data: context.image_base64,
          },
        });
      }
      ctxUserParts.push({ text: context.user });
      contents.push({ role: "user",  parts: ctxUserParts });
      contents.push({ role: "model", parts: [{ text: JSON.stringify(context.card_content) }] });
    }
    contents.push({ role: "user", parts: userParts });

    // 优先级3：Storage 上传与 Gemini 调用并行——图片消息不比纯文字消息慢。
    // 上传失败时 sourceImagePath=null，素材正常保存只是没有图片，不阻塞主流程。
    const [geminiRes, sourceImagePath] = await Promise.all([
      fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: systemPrompt }] },
          contents,
          generationConfig: { responseMimeType: "application/json" },
          safetySettings: [
            { category: "HARM_CATEGORY_HARASSMENT",        threshold: "BLOCK_MEDIUM_AND_ABOVE" },
            { category: "HARM_CATEGORY_HATE_SPEECH",       threshold: "BLOCK_MEDIUM_AND_ABOVE" },
            { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          ],
        }),
      }),
      image_base64
        ? uploadImage(image_base64, mime_type ?? "image/jpeg", userId)
        : Promise.resolve(null),
    ]);

    if (!geminiRes.ok) {
      return json({ error: "gemini_failed", status: geminiRes.status }, 502);
    }

    const data = await geminiRes.json();

    // 内容被安全过滤器拦截（输入端或输出端）→ 返回可被客户端识别的错误码
    if (data?.promptFeedback?.blockReason) {
      return json({ error: "content_blocked", blockReason: data.promptFeedback.blockReason }, 422);
    }
    if (data?.candidates?.[0]?.finishReason === "SAFETY") {
      return json({ error: "content_blocked", blockReason: "OUTPUT_SAFETY" }, 422);
    }

    const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
    const parsed = JSON.parse(raw);

    // userCreatedAt 在 AI 调用前已锁定，保证早于 assistant 的 DB now()，排序永远正确
    await insertMessage({
      role: "user",
      created_at: userCreatedAt,
      input_type: preset_card_id ? "preset_card" : (image_base64 ? "image" : "text"),
      user_content: image_base64
        ? (text ? `[photo] ${text.trim()}` : "[photo]")
        : (text ?? "").trim(),
      preset_card_id: preset_card_id ?? null,
      source: source ?? "tab1",
      status: "delivered",
    }, userId, sourceImagePath);

    // assistant 消息和素材提取并行，失败不影响主响应
    await Promise.all([
      insertMessage({
        role: "assistant",
        source: source ?? "tab1",
        card_type: parsed.card_type ?? null,
        card_content: parsed.card_content ?? null,
        extracted_concept: parsed.extracted_concept ?? null,
        status: "delivered",
      }, userId, null),
      saveMaterial(parsed.card_type ?? '', parsed.card_content ?? {}, (text ?? '').trim(), userId, sourceImagePath, source ?? 'tab1'),
    ]);

    return json(parsed, 200);
  } catch (_error) {
    return json({ error: "internal_error" }, 500);
  }
});
