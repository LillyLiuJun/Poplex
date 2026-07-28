# Tab1 提示词改造 · 第 8 刀需求

> 版本：v1 · 2026-07-26
> 依据：`docs/prd/Tab1_Prompt与输出结构_改造方案_v2.md` §2.1 + §八
> 上下文：第 1 刀已完成——四步流程、统一字段（CardContent）、learnable_units、新 persona、删 chat 均已落地。但图片和文字仍共用同一份 SYSTEM_PROMPT，纯图通过 prepend 硬编码指令强制走 s4，跳过了 SAFETY 第零步和粒度判定。

---

## 一、word / sentence / passage 三级粒度

### 1.1 判定规则（改写 STEP 3）

当前 STEP 3 只区分 word 和 sentence，"passage" 被注释为"未来值、不要用"。第 8 刀改为三级：

**word**：不是 sentence，也不是 passage → 就是 word。

- 包括：单词（`overtime`）、动词短语（`pick up`、`look after`）、名词词组（`hardly any standing room`）、习语（`bite the bullet`）

**sentence**：同时满足两个条件：
1. 有主语 + 有谓语
2. 原文 ≤ 300 字符

主语包括隐含主语：
- 祈使句：`Come here!` → 隐含主语 `you`
- 口语省略：`Having a rough day.` → 隐含主语 `I`
- 倒装句：`Only by working together can we overcome this.`
- 固定表达
**passage**：同时满足两个条件：
1. 有主语 + 有谓语
2. 原文 > 300 字符

passage 是多句文本：一封邮件、一页书、一个长告示牌、一段聊天记录。

### 1.2 卡片类型映射（扩展 MAP TO CARD TYPE）

```
word     + comprehend → "s1"
sentence + comprehend → "s2"
word     + express    → "s3"
sentence + express    → "s4"
passage  + comprehend → "s5"    ← 新增
passage  + express    → "s6"    ← 新增
```

### 1.3 WHY 300 字符

一句英文平均 80–120 字符，300 字符 ≈ 2–3 句。超过这个量，用户不是在输入"一句话"，而是在粘贴一段内容。中文同样适用（一个汉字 ≈ 1 字符）。

---

## 二、提示词拆分：模板组合方案

### 2.1 为什么拆

第 1 刀后仍只有一个 `SYSTEM_PROMPT`。图片处理在 `index.ts` 里通过 prepend 一段硬编码指令实现：

- 纯图：prepend `"The user sent only a photo… Produce an s4 card…"` → 跳过四步流程，强制 s4
- 图文混合：prepend `"Use the text to classify… The photo is additional context"` → 图片降级为附加上下文

问题：
1. 纯图连 SAFETY 第零步都没走——用户拍一张有害图片，提示词不会拦截
2. 纯图被强制走 s4——拍一个单词也被当成场景
3. 图片判定逻辑散落在 TypeScript 代码里，不在提示词中

### 2.2 拆分方式：三段拼接

将当前 `SYSTEM_PROMPT` 拆为三段常量，两份最终提示词各自拼接：

```
SHARED_HEADER（两份完全相同）
  角色定义 + TARGET_LANGUAGE / NATIVE_LANGUAGE 声明
  内容：当前 SYSTEM_PROMPT 第 30–35 行

SHARED_CORE（两份完全相同）
  "PROCESS EVERY INPUT THROUGH STEPS" 标题
  + STEP 1（定位对象）
  + STEP 2（方向：有没有非目标语言成分）
  + STEP 3（粒度：word / sentence / passage）
  + MAP TO CARD TYPE（含 s5/s6）
  + FLOWS（s1–s6 六种流程）
  + LEARNABLE UNITS（含 passage 规则）
  + PERSONA & TONE
  + OUTPUT SCHEMAS（含 passage_lines，不含 ai_scene_guess）
  + MULTI-TURN CONTEXT
  + Return JSON shape

TEXT_PROMPT  = SHARED_HEADER + TEXT_STEP_0（文本安全检查）  + SHARED_CORE
IMAGE_PROMPT = SHARED_HEADER + IMAGE_STEP_0（图片安全检查） + IMAGE_READING + SHARED_CORE
```

### 2.3 为什么 STEP 0 不共享

- 文本 STEP 0 检查：乱码、无意义问候语（"你好"、"hi"）、纯标点
- 图片 STEP 0 检查：有害图片、空白图、完全无法辨认的图
- 判据完全不同，共享反而增加复杂度

### 2.4 为什么 STEP 1–3 + FLOWS + Schema 共享

图片在 IMAGE READING 步骤提取出"待处理内容"之后——不管这个内容是图里拍到的文字、用户附带的文字、还是纯场景的英文描述——后续的定位对象、判方向、判粒度、填字段、抽词、语气，规则与文字路完全一致。

这正是 Agent PRD v2 §2.3(2) 的架构设计：不同输入来源走各自的 prompt，但产出同一套统一契约（CardContent + learnable_units[]）。

---

## 三、输入路由

### 3.1 顶层：哪个 prompt

```
纯文字（无 image_base64）          → TEXT_PROMPT
纯图（有 image_base64，无 text）    → IMAGE_PROMPT
图文混合（有 image_base64，有 text）→ IMAGE_PROMPT
```

当前代码里 prepend 的那三段硬编码指令（纯图强制 s4、图文混合"按文字分类"）全部删除。判定逻辑移入 IMAGE_PROMPT 的 IMAGE READING 部分。

### 3.2 IMAGE_PROMPT 内部逻辑

IMAGE_PROMPT 独有部分包含两步：IMAGE SAFETY（STEP 0）+ IMAGE READING。

#### IMAGE_STEP_0 · 图片安全检查

```
a. 有害图片（暴力、NSFW、仇恨内容）
   → card_type: "error", error_type: "unsafe"，停止

b. 空白图 / 完全无法辨认 / 无任何交流价值
   → card_type: "error", error_type: "meaningless"，停止

c. 其他 → 继续 IMAGE READING
```

#### IMAGE READING · 读图 + 关系判定

**第一步：图里有没有"聚焦的文字"？**

"聚焦的文字" = 文字是照片的主体。路牌特写、菜单、书页、屏幕截图、标签上的文字。背景里偶然出现的文字（远处广告牌、路人衣服上的字）不算。

```
├── 有聚焦的文字
│     提取文字内容（逐字照抄）
│     用一句话描述图片作为语境
│
└── 无聚焦的文字 → 纯场景
```

**第二步：用户是否附带了文字？（区分纯图 vs 图文混合）**

```
图文混合（有附带文字）→ RELATIONSHIP CHECK：

  文字指向图片内容？（元问题）
    判定依据：
    · 文字含指示代词（"这"、"这个"、"this"、"that"）
    · 文字是问句（"什么意思"、"怎么读"、"what does this say"、"翻译一下"）
    · 文字本身不是完整的学习素材（离开图片就没有独立意义）
    →
    待处理内容 = 从图里提取的文字
    附带文字不进入 user_original（它只是指示器）
    然后走 STEP 1–3 判定 word / sentence / passage

    例：拍英文菜单 + "这什么意思"
        → 提取菜单文字 → sentence + comprehend

  文字指向表达？（内容 + 语境）
    判定依据：
    · 文字是完整的词、短语或句子
    · 文字有独立的学习价值（离开图片仍然有意义）
    →
    待处理内容 = 用户文字
    图片补充语境细节（在 target_expression 中体现图片里的场景）
    然后走 STEP 1–3 判定 word / sentence / passage

    例：打"overtime" + 拍加班夜景
        → word + comprehend，英文描述带加班场景
    例：打"今天地铁挤死了" + 拍拥挤车厢
        → sentence + express，英文句子里融入视觉细节
    例：打"I have a 会议 at 3pm" + 拍日历
        → sentence + express，补全 meeting

纯图（无附带文字）：

  ├── 有聚焦文字
  │     待处理内容 = 提取的文字
  │     走 STEP 1–3 → 判 word / sentence / passage
  │     例：拍一个路牌"NO PARKING" → word + comprehend
  │     例：拍一页英文书 → passage + comprehend
  │
  └── 纯场景（无文字）
        → 直接产出 s2 卡（sentence + comprehend）
          不进入 STEP 1–3
          · user_original = null
          · user_original_lang = null
          · target_expression = 一句自然的英文场景描述
          · native_meaning = target_expression 的母语翻译
          · revision_type = null
          · 从 target_expression 中提取 learnable_units[]
```

### 3.3 Gemini 调用改动

删掉当前 `userParts` 里的 prepend 指令文本。纯图只发图片数据，图文混合发图片 + 用户文字。选择哪个 prompt 通过 `systemInstruction` 控制：

```
有 image_base64 → systemInstruction = SYSTEM_PROMPT_IMAGE
无 image_base64 → systemInstruction = SYSTEM_PROMPT_TEXT
```

---

## 四、passage 卡片

### 4.1 后端：passage 两种流程

**passage + comprehend（s5）**——用户输入 / 图片拍到的是目标语言长文本：

1. 原文按句拆分
2. 逐句翻译为母语 → `passage_lines: [{en: 原句, zh: 母语翻译}]`
3. `target_expression` = 原文整体（可能通过 grammar_note 指出值得注意的表达）
4. `native_meaning` = 原文一句话概要
5. `revision_type` = null（长内容不逐句修正）
6. 提取 `learnable_units[]`：从全文中提取，数量随内容体量，不做人为上限。优先级：关键词汇 → 搭配 → 句型

**passage + express（s6）**——用户输入 / 图片拍到的是母语长文本：

1. 原文按句拆分
2. 逐句翻译为目标语言 → `passage_lines: [{en: 英文翻译, zh: 原句}]`
3. `target_expression` = 英文整体翻译
4. `native_meaning` = null（原文已在 passage_lines 中）
5. 提取 `learnable_units[]`：从英文译文中提取，规则同 s5

### 4.2 前端：passage 卡片布局

**卡片类型标签**：`"PASSAGE"`

**收起态（默认）**：
```
┌─────────────────────────────┐
│ PASSAGE                     │
│ 第一句 en…     （最多 2 行）  │
│ 第一句 zh…     （1 行省略）   │
│                    [ 展开 ↓ ]│
└─────────────────────────────┘
```

**展开态**：
```
┌─────────────────────────────┐
│ PASSAGE                     │
│                             │
│ The subway was packed today. │
│ 今天地铁挤死了。              │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│ I could barely breathe.      │
│ 我几乎喘不过气。              │
│ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─  │
│ ...                         │
│                    [ 收起 ↑ ]│
└─────────────────────────────┘
```

细节：
- 展开/收起带 `easeInOut 0.2s` 动画
- 行与行之间用淡分隔线（`Divider`, 15% opacity）
- 只有 `passage_lines` 多于 1 行时才显示展开/收起按钮
- 原文行用 `englishPrimary` 字体 + `brandStrong`（橙色），翻译行用 `chineseBody` + `textMuted`（灰色）
- grammar_note 如有则在底部显示

### 4.3 learnable_units 的处理原则

- 后端：passage 流程正常输出 `learnable_units[]`，正常落库
- 前端：passage 卡片**不展示** learnable_units。这和 word / sentence 卡片的行为一致——learnable_units 在 Tab1 只落库、不展示，是给 Tab2 账本吃的
- 不做勾选剔除交互

---

## 五、passage_lines 字段

### 5.1 新增位置

| 层级 | 字段 | 类型 |
|---|---|---|
| AI 输出 JSON | `passage_lines` | `[{en: string, zh: string}]` |
| `UnifiedRawContent`（index.ts） | `passage_lines` | `{en: string; zh: string}[]`（可选） |
| `CardContent`（AIResponse.swift） | `passageLines` | `[PassageLine]` |
| `PassageLine`（新增 struct） | `en`, `zh` | `String`, `String`，Decodable |

### 5.2 字段语义

| card_type | `passage_lines[].en` | `passage_lines[].zh` |
|---|---|---|
| s5（passage+comprehend） | 原文（目标语言） | 母语翻译 |
| s6（passage+express） | 英文翻译 | 原文（母语） |
| s1–s4 | `[]`（空数组） | `[]` |

### 5.3 buildRawContent 映射

```
passage_lines:
  · JSON 中是数组 → 逐项取 en/zh 字符串 → 落库
  · JSON 中不是数组 → 落 []
  · 空数组 → 落 undefined（不在 raw_content 中占键）
```

---

## 六、ai_scene_guess 删除

### 6.1 删除原因

第 1 刀的设计中，纯图走 s4（sentence+express），`ai_scene_guess` 是 AI 用母语描述图片内容的字段，前端通过 `"In the photo: \(guess)"` 展示。

第 8 刀改为：纯场景图走 s2（sentence+comprehend），AI 产出：
- `target_expression` = 英文场景描述（原来就是这个）
- `native_meaning` = 母语翻译（**原来 ai_scene_guess 的功能被它吸收**）

comprehend 模式的 UI 本来就是"目标语言突出 + 母语翻译"，纯场景图走这条路 UI 完全一致，不需要特殊分支。`ai_scene_guess` 成为冗余字段。

### 6.2 需要删除的位置

| 位置 | 文件 | 具体操作 |
|---|---|---|
| 提示词 OUTPUT SCHEMAS | `index.ts` | 删除字段说明行（`ai_scene_guess — string or null…`） |
| `UnifiedRawContent` 接口 | `index.ts` | 删除 `ai_scene_guess?: string \| null` |
| `buildRawContent` 函数 | `index.ts` | 删除 `ai_scene_guess: asStr(content.ai_scene_guess)` |
| `CardContent` struct | `AIResponse.swift` | 删除 `aiSceneGuess: String?` 属性和 `case aiSceneGuess` CodingKey |
| `CardContent.init(decoder:)` | `AIResponse.swift` | 删除解码行 |
| `contextRepresentation` | `AIResponse.swift` | 删除 `d["ai_scene_guess"] = …` |
| `expressNativeRow` | `AICardBody.swift` | 删除 `aiSceneGuess` fallback 分支（`if let guess = …`），只保留 `userOriginal` 判断 |

### 6.3 不需要操作的位置

- 数据库已有 `raw_content` 中的 `ai_scene_guess`：老记录保留不动，新记录不再写入此键
- `Material.swift` 等 Tab2 素材模型：当前没有引用此字段，无需改动

---

## 七、后端数据层改动

### 7.1 UnifiedRawContent

```
新增：
  passage_lines?: { en: string; zh: string }[]  // 仅 passage (s5/s6)

删除：
  ai_scene_guess?: string | null

granularity 注释更新：
  "word | sentence" → "word | sentence | passage"
```

### 7.2 buildRawContent

```
cardType 白名单：
  当前：s1, s2, s3, s4
  改为：s1, s2, s3, s4, s5, s6

granularity 兜底：
  当前：s1/s3→word, s2/s4→sentence
  改为：s1/s3→word, s2/s4→sentence, s5/s6→passage

materialType 推导：
  当前：word→vocabulary, sentence→scene
  改为：word→vocabulary, sentence/passage→scene

新增字段映射：
  passage_lines：数组 → 逐项提取 {en, zh} → 落库；空 → undefined

删除字段映射：
  ai_scene_guess
```

### 7.3 saveMaterial

不改动。`materialType` 已由 `buildRawContent` 推导，passage → scene 走现有的分类+落库流程。

### 7.4 数据库

`materials` 表和 `messages` 表结构不变。`raw_content` 是 jsonb，新增 `passage_lines` 键、不再写入 `ai_scene_guess` 键，无需 migration。

---

## 八、前端改动

### 8.1 AIResponse.swift

**AICard 枚举**：不变（passage 仍走 `.card(CardContent)`）

**AIEnvelope 解码**：switch 加 `"s5"`, `"s6"`：
```
case "s1", "s2", "s3", "s4", "s5", "s6", "card":
```

**CardContent**：
- 新增 `passageLines: [PassageLine]`（CodingKey: `"passage_lines"`，默认 `[]`）
- 删除 `aiSceneGuess: String?`
- 新增计算属性 `isPassage: Bool { granularity == "passage" }`
- `granularity` 注释更新：`"word" | "sentence"` → `"word" | "sentence" | "passage"`

**新增 struct**：
```
struct PassageLine: Decodable {
    let en: String
    let zh: String
}
```

**contextRepresentation**：`aiSceneGuess` 替换为 `passageLines`：
```
if !c.passageLines.isEmpty {
    d["passage_lines"] = c.passageLines.map { ["en": $0.en, "zh": $0.zh] }
}
```

### 8.2 AICardBody.swift

**卡片类型标签**：从硬编码二元改为三元：
```
isWord → "Word"
isPassage → "Passage"
else → "Sentence"
```

**body 分支**：从 `isWord / else` 改为 `isWord / isPassage / else`。

**新增 passage 布局**（`passageContent`）：
- `@State private var passageExpanded = false`
- 收起态：只显示 `passageLines.first` 的 en（最多 2 行）+ zh（1 行），底部"Expand full text ↓"按钮
- 展开态：`ForEach` 遍历全部 `passageLines`，每行 en → zh，行间 `Divider`
- 展开/收起按钮：`Button` + `withAnimation(.easeInOut(duration: 0.2))`
- 仅当 `passageLines.count > 1` 时显示按钮
- grammar_note 如有，在底部显示

**expressNativeRow**：删除 `aiSceneGuess` fallback：
```
// 当前：
if let original = content.userOriginal, !original.isEmpty { return original }
if let guess = content.aiSceneGuess, !guess.isEmpty { return "In the photo: \(guess)" }
return nil

// 改为：
if let original = content.userOriginal, !original.isEmpty { return original }
return nil
```

### 8.3 MessageRecord.swift

解码 switch 加 `"s5"`, `"s6"`：
```
case "s1", "s2", "s3", "s4", "s5", "s6", "card":
```

注释更新：`s1–s4` → `s1–s6`。

### 8.4 不需要改动的文件

- `TodayView.swift`：时间轴渲染不变，passage 卡片走同样的 `TimelineRow → AICardView → AICardBody` 路径
- `TodayViewModel.swift`：发送、历史加载逻辑不变
- `MessageRow.swift`：`AICardView` / `AICard` 路由不变（passage 仍是 `.card(CardContent)`）
- `Material.swift`：Tab2 素材模型不变
- `AIService.swift`：LiveAIService 不变。MockAIService 中的旧 `scene_trigger` 字段保留不动（已被解码器忽略，仅 dev 测试用）

---

## 九、测试

### 9.1 新增测试

**decodesPassageComprehendCard**（s5 解码）：
- 验证 `granularity == "passage"`、`isPassage == true`、`isWord == false`
- 验证 `passageLines.count == 2`、各行的 en/zh 正确
- 验证 `learnableUnits` 正常解码、`primaryUnit` 正确

**decodesPassageExpressCard**（s6 解码）：
- 验证 `granularity == "passage"`、`direction == "express"`
- 验证 `passageLines` 内容正确
- 验证 `nativeMeaning == nil`

**decodesPureScenePhotoCard**（纯场景图 → s2）：
- 验证 `granularity == "sentence"`、`direction == "comprehend"`
- 验证 `userOriginal == nil`、`userOriginalLang == nil`
- 验证 `targetExpression` 为英文场景描述
- 验证 `nativeMeaning` 为母语翻译
- 验证 `passageLines.isEmpty`

### 9.2 更新已有测试

**decodesSentenceExpressCard**（s4 解码）：
- 删除 `#expect(c.aiSceneGuess == nil)` 断言
- 替换为 `#expect(c.passageLines.isEmpty)`
- 注释去掉 `aiSceneGuess 仅纯图场景`

---

## 十、不改动的清单（防御性说明）

以下全部不动——如果改动涉及以下任何一项，说明范围越界：

| 类别 | 具体 |
|---|---|
| 前端路由 | `MessageRow.swift` 的 `TimelineRow` / `AICardView` 结构不变 |
| 时间轴 | `TodayView.swift` / `TodayViewModel.swift` 不变 |
| 材料落库 | `saveMaterial()` 函数不变 |
| 材料分类 | `classifySceneCategory()` 函数不变 |
| 数据库 | `materials` 表 / `messages` 表 DDL 不变 |
| Tab2 | `Material.swift` / `MineView` / `VocabBookView` 不变 |
| 已有卡片 | s1–s4 的提示词流程、字段、前端渲染全部不变 |
| 已有数据 | 老的 `raw_content` 中的 `ai_scene_guess` 保留不动 |
| 图文混合 | 当前代码中图文混合 prepend 指令的行为被 IMAGE_PROMPT 的 RELATIONSHIP CHECK 接替；文档待-8① 仍未敲定，但这一刀的行为（区分指向内容 vs 指向表达）是向前兼容的 |
