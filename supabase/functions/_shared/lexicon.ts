// Slice 2 · 账本规范化工具（可测试的纯函数层）。
// generate/index.ts 的 Stage 3 和未来的补账作业都从这里 import。
// 无任何 Deno API 依赖，可在 deno test 里直接测试。

// ── 停用词表（§5.1.3）──
// prompt 的 NEVER extract 已过滤一遍；这里再挡一层。
// 流水只增不改、脏了洗不掉，多过滤一遍成本近乎为零。
export const LEXICON_STOPWORDS = new Set<string>([
  // 冠词 / 指示词
  'the', 'a', 'an', 'this', 'that', 'these', 'those',
  // be 动词
  'be', 'is', 'are', 'was', 'were', 'been', 'being', 'am',
  // 助动词
  'do', 'does', 'did', 'have', 'has', 'had',
  'will', 'would', 'shall', 'should', 'can', 'could',
  'may', 'might', 'must', 'need', 'ought',
  // 介词
  'of', 'to', 'in', 'on', 'at', 'for', 'with', 'from',
  'about', 'above', 'across', 'after', 'against', 'along',
  'among', 'around', 'as', 'before', 'behind', 'below',
  'beside', 'between', 'by', 'despite', 'down', 'during',
  'except', 'into', 'near', 'off', 'out', 'outside', 'over',
  'past', 'since', 'than', 'through', 'throughout', 'till',
  'toward', 'under', 'until', 'up', 'upon', 'via',
  'within', 'without', 'like', 'per',
  // 连词
  'and', 'or', 'but', 'if', 'so', 'nor',
  'because', 'when', 'while', 'although', 'whether',
  'though', 'unless', 'since', 'whereas', 'either',
  // 人称代词
  'i', 'you', 'he', 'she', 'we', 'they',
  'me', 'him', 'her', 'us', 'them',
  'my', 'your', 'his', 'our', 'their', 'its',
  'mine', 'yours', 'hers', 'ours', 'theirs', 'itself',
  'myself', 'yourself', 'himself', 'herself', 'ourselves', 'themselves',
  // 关系 / 疑问代词
  'it', 'who', 'whom', 'which', 'what', 'whose',
  'whoever', 'whatever', 'wherever', 'whenever', 'however',
  // 限定词
  'any', 'some', 'all', 'each', 'every', 'both', 'neither',
  'no', 'much', 'many', 'few', 'more', 'most', 'less', 'least',
  'another', 'other', 'such', 'same',
  // 副词 / 连接副词
  'not', 'also', 'then', 'now', 'here', 'there',
  'where', 'how', 'why', 'yet', 'too', 'very', 'quite',
  'just', 'only', 'even', 'still', 'already', 'once', 'twice',
  'then', 'thus', 'hence', 'therefore', 'furthermore', 'moreover',
  'otherwise', 'nevertheless', 'nonetheless', 'instead', 'meanwhile',
]);

// ── 框架词表（§5.2.1）──
// 来源：NGSL 前 1000 高频词中跨话题通用的词；逐条人工确认是否 cross-topic。
// 凡在此集合中的词 → tier='framework'；其余 → tier='domain'。
// 包含单词和常见短语动词（phrasal verbs 在账本里以完整形式存储）。
export const FRAMEWORK_LEMMAS = new Set<string>([
  // 核心动词
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
  // 常见形容词
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
  // 常见副词
  'well', 'back', 'even', 'still', 'also', 'always', 'often',
  'never', 'sometimes', 'probably', 'really', 'quite', 'though',
  'almost', 'soon', 'around', 'again', 'together', 'away', 'ahead',
  'actually', 'finally', 'quickly', 'slowly', 'directly', 'easily',
  'exactly', 'immediately', 'mainly', 'mostly', 'nearly', 'normally',
  'obviously', 'officially', 'originally', 'particularly', 'recently',
  'seriously', 'simply', 'slightly', 'suddenly', 'usually', 'clearly',
  'completely', 'correctly', 'currently', 'definitely', 'effectively',
  'especially', 'generally', 'largely', 'literally', 'locally',
  // 常见短语动词（跨话题通用）
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
  // 跨话题通用名词（只收"任何话题都可能出现"的概念）
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

// ── 轻量词形还原（§5.1.3 "MVP 用轻量规则 + AI 顺带给原形"）──
// 只处理 AI 偶发输出屈折形式的两类情况；语言学完整性靠 prompt（"base form"）保证。
export function lemmatizeBasic(s: string): string {
  // 所有格 "company's" → "company"
  if (s.endsWith("'s") || s.endsWith('’s')) return s.slice(0, -2);
  // -ings → -ing（meetings → meeting；buildings → building）
  // 守卫：len > 5 避免意外破坏 "sings" 等本来就是独立词的词
  if (s.endsWith('ings') && s.length > 5) return s.slice(0, -1);
  return s;
}

// 小写 + 词形还原 + 折叠空白 + 去首尾非字母数字。空则返回 null。
export function normalizeLemma(form: unknown): string | null {
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

// 静态词表判 tier（§5.2.1）：在列表里 → framework；否则 → domain。
export function getTier(lemma: string): 'framework' | 'domain' {
  return FRAMEWORK_LEMMAS.has(lemma) ? 'framework' : 'domain';
}
