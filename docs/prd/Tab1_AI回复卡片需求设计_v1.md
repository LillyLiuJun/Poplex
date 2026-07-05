# AI 回复卡片需求设计 v1.2

> 本文档在六层框架 Layer 3（功能结构）和 Layer 4（信息流转）范围内，完整定义 AI 回复卡片的内容规范、分类逻辑与工具链行为。
> 依赖文档：Page1_PRD_v1.md / IOS App-Language Learning 1.0.md / 待决策清单.md
> v1.2 更新：情境 2 改名为「句子分析」并更新输出规则；补充提示词 vs 代码的分工边界；新增 Chat 兜底模式；新增自指提取预处理步骤

---

## 一、五项决策完成

### 决策 1：工具链（翻译 / 语音 / 刷新）→ **采纳 B，细化各情境**

**决定：做翻译（折叠展开）+ 语音（iOS 系统 TTS），不做刷新**

决策理由：
- **翻译**：读的是已生成数据，零额外 AI 调用，最高频——用户随时需要确认自己理解正确
- **语音**：使用 iOS 原生 `AVSpeechSynthesizer`，免费、离线可用、延迟接近零；云端 TTS 等用户量稳定后再升级，同时 **Slice 3 的 Edge Function 可跳过，大幅简化 MVP 实现**
- **刷新**：需区分"换说法"还是"重试失败"两种完全不同的语义，逻辑重，且失败重试已有错误卡片处理，不额外做

各情境工具链明细：

| 情境 | 工具按钮 | 按钮位置 | 展开内容 | 语音朗读范围 |
|:---|:---|:---|:---|:---|
| 1（EN 词汇） | 语音（卡底）+ 翻译（例句行内） | 翻译按钮紧贴例句右侧 | 例句中译（行内展开） | 词条 + 第一条例句 |
| 2（EN 句子） | 语音（卡底）+ 翻译（卡底） | 翻译按钮在卡片底部 | 中文译义（插入原句正下方） | `native_polish`（有错误才有）；无则原句 |
| 3（ZH 词组） | 语音（卡底）| 卡底仅语音按钮 | — | 英文对标词/短语 + 例句 |
| 4（ZH 句子） | 语音（卡底）+ 翻译（卡底） | 翻译按钮在卡片底部 | 用户中文原意（插入英文主体正上方） | `native_translation` |

---

### 决策 2：追问上下文连续性 → **采纳 B**

**决定：只携带上一条消息作为上下文（最近 1 轮）**

决策理由：
- 核心体验"死党顺着你的话接住"需要最低限度的上下文，1 轮足够覆盖主路径
- 带 3~5 轮：成本和延迟翻倍，但真实追问超过 2 轮的场景极少
- 只带 1 轮：成本可控，「用户发言 → AI 追问 → 用户回一句」这条黄金路径完整成立

技术实现（无需改动现有字段）：
- 用户回复追问时，payload 携带 `parent_message_id`（被追问那条 AI 消息的 ID）
- Edge Function 读取该 `parent_message_id` 对应消息的 `ai_english_content` + `ai_followup`，拼入本次 Prompt 的 system 上下文
- 追问产生的新卡片：在 timeline 独立显示（不嵌套），`parent_message_id` 字段保留链路溯源

---

### 决策 3：视觉风格 → **采纳 B，暂不定**

**决定：功能稳定后，结合真机截图再定具体视觉 token**

当前占位色（teal 薄荷绿）继续保留，不阻塞开发。

---

### 决策 4：输入粒度 + 语言判定 → **采纳 B，补充完整分类规则**

**决定：给 AI 语义规则，由模型自行判断，不用硬词数阈值**

完整的 2×2 矩阵分类规则（写入 System Prompt）：

**第一层：语言判定（EN vs ZH）**

> 以「用户的表达意图语言」为准，不是字符比例统计。
>
> - → ZH 路径（情境 3 / 4）：用户用中文思维表达，即使混入了英文词（如「今天工作好 stress」）
> - → EN 路径（情境 1 / 2）：用户在用英文写作，即使附有中文注解
> - 歧义时：以第一个有完整语义的词语的语言为准；若仍无法判断，默认 ZH 路径（本 App 主要用户群体）

**第二层：粒度判定（词/短语 vs 句子/段落）**

写入 Prompt 的语义规则：
> 「如果输入能独立成句——即存在可辨别的谓语成分，或表达了一个完整的独立命题——则归入句子/段落层；否则归入词/短语层。」

判断示例（帮助模型校准）：

| 输入 | 判断结果 | 触发情境 |
|:---|:---|:---|
| `overtime` | 词 | 情境 1 |
| `I am very sleep today.` | 句子（有谓语） | 情境 2（句子分析） |
| `Having a rough day.` | 句子（隐含主语 + 谓语结构） | 情境 2（句子分析） |
| `摸鱼` | 短语（无谓语） | 情境 3 |
| `今天在摸鱼` | 句子 | 情境 4 |
| `hardly any standing room` | 短语，EN | 情境 1 |

**图片输入特殊规则**：无论有无文字，统一进入情境 4（完整素材包），图片作为场景上下文

---

### 决策 5：AI 人设规则 → **提炼规则 + 正反例**

基于文档中已有例子反推规则（可直接写入 System Prompt）：

**人设边界（Rules）：**
- ✅ 口语化，接地气，可以用网络梗（「摸鱼」「咖啡续命」）
- ✅ 用户吐槽 → 先认同再延伸（「对，太懂了！」），不急于教
- ✅ 可以开小玩笑，顺着用户情绪走
- ❌ 不说教，不主动给建议（除非用户明确问「我应该怎么做」）
- ❌ 禁止「教练腔」：「这是个好机会学习……」/ 「你可以尝试……」
- ❌ 不夸奖用户输入本身：「Great input!」/ 「很好的问题！」
- ❌ 安全底线：不涉及政治/种族/歧视类内容

**`scene_trigger` 的生成规则（单独约束）：**
- 必须输出，不能为 null
- 必须顺着用户的**具体细节**延伸，禁止泛问（「Tell me more」「How was your day?」无效）
- 最多 2 句话
- 引导用户说出**自己真实的处境**（把卡片内容和用户的生活锚定在一起）

**正反例对照（3 组）：**

| 场景 | ✅ 好回复 | ❌ 差回复 |
|:---|:---|:---|
| 用户输入「摸鱼」 | "Slacking off? 😄 What are you secretly doing right now instead of work?" | "The phrase 'slack off' means to work less hard than usual. It's important to stay focused!" |
| 用户输入「今天地铁挤死我了」 | "The subway was packed — did you manage to squeeze off at your stop without a fight? 😅" | "I understand. Public transportation can be challenging. Would you like to learn more commuting expressions?" |
| 用户输入「I am very sleep today」 | "So sleepy you can barely function? 😪 (Quick fix: 'sleepy', not 'sleep' here.) Late night?" | "Your sentence contains a grammar error. 'Sleep' is a verb. The correct adjective form is 'sleepy'. Please note this for future reference." |

---

## 二、四种卡片完整规范

### 情境 1：EN 词汇/短语【理解 · 轻词典】

**触发条件：** 用户英文输入 + 不构成完整句子

**卡片结构（从上到下）：**

```
┌──────────────────────────────────────────────┐
│ [词条区 · 常驻]                               │
│ overtime  /ˈoʊvərtaɪm/  (n.) 加班            │
│                                              │
│ [例句区]                                     │
│ • "I have to work overtime tonight."  [中译] │ ← 翻译按钮行内，紧贴例句右侧
│   我今晚又要加班了。            ← 点击后展开  │
│                                              │
│ ─────────── 虚线分割 ───────────              │
│                                              │
│ [死党追问 · 常驻 · 斜体]                      │
│ "Pulling a late one tonight too?"            │
│                                              │
│ [🔊 语音]                                    │ ← 仅语音在卡底，控制全卡英文朗读
└──────────────────────────────────────────────┘
```

**渲染规则：**
- 词条 + 音标 + 词性 + 中文释义：常驻（查词核心价值，必须直接可见）
- 例句（英文）：常驻
- 例句中译：行内 [中译] 按钮展开/收起，**不放在卡底工具栏**（避免与 scene_trigger 产生语义混淆）
- scene_trigger：常驻，虚线与例句区隔开，不受翻译按钮控制

**AI 输出 JSON：**
```json
{
  "word": "overtime",
  "phonetic": "/ˈoʊvərtaɪm/",
  "pos": "n.",
  "definition": "加班",
  "examples": [
    {
      "en": "I have to work overtime again tonight.",
      "zh": "我今晚又要加班了。"
    }
  ],
  "scene_trigger": "Pulling a late one tonight too? What's keeping you so busy?"
}
```

**语音朗读：** `word` + `examples[0].en`

---

### 情境 2：EN 句子/段落【理解 · 句子分析】

**触发条件：** 英文输入 + 构成完整句子（用户自己写的或看到的均适用）

**输出字段规则（AI 判定，写入 System Prompt）：**

| 字段 | 输出条件 |
|:---|:---|
| `chinese_translation` | **必出**，不允许为 null |
| `grammar_analysis` | a) 有语法/用词错误 → **必出**；b) 无错误但含值得讲解的结构（倒装、高级搭配等）→ **可出**；c) 句子简单且正确 → null |
| `native_polish` | **仅当有语法或表达错误时才出**；原句已地道则不出 |
| `key_phrase` | 含高价值口语短语/搭配时出；否则 null |
| `scene_trigger` | **必出**，不允许为 null |

**卡片结构（条件渲染，字段为 null 时区域自动隐藏）：**

默认态（翻译未展开）：
```
┌──────────────────────────────────────────┐
│ [用户原句 · 常驻 · 灰色弱化]              │
│ "I am very sleep today."                 │
│                                          │
│ [润色版 · 有错误时出现 · Bold · 常驻]     │ ← 改了才出现，是「答案」
│ "I'm so sleepy today."                   │
│                                          │
│ [语法说明 · 条件出现 · 常驻]              │ ← 有错必出；无错有讲解点可出
│ sleep 是动词，表示「困的」要用 sleepy     │
│                                          │
│ [核心词组 · 可空 · 绿色]                  │
│ • sleepy (adj.) — 困倦的                  │
│                                          │
│ ─────────── 虚线分割 ───────────          │
│                                          │
│ [死党追问 · 常驻 · 斜体]                  │
│ "Feeling drained — up all night?"        │
│                                          │
│ [🔊 语音] [翻译]                          │
└──────────────────────────────────────────┘
```

点击翻译后展开（中文译义插入原句正下方）：
```
│ "I am very sleep today."  ← 原句
│ 我今天很困。               ← 中文译义插入此处
│ "I'm so sleepy today."    ← 润色版（有错误才出现）
│ ...（以下不变）
```

**三种典型渲染形态：**

| 场景 | 出现的字段 |
|:---|:---|
| 句子有错误 | 原句 + 润色版 + 语法说明 + 中文译义（折叠）+ scene_trigger |
| 句子正确但有讲解点 | 原句 + 语法说明 + 中文译义（折叠）+ scene_trigger |
| 句子正确且简单 | 原句 + 中文译义（折叠）+ scene_trigger |

**AI 输出 JSON（有错误示例）：**
```json
{
  "grammar_analysis": "sleep 是动词，表示形容词「困的」要用 sleepy",
  "chinese_translation": "我今天很困。",
  "native_polish": "I'm so sleepy today.",
  "key_phrase": null,
  "scene_trigger": "Feeling drained — did you pull an all-nighter?"
}
```

**AI 输出 JSON（正确且有讲解点示例）：**
```json
{
  "grammar_analysis": "「Only by...」放句首会触发倒装，can 提到 we 前面——这是书面英文的经典句式。",
  "chinese_translation": "唯有携手共进，我们才能战胜挑战。",
  "native_polish": null,
  "key_phrase": { "phrase": "overcome", "note": "战胜/克服，比 defeat 更常用于挑战/困难" },
  "scene_trigger": "Did you come across this sentence somewhere, or did you write it yourself?"
}
```

**语音朗读：** `native_polish`（有则优先）；无则朗读用户原句

---

### 情境 3：ZH 词组/短语【表达 · 地道翻译】

**触发条件：** 用户中文输入 + 不构成完整句子

**卡片结构：**

```
┌──────────────────────────────────────────┐
│ [对标区 · 常驻]                           │
│ 摸鱼 / 偷懒 ──→ slack off                 │
│ /slæk ɔːf/  (v.)                        │
│                                          │
│ [例句 · 中英双栏 · 常驻]                  │
│ "Don't let the boss see you              │
│  slacking off!"                          │
│  别让老板看见你在摸鱼！                   │
│                                          │
│ ─────────── 虚线分割 ───────────          │
│                                          │
│ [死党追问 · 常驻 · 斜体]                  │
│ "Slacking off right now? 😄"             │
│                                          │
│ [🔊 语音]                                │ ← 无翻译/更多按钮
└──────────────────────────────────────────┘
```

**AI 输出 JSON：**
```json
{
  "chinese_concept": "摸鱼",
  "english_translation": "slack off",
  "phonetic": "/slæk ɔːf/",
  "pos": "v.",
  "example": {
    "en": "Don't let the boss see you slacking off!",
    "zh": "别让老板看见你在摸鱼！"
  },
  "scene_trigger": "Slacking off right now? Tell me what you're secretly doing instead of working."
}
```

**语音朗读：** `english_translation` + `example.en`

---

### 情境 4：ZH 句子/段落【表达 · 场景手帐】

**触发条件：** 用户中文输入 + 构成完整句子；或任意图片输入（含纯图无文字）

**卡片结构：**

```
┌─────────────────────────────────────┐
│ [用户中文原意 · 淡灰色 · 常驻]       │ ← 默认显示，翻译按钮收起/展开
│ "今天地铁挤死我了，没有站脚的地方。" │
│                                     │
│ [地道英文表达 · 常驻 · Bold · 主焦点]│
│ "The subway was packed today.       │
│  There was hardly any standing      │
│  room."                             │
│                                     │
│ [核心词组 · 可空 · 绿色]             │
│ • hardly any standing room          │
│   几乎没有站立空间                   │
│                                     │
│ -------- 虚线分割 --------           │
│                                     │
│ [死党追问 · 常驻 · 斜体]             │
│ "Did you make it off at your stop   │
│  without a fight? 😅"               │
│                                     │
│ [语音] [翻译（展开/收起中文原意）]   │
└─────────────────────────────────────┘
```

**`key_phrase` 可空规则（同情境 2）：**
- Prompt 约束：只有译文中含有「举一反三价值的地道口语短语、介词搭配或俚语」时才输出
- 极简翻译（如"I got up at 8."）→ `key_phrase` 返回 null，前端区域自动隐藏

**AI 输出 JSON：**
```json
{
  "chinese_original": "今天地铁挤死我了，连站脚的地方都没有。",
  "native_translation": "The subway was packed today. There was hardly any standing room.",
  "key_phrase": {
    "phrase": "hardly any standing room",
    "note": "几乎没有站立空间"
  },
  "scene_trigger": "Did you manage to get off at your station without a fight?"
}
```

**语音朗读：** `native_translation`

---

## 三、输入判定流程图

### 第 0 层：乱码过滤（客户端代码，不调 AI）

**分工原则：代码只做它最擅长的事，其余全交给提示词。**

| 判断类型 | 由谁处理 | 原因 |
|:---|:---|:---|
| 纯符号 / 纯数字 / 纯 emoji / 键盘乱砸 | **客户端代码（正则）** | 不需要语义理解，规则明确，避免白白消耗 API 调用 |
| 自指提取（「X 怎么说」→ 提取 X） | **System Prompt** | 需要语义理解，AI 远胜于规则代码 |
| 输入语言判定（EN / ZH） | **System Prompt** | 意图语言是语义问题，非字符统计 |
| 粒度判定（词 / 句子） | **System Prompt** | 「能独立成句」是语义判断 |
| 输入合规性（是否有实质内容可处理） | **System Prompt** | 边界模糊，AI 兜底更稳 |

客户端代码规则（一条正则即可）：
```
无效：不含任何中文字符（一-鿿）且不含任何英文字母（a-zA-Z）
有效：含至少一个中文字符 或 一个英文字母
```

```
用户点击发送
       │
       ↓
 [客户端正则：有中文字符或英文字母？]
       │
       ├── 无 → 不调 AI，行内提示：
       │         "I didn't quite catch that —
       │          try typing something in Chinese or English!"
       │
       └── 有 → 进入第 1 层（交给 AI）
```

**有效 / 无效示例：**

| 输入 | 判定 | 原因 |
|:---|:---|:---|
| `asdfghjkl` | ❌ 无效 | 无可辨识英文单词（随机字母串不含真实字母？ 注：此处实际含字母，应为有效）→ 见下方说明 |
| `12345` | ❌ 无效 | 纯数字 |
| `😊😂🎉` | ❌ 无效 | 纯 emoji |
| `a` | ✅ 有效 | 含英文字母，AI 处理 |
| `摸` | ✅ 有效 | 含中文字符 |
| `coffee 666` | ✅ 有效 | 含英文字母 |
| `asdfghjkl` | ✅ 有效 | 含英文字母（哪怕是乱序），交给 AI 兜底处理 |

> **边界保持极宽松：** 第 0 层只拦截「字符层面完全无法处理」的输入（纯数字、纯 emoji、纯标点）。只要含有字母或汉字，一律放行，由 AI 在提示词层面判断是否有实质内容。

---

### 第 1 层：分类与兜底（AI 判定，写入 System Prompt）

```
有效输入
       │
       ├── 有图片？
       │     └── YES → 情境 4（完整素材包）
       │
       ↓ NO（纯文字）
       │
       ├── [预处理] 自指提取
       │     输入是否匹配「询问某个词/表达如何说」的句式？
       │     例：「X 怎么说」/「X 是什么意思」/「how do you say X」
       │     ├── YES → 提取 X，对 X 单独分类（忽略外层问句）
       │     └── NO  → 对原始输入分类
       │
       ├── 意图语言？
       │     ├── EN（用英文写作） → 进入 EN 分支
       │     └── ZH（用中文表达） → 进入 ZH 分支
       │
       ├── [EN 分支] 能独立成句？
       │     ├── NO  → 情境 1（词汇/短语·轻词典）
       │     └── YES → 情境 2（句子/段落·句子分析）
       │
       ├── [ZH 分支] 能独立成句？
       │     ├── NO  → 情境 3（词组/短语·地道翻译）
       │     └── YES → 情境 4（句子/段落·场景手帐）
       │
       └── 不属于以上任何情境（语法知识问题、开放性问题等）
             └── → Chat 模式（见下方说明）
```

**自指提取示例：**

| 原始输入 | 识别为自指？ | 提取内容 | 最终触发情境 |
|:---|:---|:---|:---|
| `摸鱼英文怎么说` | ✅ | `摸鱼` | 情境 3 |
| `overtime 是什么意思` | ✅ | `overtime` | 情境 1 |
| `how do you say 摸鱼` | ✅ | `摸鱼` | 情境 3 |
| `今天在摸鱼` | ❌ | — | 情境 4（正常分类） |

---

---

### Chat 模式（四种情境之外的兜底）

**触发条件：** 输入不落在四种情境内，例如语法知识提问、开放性问题、纯聊天

**输出形态：** 普通文字气泡（不生成结构化卡片），AI 自然语言作答

**行为规范：**
- AI 直接回答问题（举例讲解、语法说明等），不套用卡片模板
- 末尾**可选**自然地拉向用户真实场景——不是硬绑定的 `scene_trigger` 字段，而是 AI 自然生成的一句话，如"你最近遇到过需要用这个的情况吗？"
- 不强制，若问题本身和生活场景无关，可以不加

**Chat 模式典型输入：**

| 输入 | 原因不走卡片 |
|:---|:---|
| `have been to 和 have gone to 有什么区别` | 语法知识问题，非个人表达 |
| `passive voice 怎么构成` | 语法规则问题 |
| `你好` / `谢谢` | 纯聊天，无语言学习内容 |

---

## 四、跨情境统一规范

| 规范项 | 卡片模式（情境 1-4） | Chat 模式 |
|:---|:---|:---|
| `scene_trigger` | 必出；顺着具体内容延伸；≤ 2 句；禁止泛问 | 不强制；可在末尾自然拉向用户真实场景，也可不加 |
| 加载态 | Skeleton loading | 普通打字动画（typing indicator） |
| 语音按钮 | 有，线性图标 | 无 |
| 翻译按钮文案 | 展开时「收起」，收起时「翻译」 | — |
| 错误态 | 错误卡片 + 重试按钮；保留原始输入 | Toast 提示 + 重试 |
| 追问后的类型 | 根据用户新输入重新判断情境，生成新卡片 | 继续 Chat 模式，除非新输入明确落入情境 1-4 |

---

*文档版本：v1.2 | 日期：2026-07-01 | 状态：局限1-3已处理，局限4（图片双需求）待决策*
