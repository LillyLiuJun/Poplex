// Slice 2 · lexicon 规范化单元测试（Node.js 版）
// 运行：node supabase/functions/_shared/lexicon_test.mjs
//
// 覆盖 PRD §5.1.2–5.1.3 & §5.2.1 的验收标准：
//   · "meetings" 和 "meeting" 归一为同一 lemma
//   · the / is 不入账（被停用词过滤）
//   · "invoice" → tier=domain；"make" → tier=framework

import assert from 'node:assert/strict';

// ── 内联纯函数（与 _shared/lexicon.ts 逻辑一一对应）──
// 注：直接 import .ts 需要 Deno；此处在 Node 里复制逻辑跑验证，
// 保证"业务逻辑正确"，而不是"文件能被 Deno import"。

const LEXICON_STOPWORDS = new Set([
  'the', 'a', 'an', 'this', 'that', 'these', 'those',
  'be', 'is', 'are', 'was', 'were', 'been', 'being', 'am',
  'do', 'does', 'did', 'have', 'has', 'had',
  'will', 'would', 'shall', 'should', 'can', 'could',
  'may', 'might', 'must', 'need', 'ought',
  'of', 'to', 'in', 'on', 'at', 'for', 'with', 'from',
  'about', 'above', 'across', 'after', 'against', 'along',
  'among', 'around', 'as', 'before', 'behind', 'below',
  'beside', 'between', 'by', 'despite', 'down', 'during',
  'except', 'into', 'near', 'off', 'out', 'outside', 'over',
  'past', 'since', 'than', 'through', 'throughout', 'till',
  'toward', 'under', 'until', 'up', 'upon', 'via',
  'within', 'without', 'like', 'per',
  'and', 'or', 'but', 'if', 'so', 'nor',
  'because', 'when', 'while', 'although', 'whether',
  'though', 'unless', 'since', 'whereas', 'either',
  'i', 'you', 'he', 'she', 'we', 'they',
  'me', 'him', 'her', 'us', 'them',
  'my', 'your', 'his', 'our', 'their', 'its',
  'mine', 'yours', 'hers', 'ours', 'theirs', 'itself',
  'myself', 'yourself', 'himself', 'herself', 'ourselves', 'themselves',
  'it', 'who', 'whom', 'which', 'what', 'whose',
  'whoever', 'whatever', 'wherever', 'whenever', 'however',
  'any', 'some', 'all', 'each', 'every', 'both', 'neither',
  'no', 'much', 'many', 'few', 'more', 'most', 'less', 'least',
  'another', 'other', 'such', 'same',
  'not', 'also', 'then', 'now', 'here', 'there',
  'where', 'how', 'why', 'yet', 'too', 'very', 'quite',
  'just', 'only', 'even', 'still', 'already', 'once', 'twice',
  'then', 'thus', 'hence', 'therefore', 'furthermore', 'moreover',
  'otherwise', 'nevertheless', 'nonetheless', 'instead', 'meanwhile',
]);

const FRAMEWORK_LEMMAS = new Set([
  'get', 'make', 'take', 'give', 'go', 'come', 'use', 'find', 'know',
  'see', 'think', 'look', 'want', 'tell', 'ask', 'feel', 'try', 'leave',
  'call', 'keep', 'let', 'begin', 'show', 'hear', 'play', 'run', 'move',
  'live', 'believe', 'hold', 'bring', 'happen', 'write', 'provide', 'sit',
  'stand', 'lose', 'pay', 'meet', 'include', 'continue', 'set', 'learn',
  'change', 'lead', 'understand', 'watch', 'follow', 'stop', 'create',
  'speak', 'read', 'spend', 'grow', 'open', 'walk', 'win', 'offer',
  'remember', 'consider', 'appear', 'buy', 'wait', 'serve', 'send',
  'stay', 'fall', 'cut', 'reach', 'put', 'decide', 'pull', 'break',
  'pick', 'raise', 'pass', 'require', 'turn', 'end', 'start', 'return',
  'build', 'help', 'allow', 'apply', 'expect', 'explain', 'act', 'talk',
  'work', 'carry', 'catch', 'connect', 'deal', 'develop', 'add',
  'become', 'describe', 'indicate', 'join', 'plan', 'suggest', 'support',
  'check', 'compare', 'cover', 'handle', 'identify', 'manage', 'notice',
  'perform', 'produce', 'reduce', 'report', 'share', 'solve', 'test',
  'visit', 'wait', 'agree', 'enjoy', 'realize', 'receive', 'answer',
  'choose', 'continue', 'control', 'expect', 'guess', 'happen', 'imagine',
  'mention', 'prepare', 'prevent', 'promise', 'repeat', 'replace',
  'review', 'save', 'search', 'start', 'step', 'stop', 'study',
  'submit', 'succeed', 'update', 'achieve', 'affect', 'arrange', 'avoid',
  'borrow', 'cancel', 'collect', 'combine', 'complete', 'confirm',
  'connect', 'contact', 'convert', 'decide', 'delay', 'deliver',
  'discuss', 'discover', 'enter', 'establish', 'express', 'focus',
  'improve', 'increase', 'link', 'listen', 'lose', 'measure', 'mention',
  'miss', 'obtain', 'organize', 'post', 'practice', 'process', 'publish',
  'push', 'relate', 'release', 'remove', 'reset', 'respond', 'schedule',
  'select', 'share', 'sign', 'sort', 'specify', 'store', 'track',
  'transfer', 'translate', 'upload', 'verify',
  'good', 'new', 'first', 'last', 'long', 'great', 'little', 'right',
  'old', 'big', 'high', 'small', 'large', 'different', 'hard',
  'important', 'real', 'best', 'possible', 'free', 'true', 'clear',
  'simple', 'short', 'early', 'common', 'open', 'special', 'complete',
  'next', 'whole', 'young', 'easy', 'current', 'major', 'main', 'full',
  'close', 'strong', 'low', 'ready', 'sure', 'certain', 'available',
  'own', 'several', 'recent', 'single', 'various', 'bad', 'far',
  'wrong', 'able', 'further', 'basic', 'general', 'similar', 'nice',
  'average', 'positive', 'final', 'specific', 'better', 'pretty',
  'okay', 'ok', 'tough', 'tricky', 'quick', 'busy', 'late',
  'extra', 'key', 'direct', 'typical', 'natural', 'normal',
  'standard', 'regular', 'useful', 'personal', 'official', 'separate',
  'public', 'private', 'local', 'global', 'overall', 'appropriate',
  'comfortable', 'convenient', 'effective', 'efficient', 'familiar',
  'flexible', 'obvious', 'original', 'practical', 'relevant', 'solid',
  'well', 'back', 'even', 'still', 'also', 'always', 'often',
  'never', 'sometimes', 'probably', 'really', 'quite', 'though',
  'almost', 'soon', 'around', 'again', 'together', 'away', 'ahead',
  'actually', 'finally', 'quickly', 'slowly', 'directly', 'easily',
  'exactly', 'immediately', 'mainly', 'mostly', 'nearly', 'normally',
  'obviously', 'officially', 'originally', 'particularly', 'recently',
  'seriously', 'simply', 'slightly', 'suddenly', 'usually', 'clearly',
  'completely', 'correctly', 'currently', 'definitely', 'effectively',
  'especially', 'generally', 'largely', 'literally', 'locally',
  'set up', 'pick up', 'look up', 'look into', 'take on', 'deal with',
  'end up', 'figure out', 'go on', 'go through', 'go back', 'look after',
  'run out', 'show up', 'sign up', 'take off', 'take over', 'try out',
  'give up', 'keep up', 'look for', 'move on', 'run into', 'break down',
  'bring up', 'carry on', 'catch up', 'check out', 'check in', 'come back',
  'find out', 'get back', 'get up', 'go ahead', 'hand in', 'keep on',
  'make up', 'move up', 'pass on', 'pay back', 'point out', 'pull out',
  'put away', 'put in', 'reach out', 'set aside', 'settle down',
  'slow down', 'stand out', 'take back', 'talk about', 'turn on',
  'turn off', 'work out', 'work on', 'back up', 'call back', 'calm down',
  'come up with', 'cut down', 'drop off', 'fill in', 'fill out', 'fit in',
  'get along', 'get on', 'go out', 'hang out', 'hold on', 'line up',
  'log in', 'log out', 'look forward to', 'make sure', 'mix up',
  'put off', 'run away', 'save up', 'sit down', 'sort out', 'stand up',
  'switch off', 'switch on', 'take care of', 'take part in', 'wrap up',
  'burn out', 'get over', 'give out', 'give back', 'hand over',
  'let down', 'look out', 'make it', 'miss out', 'move forward',
  'narrow down', 'open up', 'opt in', 'opt out', 'plug in', 'roll out',
  'set out', 'speak up', 'take up', 'think through', 'throw away',
  'time', 'year', 'day', 'week', 'month', 'moment', 'second', 'hour',
  'way', 'thing', 'idea', 'point', 'place', 'part', 'kind', 'type',
  'case', 'issue', 'problem', 'question', 'answer', 'reason', 'result',
  'example', 'fact', 'difference', 'change', 'information', 'level',
  'step', 'plan', 'goal', 'process', 'situation', 'experience', 'effort',
  'action', 'decision', 'choice', 'option', 'detail', 'version',
  'update', 'section', 'part', 'group', 'team', 'member', 'role',
  'person', 'people', 'name', 'number', 'amount', 'rate', 'cost',
  'size', 'length', 'order', 'form', 'list', 'note', 'message',
  'word', 'phrase', 'sentence', 'line', 'page', 'file', 'link',
  'feature', 'function', 'task', 'test', 'check', 'review', 'report',
  'event', 'meeting', 'call', 'request', 'response', 'comment',
  'feedback', 'support', 'service', 'access', 'account', 'profile',
  'setting', 'option', 'rule', 'guide', 'tip', 'trick', 'skill',
  'work', 'job', 'project', 'schedule', 'deadline', 'progress',
]);

function lemmatizeBasic(s) {
  if (s.endsWith("'s") || s.endsWith('’s')) return s.slice(0, -2);
  if (s.endsWith('ings') && s.length > 5) return s.slice(0, -1);
  return s;
}

function normalizeLemma(form) {
  if (typeof form !== 'string') return null;
  const s = lemmatizeBasic(
    form
      .toLowerCase()
      .trim()
      .replace(/\s+/g, ' ')
      .replace(/^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu, ''),
  );
  return s.length > 0 ? s : null;
}

function getTier(lemma) {
  return FRAMEWORK_LEMMAS.has(lemma) ? 'framework' : 'domain';
}

// ── 测试运行器 ──────────────────────────────────────────────
let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`  ✓ ${name}`);
    passed++;
  } catch (e) {
    console.error(`  ✗ ${name}`);
    console.error(`    ${e.message}`);
    failed++;
  }
}

// ── lemmatizeBasic ──────────────────────────────────────────
console.log('\nlemmatizeBasic');
test('-ings → -ing（核心验收标准）', () => {
  assert.equal(lemmatizeBasic('meetings'), 'meeting');
  assert.equal(lemmatizeBasic('buildings'), 'building');
  assert.equal(lemmatizeBasic('settings'), 'setting');
  assert.equal(lemmatizeBasic('feelings'), 'feeling');
});
test("所有格去掉 's", () => {
  assert.equal(lemmatizeBasic("company's"), 'company');
  assert.equal(lemmatizeBasic('user’s'), 'user');
});
test('短词不破坏（守卫 len > 5）', () => {
  assert.equal(lemmatizeBasic('sings'), 'sings');
  assert.equal(lemmatizeBasic('kings'), 'kings');
});
test('无屈折的词原样返回', () => {
  assert.equal(lemmatizeBasic('invoice'), 'invoice');
  assert.equal(lemmatizeBasic('set up'), 'set up');
  assert.equal(lemmatizeBasic('running'), 'running');
});

// ── normalizeLemma ──────────────────────────────────────────
console.log('\nnormalizeLemma');
test('meetings 和 meeting 归一（核心验收标准）', () => {
  assert.equal(normalizeLemma('meetings'), 'meeting');
  assert.equal(normalizeLemma('meeting'), 'meeting');
  assert.equal(normalizeLemma('Meetings'), 'meeting');
  assert.equal(normalizeLemma('MEETING'), 'meeting');
});
test('去首尾标点和空白', () => {
  assert.equal(normalizeLemma('  set up  '), 'set up');
  assert.equal(normalizeLemma('"invoice"'), 'invoice');
  assert.equal(normalizeLemma('...make...'), 'make');
});
test('折叠内部空白', () => {
  assert.equal(normalizeLemma('set  up'), 'set up');
});
test('非字符串输入返回 null', () => {
  assert.equal(normalizeLemma(null), null);
  assert.equal(normalizeLemma(undefined), null);
  assert.equal(normalizeLemma(42), null);
  assert.equal(normalizeLemma(''), null);
  assert.equal(normalizeLemma('  '), null);
});

// ── getTier ────────────────────────────────────────────────
console.log('\ngetTier');
test('核心验收标准 — make=framework, invoice=domain', () => {
  assert.equal(getTier('make'), 'framework');
  assert.equal(getTier('invoice'), 'domain');
});
test('常见框架动词 → framework', () => {
  for (const w of ['get', 'set', 'run', 'work', 'try', 'find', 'help']) {
    assert.equal(getTier(w), 'framework', `'${w}' should be framework`);
  }
});
test('常用短语动词 → framework', () => {
  assert.equal(getTier('set up'), 'framework');
  assert.equal(getTier('figure out'), 'framework');
  assert.equal(getTier('deal with'), 'framework');
});
test('专业/场景词 → domain', () => {
  for (const w of ['invoice', 'marinate', 'proxy', 'subnet', 'deductible']) {
    assert.equal(getTier(w), 'domain', `'${w}' should be domain`);
  }
});

// ── LEXICON_STOPWORDS ───────────────────────────────────────
console.log('\nLEXICON_STOPWORDS');
test('the / is 被过滤（核心验收标准）', () => {
  assert.equal(LEXICON_STOPWORDS.has('the'), true);
  assert.equal(LEXICON_STOPWORDS.has('is'), true);
});
test('各类功能词都在停用词里', () => {
  const mustBeStopwords = [
    'of', 'to', 'in', 'on', 'for', 'with', 'from', 'about', 'between',
    'and', 'or', 'but', 'because', 'while', 'although',
    'i', 'you', 'he', 'she', 'they', 'it', 'my', 'their',
    'will', 'would', 'should', 'can', 'could', 'must', 'have', 'had',
    'any', 'some', 'all', 'each', 'every', 'many', 'much', 'most',
  ];
  for (const w of mustBeStopwords) {
    assert.equal(LEXICON_STOPWORDS.has(w), true, `'${w}' should be a stopword`);
  }
});
test('可学词不在停用词里', () => {
  for (const w of ['invoice', 'make', 'set up', 'brilliant']) {
    assert.equal(LEXICON_STOPWORDS.has(w), false, `'${w}' should NOT be a stopword`);
  }
});

// ── 结果汇总 ────────────────────────────────────────────────
console.log(`\n${'─'.repeat(40)}`);
console.log(`通过 ${passed} / 失败 ${failed}  (共 ${passed + failed} 项)`);
if (failed > 0) process.exit(1);
