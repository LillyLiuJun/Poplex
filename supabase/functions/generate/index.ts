// Supabase Edge Function: generate
// 职责：接收 App 发来的 { text }，在服务器端带着 Gemini API Key 调用 Gemini，
//       按 5 种卡片类型（s1/s2/s3/s4/chat）生成结构化卡片，返回给 App。
//       同时将可提取的素材写入 materials 表（两阶段：内容写入 + 分类打标）。
// 安全：GEMINI_API_KEY 只存在于这里的环境变量，绝不下发到 App。

import { SCENE_CATEGORIES } from '../_shared/constants.ts';

const GEMINI_API_KEY    = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_URL        = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";
const SUPABASE_URL      = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SVC_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const STORAGE_BUCKET    = "material_images";

const SYSTEM_PROMPT = `
You are "English Buddy", a warm, natural English-learning companion for Chinese-speaking users.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SAFETY RULES (check these first)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
If the input is genuinely harmful, illegal, or disallowed (violence, NSFW, hate speech), return:
{"card_type":"error","card_content":{"error_type":"unsafe","message":"这条内容我没办法帮你处理，换一个话题试试？"},"extracted_concept":null}

If the input is empty, random symbols, or completely meaningless with no learnable content, return:
{"card_type":"error","card_content":{"error_type":"meaningless","message":"好像没有接收到内容，再说一次？"},"extracted_concept":null}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
CARD SELECTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Choose exactly one card type. Prefer s1/s2/s3/s4 whenever possible — chat is the last resort.

s1 (轻词典) — English word/phrase input (no predicate), OR user asks what an English word/phrase means:
  Examples: "overtime", "overtime是什么意思", "what does 'slam dunk' mean", "bite the bullet"

s2 (句子分析) — English sentence input (contains a verb / predicate), OR user asks how to say something in English:
  Examples: "I have to work overtime tonight.", "Will attempt to recover by breaking constraint",
            "how to say 'I'm running late' more naturally", "how do I sound more natural here?"
  Note: even if the subject is omitted (headline/note style), treat it as s2 if a verb is present.

s3 (地道翻译) — Chinese word/phrase input (no predicate), user wants the English equivalent:
  Examples: "摸鱼怎么说", "内卷", "一言难尽", "躺平", "请翻译一下：摸鱼"

s4 (场景手帐) — Chinese sentence input (has a verb/predicate), describing a scene, thought, or feeling:
  Examples: "今天地铁挤死了", "我最近压力好大", "昨天开了一天的会", "感觉好累"

chat (对话气泡) — ONLY for questions about English learning itself as a topic:
  Examples: "would和could有什么区别", "英语口音怎么练", "我适合用什么方法学英语", "怎么背单词"
  DO NOT use chat for: greetings alone ("你好"), random English sentences, Chinese life descriptions,
  or anything that can be handled by s1/s2/s3/s4.
  If input is a greeting like "你好" or "hi", treat it as chat with a warm welcome + invite them to share.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GRANULARITY RULE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Contains a verb / predicate → sentence type (s2 for English input, s4 for Chinese input)
- No predicate (word / phrase / idiom) → word type (s1 for English, s3 for Chinese)
- When in doubt about granularity, lean toward the sentence type (s2 or s4)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
LANGUAGE INTENT RULE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Judge by the user's INTENT, not just the character composition:
- "overtime是什么意思" → intent is to look up an English word → s1 (not s3)
- "please translate 摸鱼" → intent is Chinese→English → s3
- All-English input → s1 or s2 by granularity
- All-Chinese input → s3 or s4 by granularity

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SELF-REFERENCE EXTRACTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
If the user says "X怎么说", "X是什么意思", "what does X mean", "how to say X":
extract X and set it as "extracted_concept" in the top-level response.
Otherwise set "extracted_concept" to null.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT SCHEMAS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

s1 card_content fields:
  word          — the English word or phrase
  phonetic      — IPA pronunciation, always include
  pos           — part of speech: n. / v. / adj. / adv. / phr.
  definition    — Chinese definition
  examples      — array of 1–2 objects: [{en, zh}]
  scene_trigger — warm follow-up question in English, connecting to the user's real life

s2 card_content fields:
  chinese_translation — natural Chinese translation of the English input
  grammar_analysis    — (string or null) a grammar point worth explaining; null if simple and correct
  native_polish       — (string or null) a more natural rephrasing; null if the original is already idiomatic
  key_phrase          — (object or null) {phrase, note} highlighting the most idiomatic expression
  scene_trigger       — warm follow-up question in English

s3 card_content fields:
  chinese_concept     — the Chinese word or phrase the user sent
  english_translation — the idiomatic English equivalent
  phonetic            — IPA of the English translation
  pos                 — part of speech
  example             — single object {en, zh} showing it in context
  scene_trigger       — warm follow-up question in English

s4 card_content fields:
  chinese_original    — the user's original Chinese sentence; null for pure image input (no text)
  ai_scene_guess      — (string or null) a brief Chinese description of the scene you see in the photo; set only when chinese_original is null; null in all other cases
  native_translation  — natural English version of the scene
  key_phrase          — (object or null) {phrase, note} for the most notable expression
  scene_trigger       — warm follow-up question in English

chat card_content fields:
  text              — your response, conversational and warm; use Chinese when explaining Chinese concepts
  scene_connection  — (string or null) optional bridge connecting back to the user's real life

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TONE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
- Warm and encouraging, like a knowledgeable friend
- scene_trigger should feel genuinely curious, not formulaic
- Keep responses concise and practical

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MULTI-TURN CONTEXT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
When prior conversation turns are provided, use them as context if the current input is related.
If the current input is clearly a new unrelated topic, ignore the prior context and treat it as a fresh input.
Always apply the card selection rules independently to the current input.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Return ONLY valid JSON with EXACTLY this top-level shape (no markdown, no extra text):
{
  "card_type": "s1" | "s2" | "s3" | "s4" | "chat" | "error",
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

interface SceneRawContent {
  native_english: string;
  chinese_original: string;
  key_phrases: { phrase: string; note: string }[];
  source_image_path: string | null;  // 优先级3：来源图片在私有 Storage 的路径（非 URL）
}

interface VocabRawContent {
  word: string;
  phonetic: string;
  pos: string;
  definition: string;
  example_en: string;
  example_zh: string;
}

function buildRawContent(
  cardType: string,
  content: Record<string, unknown>,
  userText: string,
  sourceImageUrl: string | null
): { materialType: 'scene' | 'vocabulary'; rawContent: SceneRawContent | VocabRawContent } | null {
  switch (cardType) {
    case 's1': {
      const examples = (content.examples as Array<{ en: string; zh: string }>) ?? [];
      return {
        materialType: 'vocabulary',
        rawContent: {
          word: String(content.word ?? ''),
          phonetic: String(content.phonetic ?? ''),
          pos: String(content.pos ?? ''),
          definition: String(content.definition ?? ''),
          example_en: examples[0]?.en ?? '',
          example_zh: examples[0]?.zh ?? '',
        },
      };
    }
    case 's2': {
      const kp = content.key_phrase as { phrase: string; note: string } | null;
      return {
        materialType: 'scene',
        rawContent: {
          native_english: String(content.native_polish ?? userText),
          chinese_original: String(content.chinese_translation ?? ''),
          key_phrases: kp ? [kp] : [],
          source_image_path: sourceImageUrl,
        },
      };
    }
    case 's3': {
      const ex = (content.example as { en: string; zh: string }) ?? {};
      return {
        materialType: 'vocabulary',
        rawContent: {
          word: String(content.english_translation ?? ''),
          phonetic: String(content.phonetic ?? ''),
          pos: String(content.pos ?? ''),
          definition: String(content.chinese_concept ?? ''),
          example_en: ex.en ?? '',
          example_zh: ex.zh ?? '',
        },
      };
    }
    case 's4': {
      const kp = content.key_phrase as { phrase: string; note: string } | null;
      return {
        materialType: 'scene',
        rawContent: {
          native_english: String(content.native_translation ?? ''),
          chinese_original: String(content.chinese_original ?? ''),
          key_phrases: kp ? [kp] : [],
          source_image_path: sourceImageUrl,
        },
      };
    }
    default:
      return null; // chat, error — 不提取
  }
}

async function classifySceneCategory(nativeEnglish: string, chineseOriginal: string): Promise<string> {
  try {
    const categories = SCENE_CATEGORIES.join('、');
    const prompt = `Classify into exactly one category.\nCategories: ${categories}\nContent: "${nativeEnglish}" (${chineseOriginal})\nReply with the category name only.`;

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
  sourceImageUrl: string | null
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

      const scene = rawContent as SceneRawContent;
      const category = await classifySceneCategory(scene.native_english, scene.chinese_original);

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

    // onboarding 每次重新生成前清掉旧记录，确保 DB 里只保留最终一条
    if (source === 'onboarding' && userId && SUPABASE_URL && SUPABASE_SVC_KEY) {
      await fetch(
        `${SUPABASE_URL}/rest/v1/messages?user_id=eq.${userId}&source=eq.onboarding`,
        {
          method: 'DELETE',
          headers: {
            'Authorization': `Bearer ${SUPABASE_SVC_KEY}`,
            'apikey': SUPABASE_SVC_KEY,
          },
        }
      );
    }

    // 在 AI 调用之前就锁定 user 消息时间戳，确保比 assistant 的 now() 早，与异步顺序无关
    const userCreatedAt = new Date().toISOString();

    // Build current-turn Gemini parts（同步，不阻塞）
    let userParts: unknown[];
    if (image_base64 && !text) {
      userParts = [
        { inline_data: { mime_type: mime_type ?? "image/jpeg", data: image_base64 } },
        { text: "The user sent only a photo. Generate an s4 card. Set chinese_original to null. Set ai_scene_guess to a concise Chinese description of what you see (e.g. \"一杯咖啡放在办公桌上\"). Fill native_translation, key_phrase, and scene_trigger based on the scene." },
      ];
    } else if (image_base64 && text) {
      userParts = [
        { inline_data: { mime_type: mime_type ?? "image/jpeg", data: image_base64 } },
        { text: `The user sent this photo along with the following text. Use the text to classify and generate the card (s1/s2/s3/s4). The photo is additional context — let it inform the scene details in native_translation and scene_trigger. User text: ${text}` },
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
      saveMaterial(parsed.card_type ?? '', parsed.card_content ?? {}, (text ?? '').trim(), userId, sourceImagePath),
    ]);

    return json(parsed, 200);
  } catch (_error) {
    return json({ error: "internal_error" }, 500);
  }
});
