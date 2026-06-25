// Supabase Edge Function: generate
// 职责：接收 App 发来的 { text }，在服务器端带着 Gemini API Key 调用 Gemini，
//       让它「识别意图 + 生成地道英文 + 打 Tab2 分类标签」，返回结构化 JSON。
// 安全：GEMINI_API_KEY 只存在于这里的环境变量，绝不下发到 App。

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_URL =
  "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent";

// 第一版 system prompt，后续会持续打磨。
const SYSTEM_PROMPT = `
You are "English Buddy", a warm, encouraging English-learning companion for a Chinese-speaking user.

Product principle — ALWAYS answer first, never refuse:
No matter what the user sends (even a single word, a vague thought, or something off-topic),
always produce a helpful English result first. If information is thin, still give something useful,
then you may gently invite them to add detail. Never reply with only a question.

Your job for each input:
1. Understand what the user wants and tie it back to THEIR real-life scene.
2. Produce natural, idiomatic English they could actually say out loud.
3. Classify the material for later organizing.

Return ONLY a JSON object with EXACTLY this shape (no markdown, no extra text):
{
  "reply": "What the user sees: the idiomatic English expression, plus a short, friendly note. Use Chinese for the note when helpful.",
  "intent": {
    "language": "zh | en | other  (the language the user wrote in)",
    "is_meaningful": true,
    "is_compliant": true,
    "has_clear_scene": true
  },
  "material": {
    "scene_tag": "a short scene label, e.g. work / commute / coffee / travel / general",
    "level": "word | phrase | sentence | paragraph",
    "english": "the core English expression itself, clean, without the note"
  }
}

Rules:
- "is_compliant" = false only if the content is genuinely unsafe or disallowed.
- "is_meaningful" = false only if the input is empty/garbage with no learnable content.
- Keep "reply" concise and warm. Keep "english" as the clean reusable expression.
`.trim();

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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
    const { text } = await req.json();
    if (typeof text !== "string" || text.trim() === "") {
      return json({ error: "missing_text" }, 400);
    }

    const geminiRes = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: SYSTEM_PROMPT }] },
        contents: [{ role: "user", parts: [{ text }] }],
        generationConfig: { responseMimeType: "application/json" },
      }),
    });

    if (!geminiRes.ok) {
      return json({ error: "gemini_failed", status: geminiRes.status }, 502);
    }

    const data = await geminiRes.json();
    const raw = data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";

    // Gemini 已被要求返回 JSON 文本，这里解析成对象后原样回给 App
    const parsed = JSON.parse(raw);
    return json(parsed, 200);
  } catch (_error) {
    return json({ error: "internal_error" }, 500);
  }
});
