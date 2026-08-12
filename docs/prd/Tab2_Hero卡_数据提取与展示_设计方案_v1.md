# Tab2 Hero 卡 · 数据提取与展示 设计方案 v1

> 状态：待评审
> 上游权威：`整体架构_两个Tab与对话页_v1.md`、`Agent内容组织与成长系统_PRD_v2.md`
> 本文是 `Tab2_练习入口与信息架构_设计方案_v2.md` 的下钻。冲突时以本文为准，并回写上游。
> 设计参考：`docs/design-demos/tab2-hero-collage-redesign.html`

---

## 〇、这份文档解决什么

**范围**

- Tab2 hero 卡的**数据提取逻辑**：从哪条 material 取内容、按什么优先级选
- Tab2 hero 卡的**前端展示方案**：顶部拼图、底部内容、CTA
- 为支撑上述两点所需的 `get_tab2_home` RPC 改造与 `generate` 侧的一处 direction 修正

**不在范围**

- 分类算法、pops 计数口径
- 对话页、成长层
- Tab1 前端

**与既有实现的关系**

代码是事实。本文对现状的每处判定都标了代码位置；发现的两个 bug（§8.1、§8.2）在本文内一并给出修法。

---

## 一、卡片的职责与判断标准

### 1.1 唯一任务

hero 卡的任务是**勾起认领感 → 让用户点进去说话**。

它不是回忆本，不是内容摘要，不是数据看板。用户在这张卡上停留的时间以秒计，卡片只需要完成一次"这确实是我的事"的确认，然后把人推进对话页。

### 1.2 由此推出的取舍原则

底部每增加一个元素，只问一个问题：**删掉它，点击率会不会掉？**

- 会掉 → 留
- 不会掉 → 砍，无论它看起来多"有信息量"

统计类信息（分类频次、总词数）几乎都属于后者：它们提供的是弱自恋价值，推动不了行动。

### 1.3 三段式信息结构

一张卡按顺序回答三个问题：

| 段 | 问题 | 承载元素 |
|---|---|---|
| 一 | 这是什么 | 分类标签（顶部叠加） |
| 二 | 凭什么说是我的 | 真实照片 + 用户原话 + 场景名 + 时间 |
| 三 | 聊了会怎样 | CTA |

第二段是卡片的重心，也是本文绝大部分篇幅所在。

---

## 二、卡片结构总览

### 2.1 顶部（已定，本文不再讨论其形式）

- 只铺**用户真实照片**，1–5 张按拼图排（布局 c1–c5 见设计 demo）
- 该分类零真实照片 → 顶部整块换成 12 张分类预设图之一（暖色剪影插画）
- 叠加层：分类标签（左上）、pops（右上）、`+N more moments`
- 拼图排法按 demo 执行

**定性：顶部拼图是「分类级视觉氛围」，不承诺与底部原话同源。**

顶部说的是"这个分类最近的样子"，底部说的是"其中一个 moment"。这是两个层级的东西。拼图形式（2–5 张小图）本身就在传达"这是一堆事"，不会被读成单张插图。

**唯一例外见 §3.5（c1 单图绑定）。**

### 2.2 底部（本文重点）

三行结构：

```
Cooking dinner · seen 4× · 4 days ago      ← meta 行
❝ The sauce came out way too salty tonight. ← 主角句
                                  [ Talk → ] ← 右下 CTA
```

`+N more moments` 已上移到顶部，底部不再列其他 moment。

### 2.3 高度预算

- 底部由现状 150px 收到 **112–120px**（模式 A）/ **124px**（模式 B、C，多一行注脚）
- 各模式高度必须对齐，卡片在列表中不得跳动

### 2.4 列表级模式多样性（新增约束）

Tab2 首页是多张 hero 卡并列。单卡排序键只管"这张卡选哪条 material"，不管全局分布。

需要在**列表层**加一条约束：

> 首屏可见的前 N 张卡中，至少保证 1 张是模式 A（用户用目标语言说过的原话）。

**理由**：模式 B（想说但没说出来）和模式 C（AI 描述照片）都不含用户自己的目标语言产出。如果一个用户长期只看到 B/C，首页会失去正反馈，退化成"你还有 12 件事说不出来"的负担墙。

这条约束**不能下放到单卡排序键**——那会用次级维度推翻主排序的立论（详见 §3.3 的两次撤回记录）。

---

## 三、featured moment 的选取

这是本文的核心。底部展示的一切（原话、场景名、时间、语言模式）都来自**唯一一条被选中的 material**。

### 3.1 同源约束（硬性）

> **同一张卡上的图、话、时间、语言、粒度，必须来自同一条 material。**

现状违反了这条，见 §8.1。

### 3.2 候选集

```
lexicon_occurrences lo
  JOIN materials m      ON m.id = lo.source_id
  JOIN lexicon_entries le ON le.id = lo.entry_id AND le.status = 'active'
WHERE lo.user_id = :uid
  AND lo.scene_category IS NOT NULL
  AND lo.scene_detail   IS NOT NULL
  AND lo.source_granularity <> 'word'   -- 查词不参选 featured
```

`granularity = 'word'`（查词）不参选：它没有句子，无法承担底部主角句。查词内容归入模式 D 的 chips。

### 3.3 排序键（五层）

```sql
ORDER BY
  -- ① 方向 × 粒度
  CASE
    WHEN lo.source_direction='express'    AND lo.source_granularity='sentence' THEN 1
    WHEN lo.source_direction='express'    AND lo.source_granularity='passage'  THEN 2
    WHEN lo.source_direction='comprehend' AND lo.source_granularity='sentence' THEN 3
    WHEN lo.source_direction='comprehend' AND lo.source_granularity='passage'  THEN 4
    ELSE 9
  END,

  -- ② express 内的意图明确度（三级）
  CASE
    WHEN m.raw_content->>'source_image_path' IS NOT NULL
     AND m.raw_content->>'user_original'     IS NOT NULL THEN 1   -- 图 + 文字
    WHEN m.raw_content->>'user_original'     IS NOT NULL THEN 2   -- 纯文字
    ELSE 3                                                        -- 纯图片
  END,

  -- ③ 新鲜度：还没在对话里练过的优先
  CASE WHEN le.spoken_count = 0 THEN 0 ELSE 1 END,

  -- ④ 场景高频
  occurrence_count DESC,

  -- ⑤ 兜底
  m.created_at DESC
```

**① 的立论**：这一层排的是**意图强度**。express 意味着用户在往目标语言的方向走，comprehend 意味着他在往回走；sentence 比 passage 意图更聚焦。

**② 的立论**：同为 express，用户是否说明了"想表达什么"决定了这条素材的可练性。图 + 文字信息最全，纯图片只指了个场景、意图未指定。

**③ 的立论**：卡片是练习入口。推一条已经在对话里练透的 moment 是纯浪费。信号取 `lexicon_entries.spoken_count`。

**④⑤ 沿用既有直觉**，不展开。

#### 3.3.1 两条被否决的排序维度（保留记录，避免重开）

**否决一：`input_lang='target'` 优先于 `native`。**

提出理由是避免首页变成 gap 负担墙。否决理由：① 的立论就是意图强度，而 `express + native`（想说、说不出来）恰恰是意图最强的一类，用语言维度把它压下去等于自我推翻。负担感是**文案与版式问题**，已由 §4.3 的版式（target_expression 作主角、母语句降为注脚）解决；多样性问题已由 §2.4 的列表级约束解决。

**否决二：只要分类内存在有图候选，featured 必须从有图候选里选。**

提出理由是保证顶部大图与底部原话同源。否决理由：这会让 `sentence express`（用户真正想说的话）让位给意图更弱的素材，与否决一是同一个错误。同源问题改由 §2.1 的定性 + §3.5 的窄规则解决。

### 3.4 去重

一条 material 可能产出多个 `learnable_unit` → 多条 `lexicon_occurrences`。选取时必须按 material 去重，否则同一条素材会被重复计入排序。`DISTINCT ON` 天然解决（见 §8.1 的 SQL）。

### 3.5 c1 单图绑定（窄规则）

> **当分类恰好只有 1 张真实照片时，featured 强制取那条有图的 material。**

**理由**：一张大图 + 正下方一句话，视觉上是强烈的"图文对应"暗示，此时不同源会被直接读成错配。2–5 张拼图不存在这个问题。

**影响面**：仅限单图分类，代价可控。

### 3.6 featured 有图时的 slot 1 标记（加分项）

若 featured 自带照片，将该照片置于拼图 slot 1（c1/c3/c5 的大图位）。这让"大图 = 底部那句话说的这件事"成立，语义更紧。

**这是加分项，不是必要条件。** featured 无图时不做任何补偿动作，顶部照常按 §6.1 铺最近 5 张。

> 备注：`generate` 侧改动落地后（§10），纯图片素材升入 ①档，featured 自带照片会成为多数情况，本条的命中率会大幅提升。

---

## 四、展示模式 A / B / C / D

### 4.1 引号硬约束

> **引号 = 用户实际用目标语言产出的字面文本。其他任何来源一律不得使用引号。**

引号是"这是你的英语"的标记，一旦被 AI 生成内容稀释，卡片的可信度就没有了。而可信度是我们让原话上卡的**唯一理由**。

由此推出的字面文本规则（原 §4 章合并至此）：

- 允许的操作只有两种：**整句选取**、**从句边界截断加 `…`**
- 禁止：改写、合并多句、翻译、语法纠错、AI 润色后的版本
- 宁可这条 material 不参选，也不要展示被改动过的句子

### 4.2 模式判据

判据用 `(user_original, input_lang)` 组合，**不能只看 `input_lang`**——纯图片素材的 `input_lang` 为 `null`。

| 模式 | 判据 | 语义 |
|---|---|---|
| **A** | `user_original` 非空 且 `input_lang = 'target'` | 你说过的英语 |
| **B** | `user_original` 非空 且 `input_lang = 'native'` | 你想说但没说出来的 |
| **C** | `user_original IS NULL`（纯图片） | 你拍下的场景 |
| **D** | 该分类无 sub_scene（全是查词） | 你攒下的词 |

`input_lang = 'other'`（第三语言）按 comprehend 处理，对齐 `Prompt改动需求.md` 的 N1 项。

### 4.3 模式 A · 你说过的英语

```
Cooking dinner · seen 4× · 4 days ago
❝ The sauce came out way too salty tonight.
```

- 引号 + 衬线（`Newsreader` / SwiftUI `design: .serif`）
- 正文色 `textPrimary`，字号 15–18
- 最多 2 行，超出 clamp
- 语义：认领 + 正反馈

### 4.4 模式 B · 你想说但没说出来的

```
Cooking dinner · seen 4× · 4 days ago
The sauce came out way too salty tonight.        ← target_expression，衬线主角
你说的是「今天的酱汁太咸了」                        ← user_original，小字 muted
```

- **主角永远是目标语言那一行**。卡片是练习入口，不是回忆本
- **无引号**（母语原话不是目标语言产出）
- 母语句用小字、非衬线、`textMuted`，明确降级为注脚
- 语义：呈现 gap，且呈现方式是"这件事你可以这么说"，不是"你说不出来"

### 4.5 模式 C · 你拍下的场景

```
Cooking dinner · 📷 from your photo · 4 days ago
The sauce came out way too salty tonight.
```

- `target_expression` 作主角，衬线
- **无引号**，且**必须有来源标记**（`from your photo` 或极小相机图标）

**来源标记不可省。** 用户若误以为这句是自己说的，一旦察觉不是，整张卡的信任即刻崩塌——这比不展示任何内容更糟。

**内容供给有保证**：`generate` 的纯图片分支中 `target_expression` 与 `native_meaning` 均为 REQUIRED、never null（`index.ts:126-136`）。

**认领感来自照片而非语言。** 模式 C 里没有用户自己的目标语言产出，但照片本身是他拍的——证据从语言换成视觉，框架照样成立。

### 4.6 模式 D · 词 chips 兜底

```
6 words waiting to be used
[ back up ] [ glitch ] [ firmware ] [ sync ] [ latency ]
```

- 数量**固定 4–6 个**，按词长做打包预算，装不下就少放
  - 现状 `.chips` 用 `flex-wrap` + 固定高度容器，溢出会被裁掉半行，视觉脏
- 排序：**最近攒的 + `spoken_count = 0`（还没说过的）** 优先
- 文案改为有指向性的：`6 words waiting to be used` 优于 `You've been collecting these here`（CTA 是"去说"，chips 应当呼应）

### 4.7 模式切换的高度对齐

A 为 2 行，B/C 为 3 行。底部容器取固定高度（§2.3），A 模式下留白居上对齐，不得让卡片在列表滚动中跳动。

---

## 五、meta 行与时间

### 5.1 组成

```
{scene_detail} · seen {N}× · {relative_time}
```

### 5.2 `seen N×` 的语义澄清

`seen N×` 是**场景频次**（这个 scene_detail 重复出现过 N 次），不是分类频次。

- **场景频次留**：反复发生的事才有复用价值，它是"值得练"的直接理由
- **分类频次不上卡**：它是排序的解释，不是内容，对用户是弱自恋价值
- 沿用现状：`occurrence_count > 1` 时才显示

### 5.3 时间字段（新增）

- 取值：**被选中那条 material 的 `created_at`**，不是 sub_scene 的 `MAX(created_at)`
- 按 §3.1 的同源约束，重构后自动满足
- 现状 `Tab2SubScene` 无时间字段，需新增（§9.2）

### 5.4 时间展示粒度

`today` / `yesterday` / `N days ago` / `last month` / `earlier`

**不精确到小时。** 精确时间戳让人觉得被监视，且对学习无意义。

---

## 六、顶部拼图的数据供给

### 6.1 取图规则

> **最近 5 张，按 `material_id` 去重，`created_at DESC`。**
> **若 featured 自带照片，该照片强制置于 slot 1**（§3.6）。
> **若分类恰好只有 1 张照片，featured 反向绑定到该照片所属 material**（§3.5）。

### 6.2 必须新增 category 级字段

**不能从 `sub_scenes[].image_url` 拼图。** 现状有双重不可控：

1. `sub_scenes` 按 `occurrence_count DESC` 排序，拿到的是"最高频场景的图"而非"最近的图"
2. 每个 `image_url` 是独立子查询各自选的（§8.1 的 bug）

RPC 应直接返回有序数组：

```json
"hero_photos": [
  { "material_id": "...", "image_url": "...", "is_featured": true  },
  { "material_id": "...", "image_url": "...", "is_featured": false }
]
```

最多 5 条，slot 1 为 featured（若有），其余 `created_at DESC`。

### 6.3 预设图判定

> **"零真实照片 → 换预设插画"的判定基于 `hero_photos` 是否为空。**

判定源与渲染源必须统一，不得再用"sub_scenes 里有没有 image_url"。

---

## 七、CTA

### 7.1 形态

- 从卡内整条大按钮 → **右下角短 pill**
- 文案缩短：`Start talking` → `Talk` + 箭头
- 释放的垂直空间用于 §2.3 的高度收缩

### 7.2 视觉权重

整张卡可点（现状 `Tab2HeroCard` 已是 `Button`）。因此 CTA **不是功能按钮，是 affordance 提示**。

- 视觉要轻：描边或次要色，不与主角句抢注意力
- 真正驱动点击的是原话，不是按钮

### 7.3 退化策略

首次使用显示文字 pill；用户完成过 N 次对话后，退化为 44pt 圆形箭头图标，零文案。

---

## 八、现存 bug 与修法

### 8.1 三个独立子查询导致图 / 话 / 时间不同源

**现状**（`20260811010000_sub_scene_add_target_expression.sql`）：`quote`、`target_expression`、`image_url` 是三个各自独立的标量子查询，各自 `ORDER BY lo.created_at DESC LIMIT 1`。

一个 `sub_scene` 聚合的是历史上**所有**打过该 `scene_detail` 的 material，因此三者可能来自三条不同的素材。

**具体失效场景**

| 时间 | material | 图片 | user_original |
|---|---|---|---|
| 7/20 | A | ✅ 牛排照片 | ❌ 只拍照没打字 |
| 8/05 | B | ❌ 没配图 | ✅ "The sauce came out way too salty tonight" |

`image_url` 选中 A，`quote` 选中 B → 卡片渲染为「牛排照片 + 酱汁太咸了」，而这两件事相隔半个月。

`Tab2HeroCard.featuredMoment` 中大图与 quote 上下贴合渲染，用户读到的就是"这句话在解释这张图"。

**这个 bug 现在线上已经存在**，只是缺乏对照信息，用户无从戳穿。一旦加入时间字段（§5.3），它会立刻变成可感知的错误。

**修法：`DISTINCT ON` 选定一行，取其全部字段。**

```sql
featured AS (
  SELECT DISTINCT ON (lo.scene_category)
         lo.scene_category,
         lo.scene_detail,
         m.id                                  AS material_id,
         m.raw_content->>'user_original'       AS user_original,
         m.raw_content->>'target_expression'   AS target_expression,
         m.raw_content->>'native_meaning'      AS native_meaning,
         m.raw_content->>'source_image_path'   AS image_url,
         lo.input_lang,
         lo.source_direction,
         lo.source_granularity,
         m.created_at,
         sc.occurrence_count
  FROM   lexicon_occurrences lo
  JOIN   materials       m  ON m.id  = lo.source_id
  JOIN   lexicon_entries le ON le.id = lo.entry_id AND le.status = 'active'
  JOIN   scene_counts    sc ON sc.scene_category = lo.scene_category
                           AND sc.scene_detail   = lo.scene_detail
  WHERE  lo.user_id = p_user_id
    AND  lo.scene_category IS NOT NULL
    AND  lo.scene_detail   IS NOT NULL
    AND  lo.source_granularity <> 'word'
  ORDER  BY lo.scene_category,
            /* ① 方向 × 粒度 */
            CASE
              WHEN lo.source_direction='express'    AND lo.source_granularity='sentence' THEN 1
              WHEN lo.source_direction='express'    AND lo.source_granularity='passage'  THEN 2
              WHEN lo.source_direction='comprehend' AND lo.source_granularity='sentence' THEN 3
              WHEN lo.source_direction='comprehend' AND lo.source_granularity='passage'  THEN 4
              ELSE 9
            END,
            /* ② 意图明确度 */
            CASE
              WHEN m.raw_content->>'source_image_path' IS NOT NULL
               AND m.raw_content->>'user_original'     IS NOT NULL THEN 1
              WHEN m.raw_content->>'user_original'     IS NOT NULL THEN 2
              ELSE 3
            END,
            /* ③ 新鲜度 */
            CASE WHEN le.spoken_count = 0 THEN 0 ELSE 1 END,
            /* ④ 场景高频 */
            sc.occurrence_count DESC,
            /* ⑤ 兜底 */
            m.created_at DESC
)
```

注意 `DISTINCT ON` 的分组键是 **`scene_category`（分类级）而非 `scene_detail`**——底部只展示一条 featured moment，不再需要每个 sub_scene 各出一条（§9.4）。

`occurrence_count` 仍需单独 `GROUP BY` 聚合后 join 回来：它是"这个场景发生过几次"，本就不属于任何单行。

### 8.2 `length(user_original) >= 6` 阈值中英混用

**现状**：同一个字符数阈值同时作用于中文和英文原话。

- 中文：6 个字 = 一句完整的话 ✅
- 英文：6 个字符 = `I'm ok` ❌

**修法**：按 `input_lang` 分别设阈值。

| `input_lang` | 阈值 |
|---|---|
| `native`（中文） | 字符数 ≥ 6 |
| `target`（英文） | **词数 ≥ 4** |
| `null`（纯图片） | 不适用，走模式 C |

### 8.3 passage 素材的长度预算

`granularity = 'passage'` 且被选为 featured 时（①档第 2 位，罕见），`user_original` 可能很长。

- 服务端做字符预算：截断至 ~120 字符，在从句边界（`that / because / but / and / when`）切分，末尾加 `…`
- **绝不从词中间硬切**
- 前端 `lineLimit(2)` / `-webkit-line-clamp: 2` 保留为第二道防线，但不能作为唯一手段——clamp 裁到只剩半句时省略号救不了语义

### 8.4 其他边界

| 情况 | 处理 |
|---|---|
| 分类未解锁（`word_count < 20`） | 沿用现状锁态，不进入本文的模式分支 |
| 零 sub_scene | 模式 D |
| 签名 URL 过期 / 图片加载失败 | 单张失败 → 该 slot 用 `placeholder`；全部失败 → 降级为预设插画 |
| `scene_detail` 超长 | meta 行单行截断，优先保 `seen N×` 与时间 |
| `target_expression` 为空且 `user_original` 为空 | 该 material 不参选 featured（理论上不应出现，见 §12.1） |

---

## 九、数据层改造清单

### 9.1 `get_tab2_home` 重构

按 §8.1 的 `DISTINCT ON` 结构重写。新的 category 对象：

```json
{
  "scene_category":   "...",
  "word_count":       42,
  "unlocked":         true,
  "last_material_at": "...",
  "moment_count":     5,
  "hero_photos":      [ { "material_id": "...", "image_url": "...", "is_featured": true } ],
  "featured": {
    "scene_detail":      "Cooking dinner",
    "occurrence_count":  4,
    "material_id":       "...",
    "user_original":     "...",
    "target_expression": "...",
    "native_meaning":    "...",
    "image_url":         "...",
    "input_lang":        "target",
    "source_direction":  "express",
    "source_granularity":"sentence",
    "created_at":        "...",
    "spoken_count":      0
  },
  "preview_words": ["...", "..."]
}
```

### 9.2 `Tab2HomeData.swift` 模型变更

- 新增 `Tab2FeaturedMoment`（含 `inputLang` / `createdAt` / `sourceDirection` / `sourceGranularity` / `spokenCount` / `materialId` / `nativeMeaning`）
- 新增 `Tab2HeroPhoto`（`materialId` / `imageUrl` / `isFeatured`），沿用 `stableImageKey` 的签名剥离逻辑
- `Tab2CategoryData` 新增 `heroPhotos` / `momentCount` / `featured`
- `created_at` 解析复用现有的 fractional-seconds 双格式兜底

### 9.3 `moment_count`（供顶部 `+N`）

`+N more moments` 已上移顶部，其数值 = 该分类下 sub_scene 总数 − 已在拼图中呈现的数量。需由 RPC 直接给出计数，不再由前端从数组长度推算。

### 9.4 `sub_scenes` 数组的去留

底部只展示一条 featured moment，`+N` 已上移，**`sub_scenes` 完整数组不再有消费方**。

建议：本次改造中移除该字段，改为 `moment_count` + `featured`。这能显著简化 RPC（去掉三个相关子查询）并减小 payload。

**前置确认**：`Tab2CategoryRow`、`MomentRow` 是否还有其他消费点（§9.5）。

### 9.5 兼容与回滚

- 新旧字段并行发布一个版本：RPC 同时返回 `sub_scenes`（旧）与 `featured` / `hero_photos`（新），客户端灰度切换后再删旧字段
- migration 只 `CREATE OR REPLACE FUNCTION`，不改表结构，回滚 = 重新部署上一版函数

---

## 十、`generate` 侧改动：纯图片的 direction

### 10.1 现状与问题

`generate/index.ts:114-131`：纯图片（无附带文字）→ `sentence + comprehend`（s2），`user_original = null`、`input_lang = null`、`intent = null`。

判据是 `OBJECT is entirely in the target language → comprehend`。纯图片没有 text object，因此它不是**被判定**为 comprehend，而是**掉进默认分支**。

旁注暴露了真实顾虑：

> "A bare photo with no typed text carries no reliable signal about which word the user wants."

这句话说的是**意图不明确**，不是方向不明确。两件事被压进了同一个字段。

### 10.2 结论：改为 `express`

`direction` 回答的是**用户在跨语言边界的哪个方向上移动**：

- 从自己的世界 → 目标语言 = `express`
- 从目标语言 → 自己的理解 = `comprehend`

拍下周围场景、拿到一句英语描述——用户明确是从自己的世界往目标语言走。这是 `express`。

"AI 替他选了描述什么"影响的是**意图强度**，已由排序键 ②（§3.3）承载，不应污染 `direction`。

### 10.3 改动清单

| 位置 | 改什么 | 风险 |
|---|---|---|
| `generate/index.ts` 纯图片分支 | `direction: comprehend → express`；卡型 `s2 → s6` 或新开一型 | 需确认目标卡型的输出契约容许 `user_original = null` |
| `intent` | 写入 `native_meaning` 归一化结果，并标 `intent_source='inferred'`（§10.4） | 中。需新增列 + 收窄既有聚合查询与部分索引 |
| `lexicon_occurrences` | 新增 `intent_source` 列（§10.4.3） | 低。纯新增可空列，不改既有行 |
| `rawContent.ts` / `rawContent_test.ts` | 断言更新（现有 test 明确断言 `comprehend`） | 低 |
| `record_lexicon_material_units` RPC | 确认 `input_lang = null` 时不会被枚举校验拒绝 | 低（RPC 已有 coerce-to-null 逻辑） |
| 成长层统计 | 照片捕获的词计入表达侧而非理解侧 | **需产品确认**——本文认为符合预期 |

### 10.4 纯图片的 intent 归属

#### 10.4.1 拍照是有意图的，但意图的粒度是「场景」不是「命题」

拍照发生在学习 app 内：用户打开应用、对准某物、提交。这是一次明确的主动行为，**意图存在**，不能当作"用户没想表达"。

但用户指定的是**指向**，不是**命题**。一张厨房照片背后可能是：

- 今天做了番茄炒蛋
- 厨房好乱
- 这个锅是新买的
- 油烟机英语怎么说

**用户指定了"这个场景"，没有指定"关于这个场景的哪句话"。** AI 从这些可能里挑了一个。

而 `intent_text` 的粒度是**命题级**的——"很累"、"太咸了"是完整的意思单元，它之所以能聚合正是因为它是命题。把 AI 四选一的结果写进去，记录的不是用户的意图，是 **AI 替用户做的那次选择**。

#### 10.4.2 拍照的真实意图已经被正确记录了

用户指向的那个场景 = **`scene_detail`**。

这是拍照意图的忠实表示，粒度刚好对齐：用户指定到场景，系统就记到场景。"这个用户反复想聊 Cooking dinner"这个信号是真实的、可聚合的，且已经在库里。

**所以不是"丢掉了用户的意图"，是它已经被存在了正确的列上。**

#### 10.4.3 决策：新增 `intent_source` 列

保留意图、标注来源，不做交互改动。

```sql
ALTER TABLE lexicon_occurrences
  ADD COLUMN intent_source text
  CHECK (intent_source IN ('stated','inferred'));
```

| 值 | 含义 | 写入条件 |
|---|---|---|
| `stated` | 用户用母语说出来的意图 | `user_original` 非空且 `input_lang = 'native'` |
| `inferred` | AI 从照片推出的意图 | 纯图片素材（`user_original IS NULL`） |
| `null` | 不适用 | comprehend 来源 |

**配套规则**

1. **纯图片素材：`intent_text` 写入 `native_meaning` 的归一化结果，`intent_source = 'inferred'`。**
2. **所有既有的意图频率与同义组聚合（PRD §5.2.7）默认只取 `intent_source = 'stated'`。** 查询必须显式带上这个条件，不得依赖调用方自觉。
3. 需要更大样本时可纳入 `inferred`，但必须**降权**，且产品文案不得基于 `inferred` 对用户做断言（见下）。
4. `20260728000000` 中 `idx_lexicon_occurrences_user_intent` 的部分索引条件相应收窄为
   `WHERE intent_text IS NOT NULL AND intent_source = 'stated'`。

#### 10.4.4 为什么必须隔离，不能混在一起

**1. 会把 AI 的口头禅统计成用户的需求。**
用户随手拍了 10 张办公室照片，AI 每次都描述成"办公室里很忙碌"。聚合显示该 intent 频次极高 → 系统判定"用户反复想表达办公室很忙"→ 推相关练习。但用户可能只是顺手按了快门。**系统在统计模型自己的语言习惯，还以为是在统计用户。**

**2. 聚合结果会向模型风格收敛。**
AI 描述场景有系统性的句式与用词惯性。这些惯性经回译进入 intent，样本量一大，聚合出的"用户高频意图"实际是模型的措辞分布。这个信号越用越假，且**从数据形态上完全看不出来**——它长得跟真数据一模一样。

**3. 不可证伪，直接撞可信度主线。**
基于污染后的 intent，产品会说出"你经常想说 X，来练一下"。但用户从没说过 X，他自己都无法确认这个判断从何而来。这与本文全篇在守的可信度（§4.1 引号约束、§4.5 来源标记）是同一条线——一处松了，全线都松。

**4. 语义不对称。**
用户输入的母语原话是"想说但说不出来"的证据（`is_known_gap` 建立在此之上）。AI 回译不构成 gap——用户没有在目标语言上尝试并失败。混记会**虚增用户的表达缺口**。

#### 10.4.5 边界

**能展示 ≠ 能入账。** `native_meaning` 在卡片上是必要的（模式 C 里用户需要它才能看懂那句英文），本节限制的只是它进入 intent 聚合的路径。

### 10.5 连带影响

**1. 模式 C 从罕见态变为常态。** 纯图片升入 ①档后会经常成为 featured。可接受：照片本身承担认领感（§4.5）。但 `from your photo` 来源标记因此变得更关键。

**2. 主从绑定命中率上升。** featured 自带照片将成为多数情况，§3.6 的 slot 1 标记从"偶发加分"变为常态。

**3. 需盯的风险。** 重度拍照用户的 Tab2 可能长期只推模式 C，卡片里一句用户自己的话都不出现。由 §2.4 的列表级多样性约束兜底。

### 10.6 发布单元

**本节应拆为独立发布单元。** 它改动 prompt 与线上账本语义，与卡片改造不是同一个风险面。建议顺序：

1. §10（generate direction）单独发布 + 线上验证
2. §8/§9（RPC + 模型）
3. 前端（§11）

---

## 十一、前端改造清单

| 文件 | 改动 |
|---|---|
| `Tab2HeroCard.swift` | 顶部拼图组件（c1–c5 布局）+ 预设插画组件；`categoryHeader` 移入拼图叠加层；`+N` 移至顶部 |
| `Tab2HeroCard.featuredMoment` | 拆为模式 A / B / C 三个 `@ViewBuilder`，按 §4.2 判据分发 |
| `Tab2HeroCard.ctaButton` | 改为右下角 pill，权重降级（§7.2） |
| `MomentRow.swift` | `+N` 上移后底部不再列其他 moment，确认是否可删 |
| `Tab2HomeData.swift` | 按 §9.2 变更 |
| 新增 | `HeroCollageView`（拼图布局）、`CategoryPresetArtView`（12 张预设图） |
| 设计 token | 衬线用 `design: .serif`；muted 注脚用 `AppTheme.Color.textMuted`；来源标记用 `textMuted` + 11pt |

---

## 十二、验收标准

### 12.1 同源性（可断言）

- 同一张卡的 `image_url`（slot 1 且 `is_featured=true` 时）、`user_original` / `target_expression`、`created_at` 必须来自同一 `material_id`
- 单图分类：`hero_photos[0].is_featured` 必须为 `true`

### 12.2 引号约束

- 模式 B、C 下**不得出现引号**
- 模式 C 必须渲染来源标记

### 12.3 排序规则样例用例

每层排序键各设一条用例：

| 用例 | 构造 | 期望 featured |
|---|---|---|
| ① | 同分类下 1 条 sentence-express + 1 条 sentence-comprehend | express 那条 |
| ② | 同为 sentence-express：图+文 / 纯文字 / 纯图片各一条 | 图+文那条 |
| ③ | 两条同档，一条 `spoken_count=0`、一条 `>0` | `=0` 那条 |
| ④ | 两条同档同新鲜度，`occurrence_count` 4 vs 1 | 4 那条 |
| ⑤ | 其余全同，`created_at` 不同 | 最新那条 |

### 12.4 真机截图清单

模式 A / B / C / D × 拼图 c1 / c3 / c5 / 预设图，共 8 组关键组合。

---

## 十三、待验证 / 待决策

### 13.1 模式 C 的真实规模

`generate` direction 改动前，跑以下查询确认分布：

```sql
SELECT lo.input_lang,
       lo.source_direction,
       lo.source_granularity,
       (m.raw_content->>'source_image_path' IS NOT NULL) AS has_image,
       (m.raw_content->>'user_original'     IS NOT NULL) AS has_original,
       (m.raw_content->>'target_expression' IS NOT NULL) AS has_target,
       COUNT(*)
FROM   lexicon_occurrences lo
JOIN   materials m ON m.id = lo.source_id
WHERE  lo.scene_detail IS NOT NULL
GROUP  BY 1,2,3,4,5,6
ORDER  BY 7 DESC;
```

`has_target = false` 的总量即"无任何目标语言句子可展示"的规模。预期极低（`target_expression` 在多数卡型下为必填）；若非零，需补一个模式 E 或让这些 material 不参选。

### 13.2 §2.4 多样性约束的具体形式

"前 N 张中至少 1 张模式 A" 里的 N 取值，以及无法满足时是否降级（不强插）。建议先按 N=3、无法满足则不动。

### 13.3 语音输入上线后的影响

当前只有文字 + 图片。语音转写后 `user_original` 的形态（口语碎片、填充词）可能突破 §8.2 的阈值假设，需届时重估。

### 13.4 12 张分类预设插画的美术排期

独立美术产出，构图沿用 demo 的散点构图，配色换成品牌暖橙 / 暖纸（`--brand-200` / `#EBE6DE`），不用绿紫。这是本方案的硬前置——零照片分类占比未知，若较高则阻塞发布。

### 13.5 命题级拍照意图的升级路径（后续）

`intent_source = 'inferred'` 是过渡方案：它诚实地标注了"这个意图是 AI 猜的"，但没有把猜测变成事实。

真正的解法是让用户指定命题：

> 纯图片输入后，AI 给出 2–3 个候选描述，用户点选一个。

用户点下去的那一刻，命题级意图**真的被指定了**：`intent_source` 可写 `stated`，`user_original` 不再为空，`input_lang` 有值，该素材从模式 C 直接升格为模式 A/B，`generate` 里"no reliable signal about which word the user wants"的顾虑也随之消解。

代价是多一次点击，且改动落在 **Tab1 输入交互**，超出本文范围。建议作为独立方案评估，优先级取决于 §13.1 查出的纯图片素材占比。

### 13.6 `sub_scenes` 移除的消费方确认

见 §9.4。需检索 `Tab2CategoryRow`、`MomentRow` 及任何直读 `subScenes` 的代码路径。

---

## 附：本文推翻的三个既有判断（存档）

| 判断 | 提出理由 | 推翻理由 |
|---|---|---|
| 语言维度：`target` 优先于 `native` | 避免 gap 负担墙 | 与"意图强度"立论自相矛盾；负担感是文案与版式问题 |
| featured 必须从有图候选中选 | 保证图话同源 | 让高意图素材让位给低意图素材，同一错误 |
| 独立的"句子提取规则"章节 | 处理长输入 | 价值被排序键 ① 吸收（sentence 已优先于 passage）；剩余三条并入 §4.1 / §8.2 / §8.3 |
| 纯图片 `intent = null`，理由是"用户没尝试表达" | 避免污染意图聚合 | 前提错了——拍照是学习 app 内的主动行为，意图存在。真正的问题是**粒度**（场景级 vs 命题级），改由 §10.4 的 `intent_source` 隔离解决，意图不丢弃 |
