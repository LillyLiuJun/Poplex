// Supabase Edge Function: dialogue
// 对话页核心 API — action 路由：start | turn
// 权威依据：对话页_接口契约_v1.md + 对话页_Prompt设计与全文_v1.md
//
// 安全范式与 generate/index.ts 一致：
//   ① JWT 由 /auth/v1/user 验证，绝不在本地解码
//   ② service key 写入，必须手动带 user_id（service key 跳过 RLS）
//   ③ GEMINI_API_KEY 只存在于环境变量

const SUPABASE_URL     = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SVC_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const GEMINI_API_KEY   = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_URL       = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.7-flash:generateContent";

import { normalizeDialogueSceneCategory } from "./sceneCategory.ts";

// ─────────────────────────────────────────────────────────────
// CORS
// ─────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────
// Dialogue system prompt (对话页_Prompt设计与全文_v1.md §五)
// ─────────────────────────────────────────────────────────────

const DIALOGUE_SYSTEM_PROMPT = `You are a speaking partner for someone practising a target language.
They are not fluent. They are often tired, distracted, or slightly embarrassed.
Your entire job is to make them say the next sentence.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
THE ONE RULE THAT OVERRIDES EVERYTHING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Every word you produce either makes it easier for them to speak, or takes up
space they could have spoken in. When in doubt, say less.

You are not here to teach, assess, encourage, or demonstrate good English.
You are here to keep a person talking about their own life.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HARD CONSTRAINTS  (violating any of these is a failure, not a style issue)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. LENGTH.    "reply" is at most 2 sentences and at most 30 words. Always.

2. NEVER CORRECT. Never mention, hint at, rephrase, or repair anything the user
   said wrong. No "did you mean", no "you can also say", no gentle modelling of
   the correct form. Errors go into "correctness.issues" — that field is read by
   a database, never by the user. If you cannot understand them, ask them to say
   more about it; never say you didn't understand their English.

3. NEVER PRAISE. No "great", "nice", "well done", "your English is good",
   "that's a good sentence". Not even once, not even small.
   Warmth comes from describing their situation accurately, never from
   evaluating them.

4. NEVER INVENT THEIR LIFE. You may only refer to facts present in "seed", in
   "topic", or in what the user has said in this conversation. Do not add
   details, do not guess what happened, do not assume outcomes.
   If you need something you do not have, ask for it.

5. TARGET LANGUAGE ONLY in "reply". Never mix in the native language.

6. ASK ABOUT SITUATIONS, NEVER ABOUT RESULTS OR PROGRESS.
   Forbidden: whether they finished something, whether they've been practising,
   how they feel about their own language ability, whether they kept a habit.

7. NO emoji. No exclamation marks used to carry emotion. No describing yourself
   or your role. No meta-commentary about the conversation or about learning.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RHYTHM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Do not end every turn with a question — that reads as an interrogation.
Across any two consecutive turns, at least one must contain an open question.
The other may simply receive what they said and stop, leaving them room.

  user:  "I set up the room but the projector no work"
  ✅     "So you were troubleshooting before the day even started."      (receive, stop)
  ❌     "Oh no! Did you manage to fix it? What did you do next?"        (two questions, exclamation, asks a result)

Follow the user. If they move to something you know nothing about, go with them —
their own words are the best anchor there is. Never steer them back to the seed.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MODES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

▸ OPENING
  This is the first thing they hear. It must be a NARROWING QUESTION: name two
  or three of the candidate sub-scenes in natural speech and let them pick.
  Answering it is the lowest-effort way to start speaking — that is its purpose.

  · Use the candidates' quotes to make it concrete, but paraphrase — never read
    their own sentence back at them verbatim.
  · At most 2 sentences. Name at most 3 options.
  · Set "scene_detail" to null in this mode.

  ✅ "You've got mornings at the office and client calls in here. Which one's on
      your mind?"
  ❌ "Welcome back! Ready to practise your English today? Let's talk about work!"
     (self-description, praise-adjacent, asks about practising, exclamation marks)

  If "candidates" is empty, ask what their day has been like instead. Whatever
  they answer becomes the anchor.

▸ TURN
  Normal conversation. Everything above applies.
  Set "scene_detail" on the FIRST turn only: which candidate did they choose?
  If they said "anything" / didn't choose / chose something not in the list,
  set it to null and simply follow them.

▸ FALLBACK
  They said what they wanted in their native language because they could not say
  it in the target language.

  Produce ONLY: the natural target-language version, phonetics for at most 2 words
  that are genuinely hard, and one short neutral nudge.

  · Do NOT reply to the content. Do NOT continue the conversation.
  · Do NOT comment on the fact that they used their native language.
  · The nudge is neutral and mechanical, like "Try saying it." — never
    encouraging, never reassuring, never "don't worry".

▸ WRAP
  One sentence, in the target language, stating what they did — not how well.
  ✅ "You talked through a whole morning in English today."
  ❌ "Great session! You're really improving!"

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
WHAT TO RECORD  (silent — none of this reaches the user)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
▸ used_entries
  Lemmas from "ledger" that the user actually said this turn. Match on meaning,
  not exact form: "set it up" counts as "set up"; "ran late" counts as "run late".
  Only what THEY said — never what you said.

▸ new_expressions
  Expressions the user produced that are NOT in "ledger" and are worth keeping.
  Exclude: filler, greetings, single function words, anything you supplied first.
  At most 3 per turn. Fewer is better.

▸ correctness
  Judge the user's utterance for grammar and usage problems.
  · At most 2 issues per turn, and only ones you are confident about.
  · aspect ∈ vocab | grammar | collocation | pronunciation
  · Grammar problems that belong to no particular word are still recorded —
    that is normal and expected.
  · If the utterance is fragmentary or the transcription looks garbled, report
    NO issues. A false correction is far worse than a missed one.

▸ current_topic
  What is actually being talked about right now, re-inferred every turn.
  It may drift away from "scene_detail" — that is fine, report what is true.

▸ suggestions
  At most 3 lemmas from "ledger" they could naturally use next.
  Prefer entries flagged is_known_gap, then ones they have not used before.
  These are shown collapsed; they are a safety net, not a lesson.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OUTPUT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Return JSON only. Shape depends on mode (OPENING/TURN, FALLBACK, WRAP) —
see the schema supplied with the request. No prose outside the JSON.`;

// ─────────────────────────────────────────────────────────────
// Category label mapping (mirrors SceneCategoryMap.swift)
// New records use English keys directly. Legacy Chinese keys from old DB
// rows are also mapped here so existing data renders correctly.
// ─────────────────────────────────────────────────────────────

const CATEGORY_LABELS: Record<string, string> = {
  // ── New English keys (used by all new records) ──────────────
  "Home & Family":     "Home & Family",
  "Work & Study":      "Work & Study",
  "Daily Routine":     "Daily Routine",
  "Food & Drink":      "Food & Drink",
  "Shopping":          "Shopping",
  "Travel & Commute":  "Travel & Commute",
  "Health & Fitness":  "Health & Fitness",
  "Hobbies & Leisure": "Hobbies & Leisure",
  "Digital & Tech":    "Digital & Tech",
  "Weather & Nature":  "Weather & Nature",
  "Social & Feelings": "Social & Feelings",
  "Other":             "Other",
  // ── Legacy Chinese keys (existing DB rows — kept for compat) ─
  "家庭与人际": "Home & Family",
  "工作与学业": "Work & Study",
  "日常起居":   "Daily Routine",
  "饮食":       "Food & Drink",
  "购物消费":   "Shopping",
  "出行交通":   "Travel & Commute",
  "运动健康":   "Health & Fitness",
  "休闲娱乐":   "Hobbies & Leisure",
  "科技数码":   "Digital & Tech",
  "天气环境":   "Weather & Nature",
  "情绪社交":   "Social & Feelings",
  "其他":       "Other",
};

// ─────────────────────────────────────────────────────────────
// Auth helper
// ─────────────────────────────────────────────────────────────

async function getAuthUserId(req: Request): Promise<string | null> {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !SUPABASE_URL || !SUPABASE_SVC_KEY) return null;
  try {
    const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      headers: {
        "Authorization": authHeader,
        "apikey": SUPABASE_SVC_KEY,
      },
    });
    if (!res.ok) return null;
    const user = await res.json();
    return typeof user?.id === "string" ? user.id : null;
  } catch (e) {
    console.error("[dialogue] getAuthUserId failed:", e);
    return null;
  }
}

// ─────────────────────────────────────────────────────────────
// Supabase REST helpers
// ─────────────────────────────────────────────────────────────

const svcHeaders = {
  "Content-Type": "application/json",
  "Authorization": `Bearer ${SUPABASE_SVC_KEY}`,
  "apikey": SUPABASE_SVC_KEY,
};

async function dbGet(path: string): Promise<unknown[]> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    headers: svcHeaders,
  });
  if (!res.ok) {
    console.error(`[dialogue] dbGet ${path} failed:`, await res.text());
    return [];
  }
  return res.json();
}

async function dbPost(table: string, body: unknown): Promise<unknown[]> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${table}`, {
    method: "POST",
    headers: { ...svcHeaders, "Prefer": "return=representation" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    console.error(`[dialogue] dbPost ${table} failed:`, await res.text());
    return [];
  }
  return res.json();
}

async function dbPatch(path: string, body: unknown): Promise<void> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    method: "PATCH",
    headers: svcHeaders,
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    console.error(`[dialogue] dbPatch ${path} failed:`, await res.text());
  }
}

// ─────────────────────────────────────────────────────────────
// Gemini helper
// ─────────────────────────────────────────────────────────────

async function callGemini(payload: unknown): Promise<unknown> {
  const res = await fetch(`${GEMINI_URL}?key=${GEMINI_API_KEY}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      system_instruction: { parts: [{ text: DIALOGUE_SYSTEM_PROMPT }] },
      contents: [{
        role: "user",
        parts: [{ text: JSON.stringify(payload, null, 2) }],
      }],
      generationConfig: {
        responseMimeType: "application/json",
        maxOutputTokens: 600,
        thinkingConfig: { thinkingBudget: 0 },
      },
    }),
  });
  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Gemini ${res.status}: ${err}`);
  }
  const data = await res.json();
  const parts = data?.candidates?.[0]?.content?.parts ?? [];
  const raw = (parts.find((p: { thought?: boolean; text?: string }) => !p.thought)?.text ?? "").trim();
  return JSON.parse(raw);
}

// ─────────────────────────────────────────────────────────────
// Shared context assembler (used by both start and turn)
// ─────────────────────────────────────────────────────────────

interface SeedItem {
  user_original: string | null;
  target_expression: string | null;
  key_phrases: string[];
}

interface LedgerItem {
  lemma: string;
  sample: null;
  is_known_gap: boolean;
}

async function assembleSeed(userId: string, sceneCategory: string): Promise<SeedItem[]> {
  const catQ = encodeURIComponent(sceneCategory);
  const materials = await dbGet(
    `materials?user_id=eq.${userId}&scene_category=eq.${catQ}&deleted_at=is.null&select=raw_content&order=created_at.desc&limit=3`
  ) as Array<{ raw_content: Record<string, unknown> }>;

  return materials
    .map(m => {
      const rc = m.raw_content;
      if (!rc) return null;
      const units = Array.isArray(rc.learnable_units) ? rc.learnable_units : [];
      const keyPhrases = (units as Array<{ form?: string }>)
        .slice(0, 3)
        .map(u => u.form)
        .filter((f): f is string => typeof f === "string");
      return {
        user_original: typeof rc.user_original === "string" ? rc.user_original : null,
        target_expression: typeof rc.target_expression === "string" ? rc.target_expression : null,
        key_phrases: keyPhrases,
      };
    })
    .filter((x): x is SeedItem => x !== null);
}

async function assembleLedger(userId: string, sceneCategory: string): Promise<LedgerItem[]> {
  const catQ = encodeURIComponent(sceneCategory);
  const entries = await dbGet(
    `lexicon_entries?user_id=eq.${userId}&scene_category=eq.${catQ}&status=eq.active&select=lemma,spoken_count&order=spoken_count.asc,total_count.desc&limit=15`
  ) as Array<{ lemma: string; spoken_count: number }>;

  return entries.map(e => ({
    lemma: e.lemma,
    sample: null,
    is_known_gap: e.spoken_count === 0,
  }));
}

// ─────────────────────────────────────────────────────────────
// action = "start"
// ─────────────────────────────────────────────────────────────

async function handleStart(userId: string, rawSceneCategory: string): Promise<Response> {
  if (!rawSceneCategory) return json({ error: "missing_scene_category" }, 400);
  // 写入防线（评审 #1）：归一化到英文 key（中文 legacy 映射、'Work' 特例归位），
  // 无效值显式 400 拒收——dialogue_sessions.scene_category 无 CHECK 约束，
  // 原样落库会让脏值静默分裂分类（线上实测迁移后仍有 'Work' 新写入）。
  const sceneCategory = normalizeDialogueSceneCategory(rawSceneCategory);
  if (!sceneCategory) return json({ error: "invalid_scene_category" }, 400);

  // 1. Create session
  const sessionRows = await dbPost("dialogue_sessions", {
    user_id: userId,
    scene_category: sceneCategory,
  }) as Array<{ id: string }>;
  const sessionId = sessionRows[0]?.id;
  if (!sessionId) return json({ error: "session_create_failed" }, 500);

  // 2. Candidates — past sub-scenes the user visited in this category
  const catQ = encodeURIComponent(sceneCategory);
  const pastSessions = await dbGet(
    `dialogue_sessions?user_id=eq.${userId}&scene_category=eq.${catQ}&scene_detail=not.is.null&select=scene_detail`
  ) as Array<{ scene_detail: string }>;

  const countMap: Record<string, number> = {};
  for (const s of pastSessions) {
    countMap[s.scene_detail] = (countMap[s.scene_detail] ?? 0) + 1;
  }
  const candidates = Object.entries(countMap)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 3)
    .map(([name, count]) => ({ name, count }));

  // 3. Seed + ledger
  const [seed, ledger] = await Promise.all([
    assembleSeed(userId, sceneCategory),
    assembleLedger(userId, sceneCategory),
  ]);

  // 4. Build OPENING payload
  const categoryLabel = CATEGORY_LABELS[sceneCategory] ?? sceneCategory;
  const payload = {
    mode: "OPENING",
    languages: { target: "en", native: "zh" },
    topic: { category: categoryLabel, scene_detail: null, candidates },
    seed,
    ledger,
    history: [],
    user_utterance: null,
    asr_confidence: null,
    output_schema: {
      reply: "string — narrowing question, ≤2 sentences ≤30 words",
      scene_detail: "null (always null in OPENING mode)",
      current_topic: "string",
      used_entries: "[]",
      new_expressions: "[]",
      correctness: { ok: true, issues: [] },
      suggestions: "array of { lemma, hint } from ledger",
    },
  };

  // 5. Call Gemini
  let geminiReply: { reply: string; suggestions?: Array<{ lemma: string; hint: string }> };
  try {
    geminiReply = await callGemini(payload) as typeof geminiReply;
  } catch (e) {
    console.error("[dialogue/start] Gemini failed:", e);
    return json({ error: "ai_failed" }, 502);
  }

  const reply = geminiReply.reply ?? "";
  const suggestions = geminiReply.suggestions ?? [];

  // 6. Insert opening AI turn
  await dbPost("dialogue_turns", {
    session_id: sessionId,
    user_id: userId,
    role: "assistant",
    text: reply,
  });

  return json({ session_id: sessionId, reply, suggestions });
}

// ─────────────────────────────────────────────────────────────
// action = "turn"
// ─────────────────────────────────────────────────────────────

async function handleTurn(
  userId: string,
  sessionId: string,
  turnId: string,
  text: string,
): Promise<Response> {
  if (!sessionId || !text) return json({ error: "missing_params" }, 400);

  // 1. Validate session ownership
  const sessions = await dbGet(
    `dialogue_sessions?id=eq.${sessionId}&select=user_id,scene_category,scene_detail,turn_count`
  ) as Array<{ user_id: string; scene_category: string; scene_detail: string | null; turn_count: number }>;

  if (sessions.length === 0) return json({ error: "session_not_found" }, 404);
  const session = sessions[0];
  if (session.user_id !== userId) return json({ error: "forbidden" }, 403);

  // 2. Idempotency — if turn_id already processed, return the cached AI reply
  if (turnId) {
    const existing = await dbGet(
      `dialogue_turns?turn_id=eq.${encodeURIComponent(turnId)}&select=id,created_at&limit=1`
    ) as Array<{ id: string; created_at: string }>;

    if (existing.length > 0) {
      const aiTurns = await dbGet(
        `dialogue_turns?session_id=eq.${sessionId}&role=eq.assistant&created_at=gt.${encodeURIComponent(existing[0].created_at)}&order=created_at.asc&limit=1&select=text`
      ) as Array<{ text: string }>;

      if (aiTurns.length > 0) {
        return json({ reply: aiTurns[0].text, suggestions: [], scene_detail: null });
      }
      // AI reply not yet persisted — fall through to regenerate
    }
  }

  // 3. History — last 6 turns, chronological
  const turnRows = await dbGet(
    `dialogue_turns?session_id=eq.${sessionId}&select=role,text&order=created_at.desc&limit=6`
  ) as Array<{ role: string; text: string }>;
  const history = [...turnRows].reverse().map(t => ({ role: t.role, text: t.text ?? "" }));

  // 4. Seed + ledger
  const [seed, ledger] = await Promise.all([
    assembleSeed(userId, session.scene_category),
    assembleLedger(userId, session.scene_category),
  ]);

  // 5. Build TURN payload
  const categoryLabel = CATEGORY_LABELS[session.scene_category] ?? session.scene_category;
  const isFirstTurn = (session.turn_count ?? 0) === 0;
  const payload = {
    mode: "TURN",
    languages: { target: "en", native: "zh" },
    topic: { category: categoryLabel, scene_detail: session.scene_detail ?? null, candidates: [] },
    seed,
    ledger,
    history,
    user_utterance: text,
    asr_confidence: null,
    output_schema: {
      reply: "string — ≤2 sentences ≤30 words, target language only",
      scene_detail: isFirstTurn
        ? "string | null — which sub-scene did user pick; null if they chose freely"
        : "null — only populated on first turn",
      current_topic: "string",
      used_entries: "string[] — lemmas from ledger the user said this turn",
      new_expressions: "array of { lemma, display_form, kind }",
      correctness: "{ ok: bool, issues: [{ aspect, said, suggested, note }] }",
      suggestions: "array of { lemma, hint } — at most 3 from ledger",
    },
  };

  // 6. Call Gemini
  let geminiReply: {
    reply: string;
    scene_detail?: string | null;
    suggestions?: Array<{ lemma: string; hint: string }>;
    used_entries?: string[];
  };
  try {
    geminiReply = await callGemini(payload) as typeof geminiReply;
  } catch (e) {
    console.error("[dialogue/turn] Gemini failed:", e);
    return json({ error: "ai_failed" }, 502);
  }

  const reply = geminiReply.reply ?? "";
  const suggestions = geminiReply.suggestions ?? [];

  // 7. Validate used_entries — lemma must appear in user utterance to prevent false spoken_count inflation
  const userTextLower = text.toLowerCase();
  const validatedUsedEntries = (geminiReply.used_entries ?? []).filter(lemma =>
    lemma.toLowerCase().split(/\s+/).some(word => userTextLower.includes(word))
  );
  console.log("[dialogue/turn] used_entries validated:", validatedUsedEntries);

  // 8. Determine scene_detail update (first turn only)
  const newSceneDetail = isFirstTurn ? (geminiReply.scene_detail ?? null) : null;

  // 9. Persist turns + update session (errors here don't fail the response)
  try {
    const wordCount = text.trim().split(/\s+/).filter(Boolean).length;
    // last_turn_at 用插入行返回的 DB 侧 created_at：与 turn 行时间完全一致
    // （不用客户端时钟），且用户轮次插入失败时天然不更新（undefined 被 JSON 丢弃）。
    const userTurnRows = await dbPost("dialogue_turns", {
      turn_id: turnId || null,
      session_id: sessionId,
      user_id: userId,
      role: "user",
      text,
      word_count: wordCount,
    });
    await dbPost("dialogue_turns", {
      session_id: sessionId,
      user_id: userId,
      role: "assistant",
      text: reply,
    });
    const updateBody: Record<string, unknown> = {
      turn_count: (session.turn_count ?? 0) + 1,
      last_turn_at: (userTurnRows[0] as Record<string, unknown> | undefined)?.created_at,
    };
    if (newSceneDetail !== null) updateBody.scene_detail = newSceneDetail;
    await dbPatch(`dialogue_sessions?id=eq.${sessionId}`, updateBody);
  } catch (e) {
    console.error("[dialogue/turn] DB write failed (reply still returned):", e);
  }

  return json({ reply, suggestions, scene_detail: newSceneDetail });
}

// ─────────────────────────────────────────────────────────────
// action = "fallback"
// ─────────────────────────────────────────────────────────────

async function handleFallback(
  userId: string,
  sessionId: string,
  text: string,
): Promise<Response> {
  if (!sessionId || !text) return json({ error: "missing_params" }, 400);

  // Validate session ownership
  const sessions = await dbGet(
    `dialogue_sessions?id=eq.${sessionId}&select=user_id`
  ) as Array<{ user_id: string }>;
  if (sessions.length === 0) return json({ error: "session_not_found" }, 404);
  if (sessions[0].user_id !== userId) return json({ error: "forbidden" }, 403);

  const payload = {
    mode: "FALLBACK",
    languages: { target: "en", native: "zh" },
    user_utterance: text,
    output_schema: {
      translation: "string — natural target-language version of what they said",
      key_words: "array of { word: string, phonetic: string } — at most 2 genuinely hard words",
      hint: "string — neutral nudge, e.g. 'Try saying it.'",
    },
  };

  let geminiReply: {
    translation: string;
    key_words?: Array<{ word: string; phonetic: string }>;
    hint?: string;
  };
  try {
    geminiReply = await callGemini(payload) as typeof geminiReply;
  } catch (e) {
    console.error("[dialogue/fallback] Gemini failed:", e);
    return json({ error: "ai_failed" }, 502);
  }

  return json({
    translation: geminiReply.translation ?? "",
    key_words: geminiReply.key_words ?? [],
    hint: geminiReply.hint ?? "Try saying it.",
  });
}

// ─────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!SUPABASE_URL || !SUPABASE_SVC_KEY || !GEMINI_API_KEY) {
    return json({ error: "missing_config" }, 500);
  }

  const userId = await getAuthUserId(req);
  if (!userId) return json({ error: "unauthorized" }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const action = body.action as string | undefined;
  try {
    switch (action) {
      case "start":
        return handleStart(userId, body.scene_category as string);
      case "turn":
        return handleTurn(
          userId,
          body.session_id as string,
          body.turn_id as string ?? "",
          body.text as string,
        );
      case "fallback":
        return handleFallback(
          userId,
          body.session_id as string,
          body.text as string,
        );
      default:
        return json({ error: "unknown_action", action }, 400);
    }
  } catch (e) {
    console.error(`[dialogue/${action}] unhandled error:`, e);
    return json({ error: "internal_error" }, 500);
  }
});
