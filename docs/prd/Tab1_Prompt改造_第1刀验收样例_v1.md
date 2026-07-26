# 第 1 刀 · 边界样例回归表

> 用途：新 `SYSTEM_PROMPT` 部署后，逐条输入、逐条核对。**这张表是这一刀唯一的验收标准。**
> 对应：`docs/prd/Tab1_Prompt与输出结构_改造方案_v2.md` §1.1（四步判定）+ §1.3（各档流程）
> 代码：`supabase/functions/generate/index.ts`

---

## 〇、这一刀改了什么 / 没改什么

| | 内容 |
|---|---|
| **改了（后端）** | `SYSTEM_PROMPT` 全量重写：四步流程、判据换成"有没有非目标语言成分"、word 形式判定、sentence 修正顺序、`learnable_units[]`、新 persona、删 chat |
| **改了（后端）** | `buildRawContent` 新增落库字段：`granularity` / `direction` / `learnable_units[]` / `revision_type`；s1 加 `grammar_note`；s4 加 `ai_scene_guess`（此前被丢弃） |
| **没改** | 所有**现有**字段的名字、类型、取值逻辑 —— 一个都没动 |
| **没改** | 前端。Swift `Codable` 会忽略不认识的新字段，**App 不需要重新发版也不会崩** |
| **没改** | `raw_content` 的整体结构（新字段是追加的，老素材读出来是 `undefined`） |

> ⚠️ **删 chat 的唯一风险**：数据库里已有的 `card_type='chat'` 历史消息。新 prompt 不再产出 chat，但**老记录还在**。`MessageRow` 仍有 `.chat → ChatBubbleView` 的路由，所以历史照常渲染、不会崩。彻底删除 chat 组件是后面第 7 刀的事。

---

## 一、四步判定：分类正确性（核心）

逐条输入，核对 `card_type` + `card_content.granularity` + `card_content.direction`。

### A 组 · 元问题（验证 STEP 1 必须在 STEP 2 之前）

| # | 输入 | 期望 card_type | granularity | direction | extracted_concept | 这条在验什么 |
|---|---|---|---|---|---|---|
| A1 | `overtime是什么意思` | s1 | word | comprehend | `overtime` | **最关键的一条**。整句含中文，若先判语言会错判 express |
| A2 | `摸鱼怎么说` | s3 | word | express | `摸鱼` | 抽出对象后仍是非目标语言 |
| A3 | `what does "bite the bullet" mean` | s1 | word | comprehend | `bite the bullet` | 元问题的英文写法 |
| A4 | `"I'm running late" 更自然的说法是什么` | s2 | sentence | comprehend | `I'm running late` | 对象是个句子 |
| A5 | `would和could有什么区别` | s1 | word | comprehend | `would` 或 `would/could` | 原本走 chat，现在按元问题处理 |

### B 组 · 语言判定（验证 STEP 2 的新判据）

| # | 输入 | 期望 card_type | granularity | direction | 这条在验什么 |
|---|---|---|---|---|---|
| B1 | `overtime` | s1 | word | comprehend | 纯目标语言、无谓语 |
| B2 | `I have to work overtime tonight.` | s2 | sentence | comprehend | 纯目标语言、有谓语 |
| B3 | `内卷` | s3 | word | express | 纯母语、无谓语 |
| B4 | `今天地铁挤死了` | s4 | sentence | express | 纯母语、有谓语 |
| B5 | `今天工作好 stress` | s4 | sentence | express | **混合**：母语为主嵌目标语言词 |
| B6 | `I have a 会议 at 3pm` | s4 | sentence | **express** | **混合最难的一条**：主体是目标语言，但含母语成分 → 仍是 express，产出应是补全后的完整英文（`I have a meeting at 3pm.`） |
| B7 | `お疲れ様です` | s4 或 s3 | — | **express** | **第三种语言**：应走 express 译成英文，不报错 |
| B8 | `c'est la vie` | s3 | word | express | 第三种语言 + 短语 |

### C 组 · 粒度判定（验证 STEP 3）

| # | 输入 | 期望 granularity | 这条在验什么 |
|---|---|---|---|
| C1 | `hardly any standing room` | word | 长短语但无谓语 → 仍是 word |
| C2 | `Having a rough day.` | sentence | 省略主语但有谓语结构 |
| C3 | `躺平` | word | 母语短语 |
| C4 | `我最近压力好大` | sentence | 母语句子 |

### D 组 · SAFETY 第零步

| # | 输入 | 期望 | 这条在验什么 |
|---|---|---|---|
| D1 | `你好` | `card_type: error`, `error_type: meaningless` | 打招呼无可学内容。**原本走 chat，现在应走 error** |
| D2 | `asdkjhaskdjh` | `card_type: error`, `error_type: meaningless` | 乱码 |
| D3 | （空字符串） | 400 `missing_input`（在 Edge 层拦掉，不到 AI） | 已有行为，不该变 |
| D4 | 明显有害内容 | `card_type: error`, `error_type: unsafe` | 安全底线 |

---

## 二、word 侧形式判定（v2 新增能力）

| # | 输入 | 期望 `word`（规范词条） | 期望 `grammar_note` | 这条在验什么 |
|---|---|---|---|---|
| E1 | `spoken` | **speak** | 非空，说明是过去分词 + 用在完成时/被动 | 词形变化归原型 |
| E2 | `meetings` | **meeting** | 非空，说明是复数 | 同上 |
| E3 | `recieve` | **receive** | 非空，指出拼写 | 拼写纠正 |
| E4 | `overtime` | overtime | `null` | 已是规范形式，不该多话 |
| E5 | `glasses` | **glasses**（不是 glass） | `null` 或说明它是独立词义 | **反例**：有独立词义不归原型 |
| E6 | `drawing` | **drawing**（不是 draw） | 同上 | 反例 |
| E7 | `used to` | **used to**（不是 use） | 同上 | 反例：固定结构 |
| E8 | `overwork`（用户其实想说"加班"） | overwork | `null` | **不猜用词**。不该擅自改成 work overtime |

**同时核对**：`pos` 是否为"最多 3 个、用 ` / ` 分隔"的格式（如 `v. / n.`），`examples` 是否双语。

---

## 三、sentence + comprehend 的修正顺序（v2 新增能力）

| # | 输入 | `revision_type` | `native_polish` | `chinese_translation` 应翻的是 | `grammar_analysis` |
|---|---|---|---|---|---|
| F1 | `I am very sleep today` | **error** | `I'm very sleepy today.` | **润色版** → "我今天很困" | **必出**（sleep 是动词，这里要用 sleepy） |
| F2 | `I very like it` | **polish** | `I really like it.` | 润色版 | 可 null，语气应是"也可以说" |
| F3 | `I have to work overtime tonight.` | **null** | **null** | **原句** | 可 null |
| F4 | `Only by working together can we overcome this.` | null | null | 原句 | 可出（倒装结构值得讲） |

**F1 是这组最关键的一条**：如果 `chinese_translation` 出现"我今天很睡觉"这种直译原句的结果，说明流程第 3 步没生效。

---

## 四、`learnable_units[]`（账本进料口）

对上面每一条都顺带核对：

| 检查项 | 期望 |
|---|---|
| 是否存在 | 每张非 error 卡都有 `learnable_units`（可以是 `[]`） |
| 数量 | 短输入 1–3 个，不超过 5 |
| `is_primary` | **有且仅有一个 true**（若数组为空则没有） |
| 与 `key_phrase` 的关系 | s2/s4 的 `key_phrase` 应与 `is_primary` 那个单元是同一个表达 |
| 不该出现的 | 功能词（the/a/is/of/to）、孤立的极基础词（good/day/work）、专有名词、数字、**任何母语词** |
| `kind` 取值 | 只能是 word / phrase / collocation / slang / idiom / pattern |

**重点看几条：**

| 输入 | 期望大致抽出 |
|---|---|
| `昨天开了一天的会，累死了` | `be in meetings all day`（collocation）、`completely drained` 或 `wiped out`（phrase）。**不该**抽 `day` / `all` |
| `今天地铁挤死了` | `packed`（word/phrase）。1 个就够 |
| `overtime` | `work overtime`（collocation）或 `overtime` 本身 |
| `躺平` | `lie flat` / `check out of the rat race` 之类，1–2 个 |

> **v0 筛选标准是临时的。** 这一栏的目的不是"验它对不对"，是**收集真实结果**——跑几天之后拿这批数据反推标准，回填提示词（第 2 刀）。所以**这一栏出现"抽多了/抽偏了"是预期的，不算这一刀失败**。

---

## 五、persona / TONE

拿 `今天地铁挤死我了` 跑一条，核对 `scene_trigger`：

| 判定 | 标准 |
|---|---|
| ✅ 通过 | 顺着具体细节问（如 "Was it the whole ride, or just getting off?"） |
| ❌ 不通过 | 出现 emoji；出现 "Great..."/"很好" 类夸奖；出现 "Would you like to learn more..." 类教练腔；泛问（"Tell me more"）；感叹号堆情绪 |

再随机抽 3–5 条其他输入复核同样几条。

---

## 六、落库核对（Supabase 里查一遍）

```sql
select
  material_type,
  raw_content->>'granularity'    as granularity,
  raw_content->>'direction'      as direction,
  raw_content->>'revision_type'  as revision_type,
  jsonb_array_length(coalesce(raw_content->'learnable_units','[]'::jsonb)) as unit_count,
  raw_content->>'grammar_note'   as grammar_note,
  raw_content->>'ai_scene_guess' as ai_scene_guess,
  created_at
from materials
where deleted_at is null
order by created_at desc
limit 30;
```

| 检查项 | 期望 |
|---|---|
| `granularity` / `direction` | 新素材全部有值，与卡片上看到的一致 |
| `unit_count` | 大部分 ≥ 1 |
| `grammar_note` | E1–E3 那类输入有值 |
| `ai_scene_guess` | **纯图输入的素材有值**（这是此前被丢弃的数据，现在应该保住了） |
| 老素材 | 这几列是 null —— **正常**，不是 bug |

---

## 七、通过标准

这一刀算过，需要：

1. **第一节 A/B/C/D 四组全对**（分类正确性，这是这一刀的主要目的）
2. **第二节 E1–E8 全对**，尤其 E5–E8 四个反例不该被过度纠正
3. **第三节 F1 的 `chinese_translation` 翻的是润色版**
4. **第四节的结构检查全过**（有数组、`is_primary` 唯一、无功能词/母语词）——**内容质量本轮不作为通过条件**
5. **第五节没有踩到任何一条 ❌**
6. **第六节新字段全部落库，且老素材没被破坏**
7. App 端跑一遍：卡片显示正常、不崩（新字段被 Swift 忽略）

**任一条不过，记录具体输入 + 实际输出，回来改提示词，不要直接往下做第 2 刀。**

---

## 八、已知不在本刀范围内

| 事项 | 归哪一刀 |
|---|---|
| `chinese_original` 纯图时被压成空串 | 落库结构分化（第 8 刀）。本刀只保住 `ai_scene_guess`，没动它 |
| `pos` 改成真数组、`scene_trigger` 改成 `follow_ups[]` | 第 5、6 刀（要动 Swift 解码） |
| 删 `ChatBubbleView` 等 chat 组件与历史数据 | 第 7 刀 |
| 图片路拆独立提示词 | 第 8 刀 |
| 可学单元筛选标准定稿 | 第 2 刀（依赖本刀跑出的数据） |
