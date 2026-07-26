// Supabase Edge Function: generate
// 职责：接收 App 发来的 { text }，在服务器端带着 Gemini API Key 调用 Gemini，
//       按 granularity×direction 生成统一结构的学习卡（card_type 仍用 s1/s2/s3/s4 作判别符），返回给 App。
//       同时将可提取的素材写入 materials 表（两阶段：内容写入 + 分类打标）。
// 安全：GEMINI_API_KEY 只存在于这里的环境变量，绝不下发到 App。

import { SCENE_CATEGORIES } from '../_shared/constants.ts';

const GEMINI_API_KEY    = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_URL        = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
const SUPABASE_URL      = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SVC_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const STORAGE_BUCKET    = "material_images";

// ──────────────────────────────────────────────────────
// SYSTEM_PROMPT · 文字路（text / text+image）
//
// 依据：docs/prd/Tab1_Prompt与输出结构_改造方案_v2.md
// 本版改动（第 1 刀，纯提示词 + 落库新增字段，前端零改动）：
//   1. 四块规则改为【有顺序的四步流程】—— STEP 0/1/2/3，这是修「判错」的关键
//   2. 判据从「中文 vs 英文」改为「有没有非目标语言成分」，第三种语言零成本覆盖
//   3. word 侧新增形式判定（词形变化 / 拼写错），卡片主体给规范词条
//   4. sentence 侧明确「先判问题 → 修正 → 翻译修正版」的顺序，新增 revision_type
//   5. 新增 learnable_units[]（账本进料口，筛选标准为 v0 临时版）
//   6. persona / TONE 重做为「温润极简 + 注重效率」
//   7. 删除 chat 卡型
// 向后兼容：card_type / 现有 card_content 字段全部保留，新字段是【新增】。
// ──────────────────────────────────────────────────────
const SYSTEM_PROMPT = `
You are the English-learning engine inside an app that turns a user's own life into study material.

TARGET_LANGUAGE = English   (the language the user is learning)
NATIVE_LANGUAGE  = Chinese  (the language used to explain things to the user)

Reason in terms of "target" and "native", never in terms of "English vs Chinese" as a fixed pair.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PROCESS EVERY INPUT THROUGH FOUR STEPS, STRICTLY IN ORDER.
Never skip ahead. The order is what makes the classification correct.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

═══ STEP 0 · SAFETY & VALIDITY GATE ═══

If the input is genuinely harmful, illegal, or disallowed (violence, NSFW, hate speech), STOP and return:
{"card_type":"error","card_content":{"error_type":"unsafe","message":"这条内容我没办法帮你处理，换一个话题试试？"},"extracted_concept":null}

If the input is empty, random symbols, or has no learnable content at all, STOP and return:
{"card_type":"error","card_content":{"error_type":"meaningless","message":"好像没有接收到内容，再说一次？"},"extracted_concept":null}

A greeting alone ("你好", "hi") counts as no learnable content → meaningless error.
Questions about English learning as a topic ("would和could有什么区别") are NOT errors — carry them
through the normal steps below, treating the quoted items as the object (STEP 1).

═══ STEP 1 · LOCATE THE OBJECT ═══

Decide WHAT you are processing. Everything after this step applies to the OBJECT, not to the whole input.

If the user is asking ABOUT a language fragment — patterns like "X怎么说", "X是什么意思",
"what does X mean", "how to say X", "X和Y有什么区别" — then:
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

  · OBJECT has no EXPLICIT predicate in the text itself             → granularity = "word"
    (a word, phrase, idiom, collocation, or noun phrase)
  · OBJECT has an explicit verb / predicate, or is a complete proposition → granularity = "sentence"
  · When genuinely ambiguous, lean toward "sentence".

  Examples — word:
    "hardly any standing room"  → word  (noun phrase; no verb present in the text itself)
    "c'est la vie"              → word  (fixed foreign expression used as an idiomatic unit)
    "bite the bullet"           → word  (idiom)
  Examples — sentence:
    "Having a rough day."          → sentence  (has predicate structure)
    "I have to work overtime."     → sentence
    "I have a 会议 at 3pm"         → sentence  (full predicate "I have … at 3pm"; the embedded
                                               native word doesn't change the sentence structure)

  Fixed foreign expressions ("c'est la vie", "bon appétit", "carpe diem", etc.) treated as
  a single idiomatic unit → always granularity = "word", even if they contain a verb.
  Note: these expressions are in a NON-target language (French, Latin, etc.), so STEP 2 still
  applies — they are express, just like native-language input. The user wants the English equivalent.

("passage" exists as a future value for long pasted text. Do NOT use it yet.)

═══ MAP TO CARD TYPE ═══

  word     + comprehend → "s1"
  sentence + comprehend → "s2"
  word     + express    → "s3"
  sentence + express    → "s4"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
FLOWS — follow the one matching your (granularity, direction)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

All four flows write the SAME unified fields (see OUTPUT SCHEMAS). What differs is which
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

NEVER extract:
  · function words                       — the, a, is, of, to, and
  · very basic standalone words          — good, day, work, time
    (they count when part of a collocation, e.g. "call it a day")
  · proper nouns, numbers, dates
  · anything in the user's native language

Each unit:
  form       — the expression in its base form
  kind       — one of: word | phrase | collocation | slang | idiom | pattern
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
  granularity        — "word" | "sentence"
  direction          — "comprehend" | "express"
  revision_type      — "error" | "polish" | null   (only meaningful on sentence+comprehend)
  learnable_units    — array as defined above (may be [])

Then the content fields:
  user_original      — the user's raw input, VERBATIM, never edited
  user_original_lang — "target" if the input is in the target language; otherwise the source
                       language ("native", "ja", "fr", …). Best effort.
  target_expression  — the AI-produced target-language expression (see each flow):
                        · word+comprehend     → the canonical entry
                        · word+express        → the idiomatic translation
                        · sentence+comprehend → corrected/polished version, or NULL if the
                                                original was already fine
                        · sentence+express    → the natural target-language sentence
  native_meaning     — native-language meaning of (target_expression ?? user_original):
                        · word cards     → the definition
                        · sentence+comp  → translation of the CORRECT version
                        · sentence+expr  → may be null (user_original already carries it)
  phonetic           — IPA. word cards only; null on sentence cards
  pos                — ARRAY of up to 3 parts of speech, e.g. ["v.", "n."]. word cards only; [] otherwise
  examples           — array of {en, zh}. word: 1–2; sentence: [] unless clearly helpful
  grammar_note       — string or null. A brief linguistic observation about the target
                       expression — curious and informative, never corrective. word: when
                       entry ≠ user input (spoken→speak). sentence: REQUIRED when
                       revision_type = "error". Never references the user's input directly.
  ai_scene_guess     — string or null. ONLY for pure-image input (no text): a short
                       native-language description of the photo. null otherwise

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MULTI-TURN CONTEXT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
When prior turns are provided, use them as context if the current input relates to them.
If the current input is clearly a new topic, ignore the prior context.
ALWAYS re-run the four steps independently for the current input.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Return ONLY valid JSON, exactly this top-level shape (no markdown, no extra text):
{
  "card_type": "s1" | "s2" | "s3" | "s4" | "error",
  "card_content": { ... },
  "extracted_concept": "X" | null
}
`.trim();

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
// Material extraction
// ──────────────────────────────────────────────────────

// 可学单元：账本（lexicon）的唯一进料口。
// 由主 prompt 顺带输出，无需为记账另跑一次 AI 调用。
// is_primary 让「卡片展示什么」和「账本收什么」在同一次输出里分开：
// 卡片只高亮 is_primary，账本吃全部。
interface LearnableUnit {
  form: string;
  kind: string;        // word | phrase | collocation | slang | idiom | pattern
  note: string;
  is_primary: boolean;
}

// 统一 raw_content（第5刀）：不再按卡型分 Scene/Vocab 两套结构，一套字段按维度取用。
// 字段名与 card_content 完全对齐，读侧（get-materials 透传）直接映射到前端 Material。
// 全部标注可选是因为模型偶发漏字段时素材仍照常落库，读取端须容忍 undefined。
interface UnifiedRawContent {
  granularity?: string;                 // word | sentence
  direction?: string;                   // comprehend | express
  revision_type?: string | null;        // error | polish | null（仅 sentence+comprehend 有意义）
  learnable_units?: LearnableUnit[];
  user_original: string | null;         // 用户原样输入；纯图为 null
  user_original_lang?: string | null;   // target | 具体语言码
  target_expression: string | null;     // AI 产出的目标语言表达；sentence+comp 原句无误时为 null
  native_meaning?: string | null;       // 对 (target_expression ?? user_original) 的母语释义/译文
  phonetic?: string | null;             // 仅 word
  pos?: string[];                        // 仅 word，最多 3
  examples?: { en: string; zh: string }[];
  grammar_note?: string | null;         // word 讲形式 / sentence 讲语法
  ai_scene_guess?: string | null;       // 仅纯图
  source_image_path: string | null;     // 来源图片在私有 Storage 的路径（非 URL）
}

const asStr = (v: unknown): string | null => (typeof v === 'string' && v.length > 0 ? v : null);

// 把 AI 返回的统一 card_content 落成统一 raw_content。
// material_type 由 granularity 决定（word→vocabulary、sentence→scene），维持 Tab2 现有两类展示；
// granularity 缺失时按 cardType 兜底（s1/s3→vocab、s2/s4→scene）。
function buildRawContent(
  cardType: string,
  content: Record<string, unknown>,
  userText: string,
  sourceImageUrl: string | null
): { materialType: 'scene' | 'vocabulary'; rawContent: UnifiedRawContent } | null {
  if (cardType !== 's1' && cardType !== 's2' && cardType !== 's3' && cardType !== 's4') {
    return null; // error / 未知 — 不提取
  }

  const granularity = asStr(content.granularity) ?? (cardType === 's1' || cardType === 's3' ? 'word' : 'sentence');
  const materialType: 'scene' | 'vocabulary' = granularity === 'word' ? 'vocabulary' : 'scene';

  const units = content.learnable_units;
  const examples = Array.isArray(content.examples)
    ? (content.examples as Array<{ en?: unknown; zh?: unknown }>).map(e => ({
        en: String(e?.en ?? ''),
        zh: String(e?.zh ?? ''),
      }))
    : [];
  const pos = Array.isArray(content.pos)
    ? (content.pos as unknown[]).map(String)
    : (asStr(content.pos) ? [String(content.pos)] : []);

  // user_original：优先取 AI 回填的原样输入，兜底用请求文本；纯图（都为空）落 null。
  const userOriginal = asStr(content.user_original) ?? (userText.trim() ? userText.trim() : null);

  const rawContent: UnifiedRawContent = {
    granularity,
    direction: asStr(content.direction) ?? (cardType === 's1' || cardType === 's2' ? 'comprehend' : 'express'),
    revision_type: asStr(content.revision_type),
    learnable_units: Array.isArray(units) ? units as LearnableUnit[] : [],
    user_original: userOriginal,
    user_original_lang: asStr(content.user_original_lang),
    target_expression: asStr(content.target_expression),
    native_meaning: asStr(content.native_meaning),
    phonetic: asStr(content.phonetic),
    pos,
    examples,
    grammar_note: asStr(content.grammar_note),
    ai_scene_guess: asStr(content.ai_scene_guess),
    source_image_path: sourceImageUrl,
  };

  return { materialType, rawContent };
}

async function classifySceneCategory(targetText: string, nativeText: string): Promise<string> {
  try {
    const categories = SCENE_CATEGORIES.join('、');
    const prompt = `Classify into exactly one category.\nCategories: ${categories}\nContent: "${targetText}" (${nativeText})\nReply with the category name only.`;

    const res = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        generationConfig: { maxOutputTokens: 20 },
      }),
    });

    const data = await res.json();
    const result = (data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '').trim();
    return (SCENE_CATEGORIES as readonly string[]).includes(result) ? result : '其他';
  } catch {
    return '其他';
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

    // Stage 2: 对 scene 调用 Gemini 分类，写回 scene_category
    if (materialType === 'scene') {
      const rows = await insertRes.json() as Array<{ id: string }>;
      const materialId = rows[0]?.id;
      if (!materialId) return;

      // 分类用目标语言表达 + 母语侧文本；后者优先母语释义，兜底用户原句。
      const targetText = rawContent.target_expression ?? rawContent.user_original ?? '';
      const nativeText = rawContent.native_meaning ?? rawContent.user_original ?? '';
      const category = await classifySceneCategory(targetText, nativeText);

      await fetch(`${SUPABASE_URL}/rest/v1/materials?id=eq.${materialId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SUPABASE_SVC_KEY}`,
          'apikey': SUPABASE_SVC_KEY,
          'Prefer': 'return=minimal',
        },
        body: JSON.stringify({ scene_category: category, status: 'categorized' }),
      });

      console.log(`[saveMaterial] scene saved id=${materialId} category=${category}`);
    } else {
      console.log(`[saveMaterial] vocab saved`);
    }
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
    let userParts: unknown[];
    if (image_base64 && !text) {
      userParts = [
        { inline_data: { mime_type: mime_type ?? "image/jpeg", data: image_base64 } },
        { text: "The user sent only a photo (no text). Produce an s4 card (sentence + express). Set user_original to null and user_original_lang to null. Set ai_scene_guess to a concise native-language description of what you see (e.g. \"一杯咖啡放在办公桌上\"). Set target_expression to a natural English sentence describing the scene, native_meaning may be null, and extract learnable_units." },
      ];
    } else if (image_base64 && text) {
      userParts = [
        { inline_data: { mime_type: mime_type ?? "image/jpeg", data: image_base64 } },
        { text: `The user sent this photo along with the following text. Use the text to classify and generate the card (s1/s2/s3/s4). The photo is additional context — let it inform the scene details in target_expression. User text: ${text}` },
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
          systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
          contents,
          generationConfig: { responseMimeType: "application/json" },
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
