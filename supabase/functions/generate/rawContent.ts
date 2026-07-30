// rawContent.ts — 纯函数：AI card_content → 落库 raw_content
// 独立模块，便于单元测试（index.ts 含 Deno.serve() 无法直接 import 测试）。

export interface LearnableUnit {
  form: string;
  kind: string;
  note: string;
  is_primary: boolean;
}

export interface UnifiedRawContent {
  granularity?: string;
  direction?: string;
  revision_type?: string | null;
  learnable_units?: LearnableUnit[];
  user_original: string | null;
  input_lang?: string | null;
  input_lang_code?: string | null;
  intent?: string | null;
  target_expression: string | null;
  native_meaning?: string | null;
  phonetic?: string | null;
  pos?: string[];
  examples?: { en: string; zh: string }[];
  grammar_note?: string | null;
  passage_lines?: { en: string; zh: string }[];
  source_image_path: string | null;
}

export const asStr = (v: unknown): string | null =>
  typeof v === 'string' && v.length > 0 ? v : null;

/**
 * 把 AI 返回的统一 card_content 落成统一 raw_content。
 * material_type 由 granularity 决定（word→vocabulary、sentence/passage→scene）。
 * granularity 缺失时按 cardType 兜底（s1/s3→word、s5/s6→passage、其余→sentence）。
 */
export function buildRawContent(
  cardType: string,
  content: Record<string, unknown>,
  userText: string,
  sourceImageUrl: string | null,
): { materialType: 'scene' | 'vocabulary'; rawContent: UnifiedRawContent } | null {
  if (!['s1', 's2', 's3', 's4', 's5', 's6'].includes(cardType)) {
    return null;
  }

  const granularity =
    asStr(content.granularity) ??
    (cardType === 's1' || cardType === 's3'
      ? 'word'
      : cardType === 's5' || cardType === 's6'
      ? 'passage'
      : 'sentence');

  const materialType: 'scene' | 'vocabulary' =
    granularity === 'word' ? 'vocabulary' : 'scene';

  const units = content.learnable_units;
  const examples = Array.isArray(content.examples)
    ? (content.examples as Array<{ en?: unknown; zh?: unknown }>).map(e => ({
        en: String(e?.en ?? ''),
        zh: String(e?.zh ?? ''),
      }))
    : [];

  const pos = Array.isArray(content.pos)
    ? (content.pos as unknown[]).map(String)
    : asStr(content.pos)
    ? [String(content.pos)]
    : [];

  const passageLines = Array.isArray(content.passage_lines)
    ? (content.passage_lines as Array<{ en?: unknown; zh?: unknown }>).map(l => ({
        en: String(l?.en ?? ''),
        zh: String(l?.zh ?? ''),
      }))
    : [];

  const userOriginal =
    asStr(content.user_original) ?? (userText.trim() ? userText.trim() : null);

  const rawContent: UnifiedRawContent = {
    granularity,
    direction:
      asStr(content.direction) ??
      (cardType === 's1' || cardType === 's2' || cardType === 's5'
        ? 'comprehend'
        : 'express'),
    revision_type: asStr(content.revision_type),
    learnable_units: Array.isArray(units) ? (units as LearnableUnit[]) : [],
    user_original: userOriginal,
    input_lang: asStr(content.input_lang),
    input_lang_code: asStr(content.input_lang_code),
    intent: asStr(content.intent),
    target_expression: asStr(content.target_expression),
    native_meaning: asStr(content.native_meaning),
    phonetic: asStr(content.phonetic),
    pos,
    examples,
    grammar_note: asStr(content.grammar_note),
    passage_lines: passageLines.length > 0 ? passageLines : undefined,
    source_image_path: sourceImageUrl,
  };

  return { materialType, rawContent };
}
