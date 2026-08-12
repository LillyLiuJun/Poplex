// Slice 1b · 补账作业 Edge Function（§5.3.1）
//
// 职责：扫描当前用户名下"有 material 但无 lexicon_occurrence"的素材，
//       重跑 Stage 3 记账逻辑，把遗漏的 occurrence 补进账本。
//
// 触发：手动 POST（Supabase Dashboard → Functions → backfill-lexicon → Invoke，
//       或 curl -X POST -H "Authorization: Bearer <user-jwt>" <fn-url>）。
// 安全：沿用既有范式——从 /auth/v1/user 验签取 uid；拿不到 uid 直接 401。
//
// 与 generate/index.ts Stage 3 的关系：
//   · 记账入口复用同一个 RPC（record_lexicon_material_units）
//   · 归一化逻辑复用同一个 _shared/lexicon.ts
//   · 区别在于数据来源：Stage 3 读当前 AI 输出；补账读 materials.raw_content

import { normalizeLemma, getTier, LEXICON_STOPWORDS } from '../_shared/lexicon.ts';

const SUPABASE_URL    = Deno.env.get('SUPABASE_URL')                 ?? '';
const SUPABASE_SVC_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')   ?? '';

const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

// raw_content 里我们只关心这几个字段（兼容 Unified 结构）。
interface RawContent {
  granularity?:      string | null;
  direction?:        string | null;
  input_lang?:       string | null;
  input_lang_code?:  string | null;
  intent?:           string | null;
  target_expression?: string | null;
  user_original?:    string | null;
  learnable_units?:  Array<{ form?: string; kind?: string }>;
}

interface Material {
  id:             string;
  user_id:        string;
  scene_category: string | null;
  raw_content:    RawContent;
}

// 与 generate/index.ts recordLexicon() 里完全相同的归一化 + tier 逻辑。
function buildUnits(raw: RawContent) {
  const rawUnits = Array.isArray(raw.learnable_units) ? raw.learnable_units : [];
  return rawUnits
    .map(u => {
      const lemma = normalizeLemma(u?.form);
      return {
        lemma,
        display_form: (typeof u?.form === 'string' ? u.form.trim() : '') || null,
        entry_kind:   (typeof u?.kind === 'string' ? u.kind   : '') || null,
        tier:         lemma ? getTier(lemma) : null,
      };
    })
    .filter(u => u.lemma && !LEXICON_STOPWORDS.has(u.lemma!));
}

async function recordForMaterial(material: Material): Promise<number> {
  const raw   = material.raw_content;
  const units = buildUnits(raw);
  if (units.length === 0) return 0;

  const sample = raw.target_expression ?? raw.user_original ?? null;

  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/record_lexicon_material_units`, {
    method: 'POST',
    headers: {
      'Content-Type':  'application/json',
      'Authorization': `Bearer ${SUPABASE_SVC_KEY}`,
      'apikey':        SUPABASE_SVC_KEY,
    },
    body: JSON.stringify({
      p_user_id:            material.user_id,
      p_source_id:          material.id,
      p_scene_category:     material.scene_category,
      p_scene_detail:       (material as any).scene_detail ?? null,
      p_input_lang:         raw.input_lang        ?? null,
      p_input_lang_code:    raw.input_lang_code   ?? null,
      p_source_granularity: raw.granularity        ?? null,
      p_source_direction:   raw.direction          ?? null,
      p_intent_text:        raw.intent             ?? null,
      p_intent_source:
        raw.input_lang === 'native' && raw.intent != null
          ? 'stated'
          : raw.user_original == null && raw.direction === 'express'
          ? 'inferred'
          : null,
      p_sample_sentence:    sample,
      p_units:              units,
    }),
  });

  if (!res.ok) {
    console.error(`[backfill] material ${material.id} rpc failed:`, await res.text());
    return 0;
  }
  return (await res.json()) as number;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405, headers: CORS });
  }

  // ── 验签 ────────────────────────────────────────────────
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/, '');
  if (!token) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401, headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const userRes = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    headers: { 'Authorization': `Bearer ${token}`, 'apikey': SUPABASE_SVC_KEY },
  });
  if (!userRes.ok) {
    return new Response(JSON.stringify({ error: 'unauthorized' }), {
      status: 401, headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }
  const { id: userId } = await userRes.json() as { id?: string };
  if (!userId) {
    return new Response(JSON.stringify({ error: 'no user' }), {
      status: 401, headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  // ── 找出未入账的素材 id ──────────────────────────────────
  const unaccountedRes = await fetch(
    `${SUPABASE_URL}/rest/v1/rpc/get_unaccounted_material_ids`,
    {
      method: 'POST',
      headers: {
        'Content-Type':  'application/json',
        'Authorization': `Bearer ${SUPABASE_SVC_KEY}`,
        'apikey':        SUPABASE_SVC_KEY,
      },
      body: JSON.stringify({ p_user_id: userId }),
    },
  );

  if (!unaccountedRes.ok) {
    const err = await unaccountedRes.text();
    console.error('[backfill] get_unaccounted_material_ids failed:', err);
    return new Response(JSON.stringify({ error: 'query failed', detail: err }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const unaccountedIds: string[] = await unaccountedRes.json();

  if (unaccountedIds.length === 0) {
    return new Response(
      JSON.stringify({ message: '所有素材已入账，无需补账', processed: 0, occurrences_created: 0 }),
      { headers: { ...CORS, 'Content-Type': 'application/json' } },
    );
  }

  // ── 拉素材全行 ────────────────────────────────────────────
  // PostgREST in(...) 语法：id=in.(uuid1,uuid2,...)
  const idList = unaccountedIds.join(',');
  const materialsRes = await fetch(
    `${SUPABASE_URL}/rest/v1/materials?id=in.(${idList})&select=id,user_id,scene_category,raw_content`,
    {
      headers: {
        'Authorization': `Bearer ${SUPABASE_SVC_KEY}`,
        'apikey':        SUPABASE_SVC_KEY,
      },
    },
  );

  if (!materialsRes.ok) {
    const err = await materialsRes.text();
    console.error('[backfill] fetch materials failed:', err);
    return new Response(JSON.stringify({ error: 'fetch materials failed', detail: err }), {
      status: 500, headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  const materials: Material[] = await materialsRes.json();

  // ── 逐条补账 ──────────────────────────────────────────────
  let processed          = 0;
  let occurrencesCreated = 0;
  const errors: string[] = [];

  for (const material of materials) {
    try {
      const n = await recordForMaterial(material);
      processed++;
      occurrencesCreated += n;
      console.log(`[backfill] material ${material.id}: +${n} occurrence(s)`);
    } catch (e) {
      const msg = `material ${material.id}: ${e}`;
      console.error('[backfill]', msg);
      errors.push(msg);
    }
  }

  return new Response(
    JSON.stringify({
      processed,
      occurrences_created: occurrencesCreated,
      skipped_no_units:    materials.length - processed,
      ...(errors.length > 0 && { errors }),
    }),
    { headers: { ...CORS, 'Content-Type': 'application/json' } },
  );
});
