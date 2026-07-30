// Slice 2 · lexicon 规范化单元测试
// 运行：deno test supabase/functions/_shared/lexicon_test.ts
//
// 覆盖 PRD §5.1.2–5.1.3 & §5.2.1 的验收标准：
//   · "meetings" 和 "meeting" 归一为同一 lemma
//   · the / is 不入账（被停用词过滤）
//   · "invoice" → tier=domain；"make" → tier=framework

import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import {
  lemmatizeBasic,
  normalizeLemma,
  getTier,
  LEXICON_STOPWORDS,
} from './lexicon.ts';

// ── lemmatizeBasic ──────────────────────────────────────────

Deno.test('lemmatizeBasic: -ings → -ing（核心验收标准）', () => {
  assertEquals(lemmatizeBasic('meetings'), 'meeting');
  assertEquals(lemmatizeBasic('buildings'), 'building');
  assertEquals(lemmatizeBasic('settings'), 'setting');
  assertEquals(lemmatizeBasic('feelings'), 'feeling');
});

Deno.test('lemmatizeBasic: 所有格去掉 \'s', () => {
  assertEquals(lemmatizeBasic("company's"), 'company');
  assertEquals(lemmatizeBasic('user’s'), 'user');  // 右单引号 '
});

Deno.test('lemmatizeBasic: 短词不破坏（守卫 len > 5）', () => {
  // "sings" 是独立单词，len=5，不应被还原
  assertEquals(lemmatizeBasic('sings'), 'sings');
  // "kings" len=5，同理
  assertEquals(lemmatizeBasic('kings'), 'kings');
});

Deno.test('lemmatizeBasic: 无屈折的词原样返回', () => {
  assertEquals(lemmatizeBasic('invoice'), 'invoice');
  assertEquals(lemmatizeBasic('set up'), 'set up');
  assertEquals(lemmatizeBasic('running'), 'running');  // -ing 不是 -ings，不还原
});

// ── normalizeLemma ──────────────────────────────────────────

Deno.test('normalizeLemma: meetings 和 meeting 归一（核心验收标准）', () => {
  assertEquals(normalizeLemma('meetings'), 'meeting');
  assertEquals(normalizeLemma('meeting'), 'meeting');
  assertEquals(normalizeLemma('Meetings'), 'meeting');
  assertEquals(normalizeLemma('MEETING'), 'meeting');
});

Deno.test('normalizeLemma: 去首尾标点和空白', () => {
  assertEquals(normalizeLemma('  set up  '), 'set up');
  assertEquals(normalizeLemma('"invoice"'), 'invoice');
  assertEquals(normalizeLemma('...make...'), 'make');
});

Deno.test('normalizeLemma: 折叠内部空白', () => {
  assertEquals(normalizeLemma('set  up'), 'set up');
});

Deno.test('normalizeLemma: 非字符串输入返回 null', () => {
  assertEquals(normalizeLemma(null), null);
  assertEquals(normalizeLemma(undefined), null);
  assertEquals(normalizeLemma(42), null);
  assertEquals(normalizeLemma(''), null);
  assertEquals(normalizeLemma('  '), null);
});

// ── getTier ────────────────────────────────────────────────

Deno.test('getTier: 核心验收标准 — make=framework, invoice=domain', () => {
  assertEquals(getTier('make'), 'framework');
  assertEquals(getTier('invoice'), 'domain');
});

Deno.test('getTier: 常见框架动词 → framework', () => {
  for (const w of ['get', 'set', 'run', 'work', 'try', 'find', 'help']) {
    assertEquals(getTier(w), 'framework', `expected '${w}' to be framework`);
  }
});

Deno.test('getTier: 常用短语动词 → framework', () => {
  assertEquals(getTier('set up'), 'framework');
  assertEquals(getTier('figure out'), 'framework');
  assertEquals(getTier('deal with'), 'framework');
});

Deno.test('getTier: 专业/场景词 → domain', () => {
  for (const w of ['invoice', 'marinate', 'proxy', 'subnet', 'deductible']) {
    assertEquals(getTier(w), 'domain', `expected '${w}' to be domain`);
  }
});

// ── LEXICON_STOPWORDS ───────────────────────────────────────

Deno.test('LEXICON_STOPWORDS: the / is 被过滤（核心验收标准）', () => {
  assertEquals(LEXICON_STOPWORDS.has('the'), true);
  assertEquals(LEXICON_STOPWORDS.has('is'), true);
});

Deno.test('LEXICON_STOPWORDS: 各类功能词都在停用词里', () => {
  const mustBeStopwords = [
    // 介词
    'of', 'to', 'in', 'on', 'for', 'with', 'from', 'about', 'between',
    // 连词
    'and', 'or', 'but', 'because', 'while', 'although',
    // 代词
    'i', 'you', 'he', 'she', 'they', 'it', 'my', 'their',
    // 助动词
    'will', 'would', 'should', 'can', 'could', 'must', 'have', 'had',
    // 限定词
    'any', 'some', 'all', 'each', 'every', 'many', 'much', 'most',
  ];
  for (const w of mustBeStopwords) {
    assertEquals(LEXICON_STOPWORDS.has(w), true, `expected '${w}' to be a stopword`);
  }
});

Deno.test('LEXICON_STOPWORDS: 可学词不在停用词里', () => {
  const notStopwords = ['invoice', 'make', 'set up', 'brilliant', 'completely drained'];
  for (const w of notStopwords) {
    assertEquals(LEXICON_STOPWORDS.has(w), false, `'${w}' should NOT be a stopword`);
  }
});
