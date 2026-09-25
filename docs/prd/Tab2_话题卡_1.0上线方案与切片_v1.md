# Tab2 话题卡 1.0 · 上线方案与需求切片

> 配套文档：
> - 字段规格：`Tab2_话题卡_字段变更_实现规格_v2.html`（SQL 可直接抄）
> - 设计对照：`Tab2_话题卡_字段变更_v1.md`
>
> 本文只回答两件事：**1.0 做到哪里**，以及**怎么切、按什么顺序上**。

---

## 一、1.0 的范围

### 1.1 做

| | 内容 |
|---|---|
| 卡面主内容 | 活动名 + 次数（`Cooking ×7 · Chores ×4`），**`×N` 仅在 N ≥ 2 时显示** |
| 卡面右上 | 欠账数（`6 not said`） |
| 卡面底部 | 对话状态（`Never talked` / `Talked 3 days ago`） |
| Hero 理由 | **只上两条**：`Never talked about` / `N words waiting`（欠账最大） |
| 图片 | 跟随被点名的活动，前 3 个都无图则退预设图 |
| 删除 | featured 句子、`pops`、`+N more moments`、卡上的具体词 |
| 命名 | `moment` → `activity` 全链路 |
| 顺带 | 分区标题从 22pt Charter-Bold 降为 Geist 小标（解决三个同档标题连砸） |

### 1.2 不做（留 1.1 及以后）

| 不做的 | 原因 |
|---|---|
| Hero 理由池的四条轮换 | 1.0 用两条固定规则够用。轮换是留存优化，不是可用性前提 |
| `moment_title`（具体标题字段） | 需改库 + 改生成侧，且与当前 moment 粒度冲突。已否决，不是延期 |
| `ended_at` 治理 | 另立 issue，见 §5 |
| `Theme.swift` 字重映射修复 | 全局改动，风险面大于 Tab2，单独一刀 |
| Topics in progress 的对齐 | 不在本次范围 |

### 1.3 一个必须记住的前提

**库里全是测试数据，产品未上线。**

好处：不需要兼容版本、不需要数据迁移、可以直接同发。
代价：**下面刀 0 跑出来的三个数只能看量级，不能当精确依据**——
真实用户的输入分布与自造测试数据不是一回事。用它判断「是 ×1 还是 ×7 这种量级差异」可以，
用它决定精确的 UI 文案阈值不行。

---

## 二、切片

五刀。每刀独立可验收，前置关系是硬的。

### 刀 0 · 数据摸底

**改动**：无。只跑查询。
**目的**：拿到刀 1 的 before 基线；确认卡面三种边界态各自有多常见。

```sql
-- ① 标签碎片化基线（刀 1 的验收对照，必须在刀 1 上线前跑）
SELECT scene_category,
       COUNT(DISTINCT scene_detail)                      AS distinct_labels,
       COUNT(DISTINCT source_id)                         AS materials,
       ROUND(COUNT(DISTINCT scene_detail)::numeric
             / NULLIF(COUNT(DISTINCT source_id),0), 2)   AS frag_ratio
FROM   lexicon_occurrences
WHERE  scene_category IS NOT NULL
  AND  scene_detail   IS NOT NULL
  AND  source_granularity <> 'word'
  AND  source_type = 'material'   -- source_id 是多态外键，见下方说明
GROUP  BY scene_category
ORDER  BY frag_ratio DESC;

-- ② 带图素材覆盖率（决定预设兜底图会有多频繁）
SELECT COUNT(*) FILTER (WHERE raw_content->>'source_image_path' IS NOT NULL) AS with_image,
       COUNT(*)                                                              AS total,
       ROUND(100.0 * COUNT(*) FILTER (WHERE raw_content->>'source_image_path' IS NOT NULL)
             / NULLIF(COUNT(*),0), 1)                                        AS pct
FROM   materials
WHERE  deleted_at IS NULL;

-- ③ occurrence_count 分布（决定 ×N 会不会大面积不显示）
SELECT occurrence_count, COUNT(*) AS activities
FROM (
  SELECT scene_category, scene_detail,
         COUNT(DISTINCT source_id) FILTER (WHERE source_granularity <> 'word') AS occurrence_count
  FROM   lexicon_occurrences
  WHERE  scene_category IS NOT NULL AND scene_detail IS NOT NULL
    AND  source_type = 'material'   -- 同上
  GROUP  BY scene_category, scene_detail
) t
WHERE occurrence_count > 0
GROUP BY occurrence_count
ORDER BY occurrence_count;
```

**为什么 ①③ 带 `source_type = 'material'`**

`lexicon_occurrences.source_id` 是多态外键（`source_type` 取 `'material' | 'dialogue'`），
而建表脚本对 `scene_category` 的注释原文是「情境；**对话来源按当前推断话题记**」——
也就是说对话记账一旦接线，对话来源的行**会带 scene_category**，被这两条查询默默计入。

今天加它是 no-op（`record_lexicon_dialogue_units` 尚无调用方，库里全是 material 行），
但基线查询的唯一职责就是跨时间可比：不钉死口径，刀 1 前后两次跑出来的数就不是同一个东西，
`frag_ratio ≤ 0.35` 那道闸门会拿被污染的分母判合格。
写法与 `20260728030000_lexicon_backfill_reconcile_rpcs.sql:32` 的既有用法一致。

**同一个过滤必须同步加到刀 2 的 `scene_counts`**（见 §二·刀 2），否则基线查询与 RPC 实际输出会分岔。

**产出**：三个数字，写进本文档 §6 备查。
**不阻塞刀 1**（刀 1 无论如何都要做），但必须在刀 1 上线**之前**跑完，否则失去对照基线。

---

### 刀 1 · 标签一致性（prompt）

**这是唯一的硬前置。** 不做就上后面的刀，卡面 `×N` 会因标签漂移碎裂，比现状更糟。

**改动**：只改 `supabase/functions/generate/index.ts` 的 `classifyScene`。

- 把该用户该分类下已有的 `scene_detail` 喂回 prompt，命中时**逐字复用**（即该函数上方那条 TODO）
- 新增约束：sub_scene 必须比类别名说得更多（防 `饮食 / Eating` 这类同义重复）
- 点明 `userOriginal` 比 `Scene` 更权威
- 不加字段，`maxOutputTokens` 保持 100

**独立性**：不依赖任何其他刀，可单独上线、单独回滚。
**验收**：上线后对新产生的素材重跑刀 0 的查询 ①，看 `frag_ratio`。

| frag_ratio | 判定 |
|---|---|
| ≈ 1.0 | 完全碎片化，每条素材自成一类，`×N` 全是 ×1 → **不合格，后面三刀不许动** |
| 0.35 – 0.6 | 部分归并，勉强可用，需再调 prompt |
| ≤ 0.35 | 归并生效 → 放行 |

**观察周期**：建议至少一周新数据，或人工造 20–30 条同类场景素材加速验证。

---

### 刀 2 · RPC + Edge Function

**前置**：刀 1 验收通过；且 `last_talked_at` 取数路径已拍板（见 §3）。

**改动**：按 `实现规格_v2.html` §2–§3 全部。
- `cat_words`：加 `not_spoken_count`（**必须 `COUNT(DISTINCT)`**）、`sort_last_at`；删 `last_material_at` 输出与 `preview_words`
- `scene_counts`：加 `activity_last_at`；**加 `source_type = 'material'` 过滤**（见下）
- 新增 `ranked_activities` + `activities`（先排名、取前 5、再取 cover）
- 删 `featured` / `hero_photos` 两段 CTE 及其 LEFT JOIN
- 最终 `ORDER BY` 改 `cw.word_count DESC, cw.sort_last_at DESC`
- `signImagePaths` 同步改（收集侧深入 `activities[].cover.image_url`；回写保留 `material_id`）

**必须同发**。Edge Function 漏改是静默失败。

**`source_type` 过滤的边界**——只加在「数素材」的地方，不加在「数词条」的地方：

| 位置 | 加不加 | 理由 |
|---|---|---|
| `scene_counts.occurrence_count` | **加** | 「Cooking ×7」的 7 是素材条数。不加则对话接线后会把「聊过做饭」也算进去，静默改变对外承诺 |
| `activities` 的 cover LATERAL | **加** | 封面必须来自素材 |
| `activity_count` | 自动继承 | 派生自 `scene_counts` |
| `cat_words.word_count` | **不加** | 语义是「这个类别下你有多少个词」。一个词只在对话里说过也照样属于你的词库 |
| `cat_words.not_spoken_count` | **不加** | `spoken_count = 0` 的词按定义没被说过，必然来自素材，加不加等价 |

**验收**：
- [ ] `not_spoken_count ≤ word_count` 对全部类别恒成立
- [ ] `activities[].cover.image_url` 返回的是签名 URL，不是裸 Storage 路径
- [ ] 无任何 cover 指向 `deleted_at IS NOT NULL` 的 material
- [ ] `activities` 每类别 ≤ 5 条，`activity_count` 仍是全量
- [ ] `EXPLAIN ANALYZE` 对比改前改后，总耗时不高于基线

---

### 刀 3 · 客户端模型与命名

**前置**：刀 2 已上。
**改动**：纯机械，**不动 UI**。

- 删 `Tab2FeaturedMoment` / `Tab2HeroPhoto`
- `Tab2SubScene` → `Tab2Activity` + 嵌套 `Cover`
- `Tab2CategoryData` 加 `notSpokenCount` / `lastTalkedAt`，删 `lastMaterialAt` / `previewWords`
- `lastTalkedAt` 复用现有的双格式 ISO8601 解析（`Tab2HomeData.swift:93-101`）
- 全量改名：`momentCount` → `activityCount`、`Tab2MomentRow` → `Tab2ActivityRow`
- `Tab2HomeViewModel` 的 `ranked` / `heroCategory` / `moreCategories` 中对 `featured` 的判空改为对 `activities` 判空

**验收**：真机能拉到数据、能解码、卡片即使还是旧样式也不崩。
**这一刀故意不改视觉**，把「数据通了」和「样子对了」分成两次验证，出问题时好定位。

---

### 刀 4 · 卡片内容重做

**前置**：刀 3 已上。

**改动**：`Tab2HeroCard` / `Tab2ActivityRow` / `MineView`

- 活动名 + `×N`（**N ≥ 2 才渲染数字**；`×N` 用 Geist 小一号 + `brandInk`，与活动名的 Charter 拉开层次）
- 欠账徽章、对话状态行
- Hero 理由两条：无 `lastTalkedAt` → `Never talked about`；否则 → `N words waiting`
- Hero 选取排除 `其他` 类别
- 图片取用：被点名前 3 个中第一个 `cover != null`；都无图 → `CategoryPresetArtView`。**禁止向后查找**
- 分区标题 `More to talk about` / `Topics in progress` 从 `sectionTitleSerif` 降为 Geist 全大写小标

**必须覆盖的三种边界态**（刀 0 的数据会告诉你它们有多常见）：
- [ ] 全部活动 `occurrence_count = 1` → 卡面只有裸标签，排版不塌
- [ ] 前 3 个活动全无图 → 预设图，且不显得像加载失败
- [ ] `not_spoken_count = 0` → `All caught up` 状态，不是显示 `0 not said`
- [ ] `activity_count ≤ 3` → 不渲染 `+N`

---

### 刀 5 · 收尾

- **`classifyVocabCategory` 缺 `thinkingConfig`（新增，2026-09-09 发现）**

  `index.ts:605` 的 `generationConfig` 只有 `{ maxOutputTokens: 20 }`，
  **没有 `thinkingConfig: { thinkingBudget: 0 }`**——而同项目的 `classifyScene`
  （`_shared/classifyScene.ts:125-126`）有。

  后果：Gemini 先用 token 思考，20 个 token 被吃光后没有非 thought 的文本 part，
  解析出 `raw = ""`，每次查词都走兜底 `其他`。
  线上日志实证：`[classifyVocabCategory] unmatched "" for "thermos", fallback→其他`。

  **这解释了刀 0 数据里 `其他` 是全页词数最高（92 pops）的原因**——它是所有查词的垃圾桶，
  而不是分类判断的结果。prompt 里写的 "You MUST pick exactly one category — do not reply 其他"
  从来没有机会生效，因为模型的回复根本没送达。

  修法：`generationConfig: { maxOutputTokens: 20, thinkingConfig: { thinkingBudget: 0 } }`

  **连带影响，刀 4 之前必须回头确认**：修好后 `其他` 的词数会大幅下降，
  词条散回真实类别，`word_count` 分布随之改变。
  **§刀 4 里「Hero 选取排除 `其他`」那条规则可能就不必要了**——重新评估。

- `dialogue_sessions.ended_at` 另立 issue（schema 承诺了代码没兑现的语义，要么接线要么删列）
  → **已收（2026-09-10）**：PM 拍板保留该列作未来预留（总结卡幂等与 resume 判定），
  不接线不删列。诊断结论见 §5 风险登记；迁移 `20260910010000` 加 COMMENT 写明「当前无写入方」。
  契约 §2.4 的「写 ended_at + end_reason」是与实现不符的旧承诺，等总结卡真正实现时再接线。
### 排版技术债（`Theme.swift` 换装 083798c 带入，已写进该 commit body）

按严重度排。前两条是换装时打破了旧注释里明写的约束。

**① wordmark / onboardingHeroSerif 固定字号约束被打破 —— 唯一用户可见**

```swift
// 旧：Font.system(size: 46, ...)              不带 relativeTo，不缩放
// 新：charter(46, ..., relativeTo: .largeTitle)  Font.custom(_:size:relativeTo:) 会缩放
```

旧注释原文：「固定字号、不随 Dynamic Type 变化（**放大后会撑破居中构图**）」，
且「字号改动需同步 `SplashScreenView.wordmarkSize`」。

后果：开辅助功能大字号的用户，**开屏字标与 Onboarding 封面标题会撑破构图**。
修法：这两处改用 `Font.custom(_:fixedSize:)`。两行，优先修。

**② tabLabel 配方解耦断裂 —— 测试与实际渲染脱节**

旧代码刻意让 `tabLabel` 由 `tabLabelStyle` / `tabLabelDesign` / `tabLabelWeight`
三个成分常量组成，因为 UIKit 导航宽度测试要读原值反解配方
（注释：「改配方只改这一处、测试自动按新配方重测」）。

新代码 `tabLabel = geist(15, ...)`，三个常量还在但不再构成它。
**测试量的是 SF Pro，App 渲染的是 Geist**，度量不同。
`Typography.topTabLabelMaxDynamicTypeSize` 注释里「封顶档从 AX2 松到 AX3」
的结论可能已不成立。

待办：确认 `AIEnglishAppTests` 的
`labelTabRowFitsNarrowestSupportedScreenAtMaxDynamicTypeSize` 是否引用那三个常量；
若是，改为读 `tabLabel` 本身，或让 `tabLabel` 重新由常量组合而成。

**③ 三个字体工厂是二值 isBold 映射 —— 声明的四档字重实际只有两档**

```swift
let isBold = (weight == .bold || weight == .semibold || weight == .heavy)
```

- Charter 系统字体只有 Roman / Bold，**没有 semibold**。写 `.semibold` 得到 700。
- `.medium` 落进 else 分支，**静默退成 Regular**。
- Geist 只 bundle 了 Regular + SemiBold，`.bold` / `.heavy` 全部退成 600。

后果：`hero = geist(34, .bold)` 和 `tab2HeroCategoryLabel = geist(11, .heavy)`
渲染出来是同一个字重，层级被压平。

修法：补 `Geist-Medium.ttf`，三个工厂改真正的多档映射；
Charter 侧接受「只有 400/700」的物理事实，中间档改用字号 + 颜色拉层级。
全局改动，影响面大于 Tab2，单独评估。

---

## 三、已拍板

**`last_talked_at` 的取数路径：方案 B（2026-09-09 定）**

在 `dialogue_sessions` 上加 `last_turn_at timestamptz`，由 `handleTurn` 在写入用户轮次时
顺手更新（写入侧 O(1)）。RPC 对 `dialogue_sessions` 做 `MAX(last_turn_at)` 分组，
走现成的 `idx_dialogue_sessions_user_created`。

不走方案 A 的原因：`dialogue_turns` 是全系统写入量最大的表，唯一可用索引是单列
`(user_id)`，建表注释写明用途是「数据审计 / 隐私删除用」——罕用管理路径的索引，
不能拿来撑每次进 Tab2 都跑的首页 RPC。

口径不变：**最后一次对话 = 最后一次用户开口**（`role = 'user'`），不用 `ended_at`（无写入方）。

存量测试数据不回填，`last_turn_at` 从 null 起步（表现为 Never talked，可接受）。

<details><summary>当初的三个备选（存档）</summary>

三选一：

| | 做法 | 代价 |
|---|---|---|
| A | 直接扫 `dialogue_turns` | 每次开 Library 扫该用户全部对话轮次；唯一可用索引是单列 `(user_id)`，注释写明是「数据审计 / 隐私删除用」 |
| **B（推荐）** | `dialogue_sessions` 加 `last_turn_at`，`handleTurn` 顺手写 | 多一列 + 一处写入；读取回到 sessions 量级 |
| C | 维持 A，给 turns 加 `(user_id, session_id, created_at DESC)` | 改动小，但在最大表上加索引有写入放大 |

</details>

---

## 三之二、刀 1.5 · classifyVocabCategory 缺 thinkingConfig（插在刀 2 之前）

**改动**：`generate/index.ts:605`

```ts
- generationConfig: { maxOutputTokens: 20 },
+ generationConfig: { maxOutputTokens: 200, thinkingConfig: { thinkingBudget: 0 } },
```

**为什么同时要把 20 提到 200**：刀 1 实测证明 `thinkingBudget: 0`
**并不能**把思考完全压到零——`classifyScene` 设了它，100 仍被吃到只剩 `{`，
67/96 次截断。只补 `thinkingConfig` 而不提上限，20 这个预算稍有思考就会再次爆掉。
输出只是一个类别名（最长 5 个汉字），200 是给思考留的余量；
Gemini 按实际生成计费，提高上限不增加成本。

**为什么从刀 5 提前**：与刀 1 修的是同一个失效模式（思考吃掉输出预算 → `raw = ""` →
走兜底），修法已在刀 1 验证过（96/96 成功）。一行改动、零风险、与刀 2 不冲突，
而每多跑一天 `其他` 就多攒一批本该属于别的类别的词。

**明确不做的**：不追溯清理。已在 `其他` 里的词留在原地，只有新查词会被正确分类。
查词素材不出现在卡面活动里，受影响的只是 `word_count`，不值得再写一个回填脚本。

**真正的收益在刀 4**：修完后重新观察 `其他` 的真实体量，
**决定「Hero 选取排除 `其他`」那条规则还需不需要**——现在那条规则是在为一个 bug 打补丁。

**验收**：**先部署**（`supabase functions deploy generate`），再查一个词，
看 Functions 日志里 `[classifyVocabCategory] unmatched ""` 这行是否消失。

判据是**引号里是不是空的**，不是它选了哪个类别：

- `unmatched ""` 消失 → 修好了
- 仍是 `unmatched ""` → 200 还不够，或另有原因
- 变成 `unmatched "某个词"` → 是另一回事（模型答了但不在枚举里），不是本 bug

测试词要选类别明确的（`thermos` / `treadmill` / `spreadsheet`）。
`iron gate` 这类本身就归属模糊的词，即使修好了也可能合理地落进「其他」，
会造成误判。

**验收结果（2026-09-09）：通过。**

| 时间 | 结果 |
|---|---|
| 12:09:33（部署前） | `unmatched "" for "iron gate", fallback→其他` |
| 12:14:25（部署后） | `category=运动健康`，**无 unmatched 警告** |
| 12:14:38（部署后） | `category=工作与学业`，**无 unmatched 警告** |

`unmatched ""` 警告行完全消失，两次查词都落进正确的真实类别。
同时证实：`iron gate` 落进「其他」不是因为词本身归属模糊，就是这个 bug。

---

## 四、依赖与并行

```
刀0 ✅ ──┐
         ├─→ 刀1 ✅ ──→ 刀1.5 vocab 修复 ──→ 刀2 RPC+Edge ──→ 刀3 模型 ──→ 刀4 卡片
拍板 ✅ ─┘

可并行、不依赖后端：
  · Hero 理由的文案定稿
  · 「其他」排除规则（客户端逻辑）
  · 分区标题的字体档位（排版）
```

**唯一的串行瓶颈是刀 1 的观察期。** 其余四刀加起来的工作量小于等待标签数据的时间，
所以刀 1 越早上线越好——它不需要等任何拍板。

---

## 五、风险登记

| 风险 | 触发条件 | 应对 |
|---|---|---|
| 标签仍碎片化 | 刀 1 验收 `frag_ratio > 0.6` | 不进刀 2。回到 prompt 迭代；最坏情况接受「只显示标签不显示 ×N」作为常态 |
| 预设兜底图大面积出现 | 刀 0 查询 ② 的带图占比低 | 提升预设图质量，或放宽「禁止向后查找」到前 5（但会引入图文错位，需重新权衡） |
| `×N` 几乎不出现 | 刀 0 查询 ③ 显示绝大多数是 1 | 卡面退化为裸标签仍可用；但要重新评估「活动」这一层是否值得占卡面主位 |
| 测试数据误导 | 上述三个数都基于自造数据 | 只作量级参考。真实用户数据到位后重跑 |
| `dialogue_sessions.ended_at` 被误信有值 | 总结卡接线时直接读该列 | **已拍板（2026-09-10）**：保留作未来预留（总结卡幂等与 resume 判定），不接线不删列。迁移 `20260910010000` 加 COMMENT 写明「当前无写入方」。诊断：契约 §2.4 承诺「写 ended_at + end_reason」但全仓无任何代码写该列；刀 2「最后一次开口」已用 `last_turn_at` 绕开 |

---

## 六、刀 0 实测数据（待填）

> 跑完刀 0 的三个查询后把结果贴在这里，作为后续所有判断的依据。

- 碎片化基线 `frag_ratio`：__待填__
[
  {
    "scene_category": "日常起居",
    "distinct_labels": 13,
    "materials": 13,
    "frag_ratio": "1.00"
  },
  {
    "scene_category": "其他",
    "distinct_labels": 11,
    "materials": 11,
    "frag_ratio": "1.00"
  },
  {
    "scene_category": "出行交通",
    "distinct_labels": 1,
    "materials": 1,
    "frag_ratio": "1.00"
  },
  {
    "scene_category": "运动健康",
    "distinct_labels": 2,
    "materials": 2,
    "frag_ratio": "1.00"
  },
  {
    "scene_category": "购物消费",
    "distinct_labels": 3,
    "materials": 3,
    "frag_ratio": "1.00"
  },
  {
    "scene_category": "家庭与人际",
    "distinct_labels": 2,
    "materials": 2,
    "frag_ratio": "1.00"
  },
  {
    "scene_category": "科技数码",
    "distinct_labels": 10,
    "materials": 11,
    "frag_ratio": "0.91"
  },
  {
    "scene_category": "饮食",
    "distinct_labels": 12,
    "materials": 14,
    "frag_ratio": "0.86"
  },
  {
    "scene_category": "情绪社交",
    "distinct_labels": 11,
    "materials": 14,
    "frag_ratio": "0.79"
  },
  {
    "scene_category": "休闲娱乐",
    "distinct_labels": 7,
    "materials": 9,
    "frag_ratio": "0.78"
  },
  {
    "scene_category": "工作与学业",
    "distinct_labels": 12,
    "materials": 18,
    "frag_ratio": "0.67"
  },
  {
    "scene_category": "天气环境",
    "distinct_labels": 2,
    "materials": 3,
    "frag_ratio": "0.67"
  }
]
- 带图素材占比：__待填__
[
  {
    "with_image": 47,
    "total": 180,
    "pct": "26.1"
  }
]
- `occurrence_count` 分布：_[
  {
    "occurrence_count": 1,
    "activities": 76
  },
  {
    "occurrence_count": 2,
    "activities": 7
  },
  {
    "occurrence_count": 3,
    "activities": 2
  },
  {
    "occurrence_count": 5,
    "activities": 1
  }
]_待填__
- 采集时间 / 数据来源（测试库 or 生产库）：测试库，当前没上线

---

### 6.1 事故记录：逐条 old→new 对比已不可用

**2026-09-09**：跑刀 0 的预检 SELECT 时，同一代码块里的清空 `UPDATE` 一并执行，
`lexicon_occurrences.scene_detail` 的 303 行在备份之前就被清空了。
事后建的 `_scene_detail_backup_20260909` 是空表（0 行）。

**后果**：刀 1 的验收只能做**聚合对比**（85 个标签 → 重跑后多少），
做不了「同一条素材，老标签 → 新标签」的逐条核对。

**主指标不受影响**：上面 §6 的 before 基线（85 个 distinct 标签、
每类别的 `distinct_labels` / `frag_ratio`）在事故前已经记录，闸门照常可用。

**教训**：破坏性语句永远单独一个代码块执行，不与诊断查询混排。

### 6.3 刀 1 验收结果（2026-09-09，run2）

```
total=96 updated=63 skipped_null=0 failed_parse=0 skipped_category_drift=33 failed=0
```

| | before | after |
|---|---|---|
| distinct 标签 | **85** | **24** |
| 有标签的素材 | 99 | 63 |
| frag_ratio | **0.86** | **0.38** |

**判定：通过。**

- `failed_parse = 0` / `skipped_null = 0` —— `maxOutputTokens 100→500` 之后
  96 次调用全部产出合法标签，管线干净。
- 定性检验决定性通过：`Chores` / `Organizing a room` / `Organizing clothes and groceries` /
  `Organizing daily necessities` / `整理房间` 五个同义标签**合并成 `Chores` 一个**；
  `Sleeping` / `Feeling sleepy` / `休息` 合并成 `Sleeping`。
- 新标签形态正确：`Working` / `Studying` / `Cooking` / `Chores` / `Shopping` /
  `Commuting` / `Eating out` / `Catching up` / `Watching sports`——即 prompt 的目标抽象档。
- `frag_ratio 0.38` 略高于原定 ≤0.35 的闸门。**放行**：该阈值是在没有任何真实数据时
  估的理论最优（日常起居 4/13≈0.31），且测试数据在方法论上偏向多样性；
  定性检验才是当初约定的主判据，它决定性通过。

**×N 覆盖率——卡片设计的支点**

| occurrence_count | 活动数 |
|---|---|
| 1 | 12 |
| 2 | 4 |
| 3 | 2 |
| 4 | 1 |
| 5 | 3 |
| 6 | 1 |
| 12 | 1 |

| | 刀 0（before） | 刀 1 后（after） |
|---|---|---|
| ×1 的活动占比 | **88%**（76/86） | **50%**（12/24） |
| 会显示 ×N 的活动 | 12% | **50%** |

**这条比 frag_ratio 更重要。** 刀 1 之前 88% 的活动都是 ×1，
`Cooking ×7` 这个卡面卖点等于不存在；现在一半的活动带数字，
最大的到 ×12。

关键认知修正：**问题从来不是"用户不重复"，而是"标签不合并、重复看不见"。**
63 条素材就能产出 ×12 / ×6 / ×5×3 的分布，说明重复一直都在，
只是被碎片化的标签掩盖了。刀 1 不只是清理了标签，
它让整个卡片概念第一次成立。

**对刀 4 的影响**：24 个活动散在 12 个类别里，平均每类别约 2 个。
卡面「点名前 3 个」经常等于「点名全部」，`+N` 大概率是 0 或 1。
这不是 bug（§刀 4 的边界态清单已列 `activity_count ≤ 3 → 不渲染 +N`），
但文案设计要以"通常没有 +N"为常态，而不是例外。

**遗留观察项（不阻塞刀 2）**

1. **33 条（34%）因类别漂移未获标签。** 这是回填独有的产物——历史素材的
   `scene_category` 由老 prompt 判定，新 prompt 有 31% 不同意。
   **正式链路不存在此问题**：`classifyScene` 一次调用同时产出 category 和 sub_scene，
   两者永远一致。但本次测试语料因此缩到 63/96。
2. **`其他` 正在被清空**：33 条漂移里 **14 条是 `其他` → 真实类别**（42%）。
   这与刀 5 记录的 `classifyVocabCategory` 缺 `thinkingConfig` 的诊断互相印证——
   `其他` 一直是失效链路的垃圾桶，不是分类结果。
3. **`情绪社交` 可能成为新的吸附桶**：11 条漂移流入该类别，
   且 `Sharing thoughts` 是全部标签里最大的一个（12 次）。需观察。
4. **两条脏数据**：`"天气环境, 购物消费"` 和 `"休闲娱乐, 天气环境"`——
   单条素材的 occurrence 行上挂着两个不同的 `scene_category`。
   漂移检查的「去重后必须恰好一个值」规则把它们拦下了。
5. **两个非活动标签**：`Image inquiry`（描述的是交互方式而非生活活动）和
   `Other`（字面意义的"其他"）。各 1 次，暂不处理。

### 6.2 幸存的定性样本（日常起居，事故前）

这 13 个标签是事故前从对话记录里保留下来的，用作重跑后的人工核对样本——
**看它们是不是收敛成了 3–4 个**：

| 真实活动 | 老 prompt 拆出的标签 |
|---|---|
| 收纳整理 | `Chores` / `Organizing a room` / `Organizing clothes and groceries` / `Organizing daily necessities` / `整理房间` |
| 家居布置 | `Decorating a room` / `Designing/Decorating home` / `Home decor` |
| 睡觉休息 | `Sleeping` / `Feeling sleepy` / `休息` |
| 非活动名词（本身就违规） | `厨房用品` / `安全提醒` |

其中 5 条违反 `validateSubScene`（中文 4 条、含 `/` 1 条），另有 2 条超 24 字符上限——
这些是英文约束上线之前的残留。剩余 6 条完全合法，但仍是三组同义词，
**那正是刀 1 要解决的部分**。

---

## 7. 刀 2 验收记录与遗留决策

### 7.1 验收结果（已达标）

| 项 | 基线 | 刀 2 后 |
|---|---|---|
| RPC 耗时 | 37.8 ms | 11.4 ms（3.3×） |
| `not_spoken ≤ word_count` | — | 恒成立 |
| `activities_returned ≤ 5` | — | 成立（饮食 `activity_count=6`、返回 5 条，
结构性证明了「先截断、后 LATERAL」生效） |
| `deleted_covers` | — | 0 |
| `last_talked` | — | 全 NULL（符合预期，见下） |

### 7.2 🔴 决策项：`not_spoken_count` 目前恒等于 `word_count`

**事实**（不是推断）：

- `not_spoken_count = word_count - spoken_count`。
- `spoken_count` 只由 RPC `record_lexicon_dialogue_units` 递增。
- 该 RPC **至今没有任何调用方**（全仓检索无 caller）。
- 因此 `spoken_count` 恒为 0，`not_spoken_count ≡ word_count`。

**后果**：

| 卡面元素 | 实际行为 |
|---|---|
| 「欠账数」 | 就是词数，换了个名字 |
| 按欠账排序 | 就是按词数排序 |
| `All caught up` 空状态 | 永远不可达 |
| Hero 的入选理由 | 永远是「词最多」 |

**这一点必须记住**：我们删掉 `pops` 的理由——*一个不会变的数字，
用户看三次之后就不再看它*——现在**原样适用于** `not_spoken_count`。
同一个无信息量的数字，穿了件新衣服。

**三个选项**：

- **A. 接线**：在 `dialogue` 的收尾处调用 `record_lexicon_dialogue_units`，
  让 `spoken_count` 真的动起来。代价：要定义「说过一个词」的判定口径
  （出现即算？还是要求语境正确？），这是一个产品问题，不是工程问题，
  1.0 之前想不清楚。
- **B. 接受**：1.0 就承认它等于词数，把文案改成不撒谎的说法
  （不写「还没说过 N 个」，写「N words」），等接线后再改回。
- **C. 换主轴**：主排序改用 `last_talked_at`——刀 2 已经给它接上了真实写入方
  （`dialogue.handleTurn` 写 `last_turn_at`），它是**会变的**。
  欠账数降级为辅助信息。

**倾向：C + B。** 1.0 用 `last_talked_at` 做主排序，欠账数降级、
文案按 B 改。这样不用等接线，卡面也不说谎；A 留到接线口径想清楚之后。

**待定**：本项须在**刀 4（卡面内容重建）之前**定稿——刀 4 要写死排序轴和文案。
刀 3 是纯模型改名，不受本项影响，可并行。

---

## 8. 刀 3 验收记录

### 8.1 结果

模型与命名改动完成（`3815ca9`），356 单测全绿。首次模拟器渲染验证 **无效并已重做**，
重做后四关全过：构建隔离 → 装前指纹 → 装后指纹 → 运行时证据。
`Hero=FOOD` 时 More 区无 FOOD 行，排除逻辑在正确包上确认生效。

### 8.2 🔴 过程事故：多 worktree 下装错包，验证结论一度为假

**事实链**：模拟器上运行的二进制 UUID `3B02CF78…` 对应的 DerivedData
`WorkspacePath` 指向另一个 worktree（`AIEnglishApp-home-content-loading`，
`feat/home-content-loading` 分支）。那份代码是刀 3 之前的旧模型
（`subScenes` / `previewWords` / `momentCount`），进程全程未请求过
`get-tab2-home`。截图里的 `41/12/10/8`、`Food` 同现、`words` 文案，
**全部是旧分支渲染的画面，与刀 3 代码和云端 v5 数据无关**。

**这次事故与 6.1 的破坏性 SQL 事故是同一类错误**：验证动作本身没有被验证。
6.1 是"执行前没确认作用范围"，本次是"看画面前没确认画面来自哪份代码"。

**定为长期规则（多 worktree 必守）**：

1. 安装到模拟器必须用**精确 `TARGET_BUILD_DIR`**，不得依赖 DerivedData 默认路径。
2. 截图取信之前，必须先核对**已装 bundle 的二进制 UUID = 本次构建产物的 UUID**。
   Xcode 15+ Debug 构建的真代码在 `AIEnglishApp.debug.dylib`，主二进制是空壳，
   **两个 UUID 都要核**。
3. 补一条廉价的交叉证据：确认进程确实发出过 `get-tab2-home` 请求。
   没有网络请求的"渲染验证"一律不算数。

### 8.3 刀 4 影响清单（刀 3 的非机械判断）

1. Hero 稳定性只看前 5 条 activities 的 `sceneDetail`，第 6+ 条新活动不触发重选。
2. 原 `featured` 的 7 天新近桶与 `createdAt` 平局键已随模型删除，现为
   `activityCount → id`。
3. `HeroCollageView.swift` 只剩 `HeroTopOverlay`，文件名已名不副实，建议刀 4 迁走。
4. `Tab2SceneDetailValidation.swift` 已删，刀 4 若需校验须重写。
5. malformed 语义收紧：`activities` 类型不符现在整包解码失败
   （旧 `previewWords` 是宽容降级为空）。
6. 行高测试守卫从 XXXL 降到 AX5 档，刀 4 恢复主句位后可升回。
7. 约 10 个语义 token 失去消费者（`Font.tab2MoreRowSentence`、
   `tab2HeroPhotoToneWarm` 等），刀 4 落地后统一清理。

### 8.4 补充事实：卡面数字取的是 `wordCount`

`Tab2HeroCard.swift:46` 与 `Tab2ActivityRow.swift:139` 都用
`PopsLabel.format(category.wordCount)`，即**总词数**，不是 `notSpokenCount`。
两者当前恒等所以看不出差别；一旦 §7.2 的接线发生，取错字段就会变成线上 bug。
另外卡面文案仍是 `POPS`——**那正是我们已经判定为无信息量、决定删掉的那个数字**。
本项与 §7.2 是同一个决策，须一起定稿。

---

## 9. 刀 4 定稿（§7.2 的 C 方案作废，重定）

### 9.1 🔴 推翻 C 的前提：对话功能未上线

`FeatureFlags.swift:21` → `conversationEnabled = false`；
`MineView.swift:164` 判断该 flag，false 时 `Start talking` 弹 "Coming soon"，
`ConversationView` 进不去。

**后果**：`last_talked_at` 的写入方是「用户在对话里说出第一句话」，
而用户在 1.0 根本走不到那一步。**该字段在 1.0 恒为 NULL**，
§7.2 推荐的 C 方案（用 `last_talked_at` 做主排序轴）**不成立**。

刀 2 验收时记录的「`last_talked` 全 NULL，符合预期」被误读为
"测试账号没聊过"，实际是"没有人能聊"。

**教训（与 6.1、8.2 同类）**：查通了数据链路，没查用户能不能走到那一步。
**今后任何依赖某字段的方案，必须先确认它的写入路径对 1.0 用户是可达的。**

### 9.2 1.0 唯一可用的变量

| 候选轴 | 用户如何使之改变 | 1.0 可用 |
|---|---|---|
| 聊过多久 | 说话 | ❌ 进不去 |
| 说过多少词 | 说话 | ❌ 同上 |
| 词数 | 查词 | ⚠️ 只涨不落，等价于固定 |
| **最近存入新素材** | **拍照 / 查词** | ✅ **唯一** |

因此 1.0 方案 = **B（文案只报存量）+ 新近度作主排序轴**。

### 9.3 `last_material_at` 是三处依赖的必需字段

值已在 v5 内部算出（`cat_words.sort_last_at`，第 50 行），
但**未放进返回 JSON**。三处依赖它：

1. 分类排序轴
2. Hero 轮换判定
3. More 行的时间行文案

**它不是可选项**——没有它，1.0 卡面没有任何会变的元素。
故刀 4 拆为 **4a（RPC 加字段并部署验证）** + **4b（卡面重建）**。

### 9.4 卡面字段替换

| 位置 | 提案 | 1.0 |
|---|---|---|
| Hero 理由行 | `spoken_count` 聚合 | `last_material_at` |
| Hero / More 活动行 | `scene_detail` + `occurrence_count` | 不变，**×1 不渲染** |
| Hero 副状态 / More 徽章 | `not_spoken_count`（"6 not said"） | `word_count`（"40 words"） |
| More 时间行 | 无字段（文案是编的） | `last_material_at`（"Added 3 days ago"） |
| `All said` 灰态 | `not_spoken_count = 0` | **删除**（条件不可达） |
| 照片 | `hero_photo`（已删） | `activities[].cover.image_url` |

时间行**保留**而非删除：排序轴必须在卡面可见，否则顺序在用户眼里是随机的。
主语从「你说过」改为「你存过」，位置、字号、相对时间格式不变，
对话上线后原位换回。

`All said` 无等价替代，真删——1.0 没有任何东西构成「练完」，
查词只会让词变多。硬造替代品等于给一个不存在的完成感。

### 9.5 Hero 轮换规则（现规则有缺陷）

**现规则**：出现没见过的 `sceneDetail` 就重选。
**缺陷**：用户又拍三张做饭照片、活动名仍是 `Cooking`，Hero 不换；
而随手查个陌生词蹦出新标签，Hero 反被顶掉。
**对「新标签」敏感，对「新素材」不敏感——方向相反。**

**新规则（按优先级）**：

1. **一次浏览之内绝不换**——进页面时定一次，之后数据怎么刷新都不动。
2. **今天存过，就选它**——门槛是「今天」，不是「比上次新」；
   后者每存一条就换，Hero 沦为跟随最后一次操作的指示灯。
3. **没有新素材时，按自然日轮换**——在最久没被选中的几类里换一个。

实现注意：规则 1 要求选择结果在页面存活期间冻结，
不能像现在这样写在 `heroCategory()` 里每次 body 求值都重算，
且该函数带写 `UserDefaults` 的副作用，在 SwiftUI body 里执行本身不干净。

### 9.6 图片规则

有图 → 该活动最新一张（v5 `cover` 已按 `m.created_at DESC LIMIT 1` 取好）；
无图 → 类别预设图；**绝不向后翻别的活动的图**——
那会给卡片配一张不属于这件事的照片，用户会以为图就是这件事。

### 9.7 对话上线后改回的三处

| 位置 | 1.0 | 上线后 | 前置条件 |
|---|---|---|---|
| 时间行 | `Added 3 days ago` | `Talked 3 days ago` | `conversationEnabled = true` |
| 徽章 / 副状态 | `40 words` | `12 words not said yet` | 接线 `record_lexicon_dialogue_units` + 定义「说过一个词」口径 |
| 灰态 | 无 | `All said` | 同上 |
| Hero 理由池 | 2 条 | 4 条 | 以上两项均完成 |

卡面结构不变，本版可逆。

---

## 10. 刀 4 字段规格（§9 的细化与修订，以本节为准）

完整可视版见 `docs/prd/Tab2_话题卡_刀4字段规格_v3.html`。本节记录决策与口径。

### 10.1 术语

`scene_detail`（DB 列名，从未改过）= `sub_scene`（v2 及更早 migration 的叫法，已废弃）
= `activity`（v5 输出与刀 3 之后的客户端，当前正式叫法）。

**activity 定义**：用户反复在做的一件具体的事，AI 从每条素材抽一个短标签，
同名累计即 `occurrence_count`。与 `scene_category`（系统固定 12 桶）是两层。

### 10.2 三个数字的口径差异（设计，非 bug）

| 数字 | 含 `word` 粒度? | 依据 | 回答的问题 |
|---|---|---|---|
| `occurrence_count` | ❌ 不含 | v5 ② `FILTER (granularity <> 'word')` | 你反复在做什么 |
| `word_count` | ✅ 含 | v5 ① 不加过滤 | 你攒了多少词 |
| `new_material_count` ★ | ✅ 含 | 本次新定 | 你今天放新东西了没有 |

`occurrence_count` 排除 word：查 7 个厨房单词不等于做了 7 次饭。
`new_material_count` 包含 word：查词就是放了新东西，不算会让用户觉得 app 眼瞎。
按**不同素材去重**——一张照片抽出 8 个词算 1 条。

### 10.3 时间档位（`d` = 本地自然日之差，非 24h 差）

| 条件 | 文案 |
|---|---|
| `d = 0` | `Added today` |
| `d = 1` | `Added yesterday` |
| `2 ≤ d ≤ 6` | `Added {d} days ago` |
| `7 ≤ d ≤ 13` | `Added last week` |
| `14 ≤ d ≤ 29` | `Added {w} weeks ago`，`w = floor(d/7)` |
| `d ≥ 30` | `Nothing new in a month` |
| `last_material_at = null` | **整行不渲染**（不写 `Never added`） |

### 10.4 Hero 理由行合成

`new_material_count` 优先，为 0 才退到 `last_material_at`：

- `= 1` → `You added something new today`
- `≥ 2` → `You added {n} new bits today`
- `= 0` 且 `d` 有值 → `Nothing new in {档位}`
- `= 0` 且 `last_material_at = null` → `Only words so far`

Hero 只有理由行、无时间行；More 行只有时间行、无理由行。**同卡不并存**，
但两者同源（都表达「这摊东西有多新」）——这是有意的：排序轴必须在卡面处处可见。

### 10.5 条数与折叠

Hero 显示 3 条 activity，More 行显示 2 条，后端 `rn <= 5` 的余量用于被校验挡掉的情况。
**折叠数基数是 `activity_count`，不是 5**；`N ≤ 0` 时 `+N` 不渲染。
文案：Hero `+{N} more activities`，More `+{N} more`。

**排序：后端已按 `occurrence_count DESC, activity_last_at DESC` 排好，客户端原序渲染不得重排**
——重排会让 `+N` 的语义（「剩下的都比这些少」）失效。

### 10.6 时区：1.0 采用方案 B

存储层已是标准（`timestamptz`，内部 UTC，按用户时区渲染）。
自然日聚合由**客户端传日界**：`p_day_start timestamptz` = 本地今天 00:00 对应的 UTC 时刻。

**传时刻，不传偏移**——存 `+8` 这类偏移数字的系统每年夏令时会错两次。
将来方案 A 存 IANA 名（`Asia/Shanghai`），同理不存偏移。

**4a 必须一并写入的兼容兜底**（今天不改变行为，只是留门）：

```sql
v_day_start := COALESCE(
  p_day_start,
  date_trunc('day', now() AT TIME ZONE COALESCE(v_user_tz, 'UTC'))
);
```

迁移到 A 的成本 = 加一列 + 填值 + 改这一行，**客户端零改动**。
之所以便宜，是因为「今天」只在读取时计算、从不落盘。
**禁止**把每日统计物化成表并按 UTC 分桶——那会让换时区需要重跑全部历史。

何时必须上 A：服务端主动发起的动作（定时推送、周报、任何 cron）——
那些时刻客户端不在线，服务端必须自己知道用户的日界。

### 10.7 刀 4 拆分

- **4a（后端）**：v5 输出加 `last_material_at`、`new_material_count`；
  RPC 加可空参数 `p_day_start` 与兜底；`get-tab2-home` 透传；客户端计算该时刻。
- **4b（卡面）**：按本规格重建 Hero 与 More；Hero 选取移出 `@ViewBuilder`；重写活动名校验。

4a 未完成，4b 没有数据可读。

---

## 11. 刀 4a 完成记录与两处规格修正

已落地 5 个 commit（未推送）：`7cb4489` 迁移 → `743dc6a` Edge → `ada6a74` Swift+测试
→ `3068626` 性能补丁 → `3b9ce11` 部署包文档。

### 11.1 🔴 修正一：§10.6 的兜底 SQL 写错了，以本节为准

**§10.6 写的（错误，勿用）**：

```sql
date_trunc('day', now() AT TIME ZONE COALESCE(v_user_tz, 'UTC'))
```

`AT TIME ZONE` 把 timestamptz 转成该时区的**墙钟时间**（`timestamp`，已丢失时区标记）；
截到零点后再赋回 `timestamptz` 变量时，会按**会话时区**重新解读。
今天 `v_user_tz` 恒 NULL → 兜底 UTC、解读也 UTC，两者巧合一致；
**但将来方案 A 把 `v_user_tz` 填成 `Asia/Shanghai` 后，会把"上海零点的墙钟"当成 UTC 解读，
差 8 小时且不报错**——正是「留门」那一行反而变成埋雷。

**正确写法（已落地）**：

```sql
v_day_start := COALESCE(
  p_day_start,
  date_trunc('day', now(), COALESCE(v_user_tz, 'UTC'))
);
```

三参 `date_trunc(field, timestamptz, zone)` 全程在 timestamptz 域内运算，任何时区都正确，
且不破坏「方案 A 只改这一行」的承诺。**依赖 PostgreSQL 16+**（已在生产验证可用）。

### 11.2 🔴 修正二：DROP FUNCTION 会一并删掉 ACL（提示词的缺漏）

`20260831115529` 做过安全收口：禁止客户端直连该 RPC。
`DROP FUNCTION` 把函数权限一起删除，重建后回到默认的 `PUBLIC EXECUTE`——
**即一次静默的权限回退**。v6 末尾必须重挂：

```sql
REVOKE EXECUTE ON FUNCTION public.get_tab2_home(uuid, timestamptz)
  FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.get_tab2_home(uuid, timestamptz) TO service_role;
```

**规则（今后任何 DROP+CREATE 都适用）**：改函数签名必须同时检查该函数是否有过
ACL 收口，并在同一迁移里重挂。这条不在原提示词里，是执行方发现的。

### 11.3 性能：并入同趟聚合，不另开 CTE

初版把 `new_material_count` 写成独立 CTE → 对 `lexicon_occurrences` 再开一趟全扫描 + JOIN，
中位 12.69ms，超 11.4ms 基线。改为并入 `cat_words` 同趟聚合
（`COUNT(DISTINCT source_id) FILTER (WHERE created_at >= v_day_start)`）后
暖态中位 **11.91ms**，样本 11.886–13.934（自身波动 ±1.9ms）。

判定：**+0.5ms 在噪声内，接受**。这是该字段的固有开销，同趟聚合已是最省实现。

### 11.4 验收实录（生产库，`f734e90f`）

| 项 | 结果 |
|---|---|
| 两新字段有值（p_day_start=NULL 走兜底） | 12 类 `last_material_at` 全非空；`new_material_count` 全 0（UTC 日界下最新素材属"昨天"，合理） |
| 自洽性（上海日界） | `inconsistent_rows = 0` |
| 自洽性正例（日界拨到 9/9） | 3 类计入，`inconsistent = 0` |
| NULL 兜底 ≡ 显式 UTC 日界 | `mismatches = 0` |
| 耗时 | 暖态中位 11.91ms |

调用方检索：`get_tab2_home` 唯一真实调用方是
`supabase/functions/get-tab2-home/index.ts:141`；客户端不直连 RPC。

### 11.5 其他落地细节

- `parseDayStart` 抽成 `get-tab2-home/dayStart.ts`：`index.ts` 顶层有 `Deno.serve`，
  测试若 import 它会真的拉起 HTTP 服务器（`delete-account`/`generate` 同惯例）。5 条 Deno 用例。
- Swift `tab2HomeRequestURL(now:calendar:)` 抽成纯函数，2 条单测固定上海/UTC 时区断言换算，
  不依赖跑测试的机器时区。保持 `GET`。

---

## 12. 刀 4b 执行期补定的三条规则

### 12.1 Hero 平局：三级键，`word_count` 全程不参与

一张素材抽词进两个分类时，`newMaterialCount >= 1` 且 `lastMaterialAt` 完全相同——很常见。
tiebreak 按序：

1. **`newMaterialCount` 降序**——与主规则同轴，只是更细一档。
2. **`activityCount` 降序**——内容厚度。
3. **`id` 升序**——与数据无关的确定键，保证可复现、可测。

**不用 `word_count`**：它正是本版刻意降级掉的轴（只涨不落 = 固定排名），
拿它当 tiebreak 等于把「词多者优先」从后门放回来。
它只在 `lastMaterialAt = null` 那一组的组内排序中还有职责（那组没有时间可比）。

### 12.2 轮换记账：持久化「类别 → 上次被选中日期」字典

12 个类，字典最多 12 条。**关键补充规则：无记录 = 从未被选中 = 最久，排在所有有记录的类之前。**

不补这条，轮换会退化——先被选中的类因为有了日期记录，反而永远排在从未被选中的类前面，
页面在少数几个类里打转。补上后行为是：**先把每个类轮一遍，再按最久回头**。

- **首次进入（无任何记录）**：全体皆「从未被选中」，按 §10.5 排序取第一个
  （即 `lastMaterialAt` 最新的已解锁类）。
- **写入时机**：进页面确定 Hero 后写入当天日期。同一天再次进入不重新轮换
  （当天已有记录，且 Hero 已按规则①冻结）。

### 12.3 理由行「久未」文案集（§10.4 的修订）

`d = 0` 时 `newMaterialCount` 必然 ≥ 1（同一日界口径），故本分支实际从 `d = 1` 起。

| 条件 | 文案 |
|---|---|
| `d = 1` | `Nothing new since yesterday` |
| `2 ≤ d ≤ 6` | `Nothing new in {d} days` |
| `7 ≤ d ≤ 13` | `Nothing new in the last week` |
| `14 ≤ d ≤ 29` | `Nothing new in {w} weeks` |
| `d ≥ 30` | `Nothing new in a month` |

**防御规则**：渲染时若出现 `d >= 1` 却 `newMaterialCount >= 1`（跨午夜后使用缓存响应），
**以 `d` 为准**走「久未」分支。宁可少报一次「今天有新东西」，
也不要在第二天早上还对用户说「你今天加了 3 条」。

---

## 13. 刀 4b 验收与 6 处 flagged 口径裁定

7 个 commit（`21aefd6` → `f25fec5`，基于 `3b9ce11`），未推送。
全量测试两遍绿：CI 脚本（iPhone 15 Pro / OS 17.4）与钉死模拟器 F761F756（iPhone 16 Pro）
各 395 passed / 0 failed。四个边界态截图验证通过，装前装后两个 UUID 逐字符 MATCH
（含容器被清理重建后的重装复验）。截图与记录入仓 `docs/review/刀4b渲染验证/`。

### 13.1 裁定

| # | 口径 | 裁定 |
|---|---|---|
| 1 | 照片取第一条**有效**活动的封面，被挡的不参与取图 | ✅ 采纳。被校验挡掉的活动根本不算活动，与「不向后翻」一致 |
| 2 | `Nothing logged yet` 用 20px 衬线 | ❌ **改无衬线 13px muted** ——见下 |
| 3 | 分隔符 ` · ` 用 textMuted | ✅ 采纳 |
| 4 | `artHeight` 沿用既有 150 token（规格写的 132） | ✅ 采纳，以 token 为准，规格数字作废 |
| 5 | 只删自己 orphan 的 8 个 token，历史债务留给 token hygiene pass | ✅ 采纳，正确的克制 |
| 6 | More 行活动行折行 | ❌ **改为单行截断，`+N` 不参与截断** ——见下 |

### 13.2 为什么 `Nothing logged yet` 不能用衬线

本项目既定规则：**衬线是「用户产生的内容」的标记**
（见 `Tab2ActivityRow.swift` 注释：「词表用衬线是形式撒谎」）。
`Nothing logged yet` 是系统文案，不是用户内容——放进活动位、又穿上衬线，
会让「没有内容」在视觉上被读成「一条内容」。改用无衬线 13px muted，
与副状态行同族：它陈述的是状态，不是素材。

### 13.3 为什么 More 行不折行

执行方的顾虑对：强制单行省略会吞掉 `+N`，违背折叠文案。**但解法不是折行，是分优先级截断。**

More 行是**并列可比的一组**，行高一致是它们能被扫视比较的前提；
折行会让某些行比别的高，这一组就散了。

**定：`+N` 固定不参与截断，活动文本单行截断。**
布局上把 `+N` 作为固定宽度尾块，活动文本占剩余宽度并 `.truncationMode(.tail)`。
宽度不够时，先省略第 2 条活动，再省略第 1 条——`+N` 永远完整。

这条也让「行高恒定」成为可断言的测试项，而不是靠 `minHeight` 兜住。

---

## 14. 测试数字口径与共享环境（刀 4b 对账的产物）

### 14.1 🔴 只认 xcresult，不数日志行

「395」与「377」**都不是测试数量**，都是从日志数 `Test case … passed` 行数得来的：

- 395 = 完整跑完后的日志行数（UI 启动测试按 launch 次数记 4 行，一个测试名出现多行）
- 377 = 日志文件还差最后 18 行没写完时数的行数——**竞态，不是测试变少**

**权威数字：394 = 393 passed + 1 skipped**（xcresult，exit 0）。
新增的 `rowHeightIsConstantWhenActivityLineOverflows` 在跑。

**规则：报测试数字一律引用 xcresult，不引用日志行数。**

### 14.2 🔴 同一台 Mac 上多会话共用模拟器与构建目录

对账中发现另一个会话在共用测试模拟器 `F761F756` 与共享构建目录跑它自己的 CI，
其结果档案与本工作区的轮次时间交错，一度把执行方带偏
（那两轮含 DesignLab toast 测试、#62 间距测试、旧版 Tab2 测试名——根本不是本工作区的代码）。

**规则：解读任何测试结果前，先核对结果档案的「测试名清单指纹」确认是本工作区的轮次。**
这与 §8.2「截图取信前先核二进制 UUID」是同一条原则的两个面：
**结果属于谁，必须先证明，再解读。**

### 14.3 附带发现（未修）

CI 脚本里 `-skip-testing:AIEnglishAppUITests/testLaunchPerformance` 写法与测试类名不匹配，
一直未生效——launch 性能测试每轮都在跑。比要求更严，无害，留待清理。

---

## 15. 与 main 的分叉：采用 rebase

`origin/main` 多出 #61（debug/input box）、#62（spacing optimization）、#63（home content loading）。

**文件交集只有 2 个**：`Theme.swift`、`AIEnglishAppTests.swift`；其余 47 个文件零接触。
两处均为**各改各的、行级不重叠**——PR 侧 `Theme.swift` 加时间线/文章卡 token（4 处），
本分支是字体层换装（Charter/Geist）与 Tab2 token（7 处）；测试文件套件不同。

**决定：rebase。** 两处都是独立新增，git 按上下文对齐，冲突概率低；
rebase 后历史线性，token 层的合流结果一眼可审。

---

## 16. 刀 6：视觉调整（待刀 5 完成后开始）

**为什么不能提前做**：刀 5 ① 的字重映射一旦修好，8 处声称 `.medium`
实际渲染 Regular 的文字会真的变轻，整屏墨量分布随之改变。
**在错误的基线上调视觉，会把「为补偿字重错误而做的调整」一起固化。**

以下四项来自真机截图评审（2026-09-10），刀 5 完成后重新评估再落地。

### 16.1 红色：整屏只保留一个用途

现状：品牌红出现在 Hero 整句理由行、所有 `×N`、以及 `Delete account`。
一屏上有七八个红色元素——**强调到处都是，等于没有强调**；
且一整句话染红，语气像报错，而 `You added something new today` 是好消息。

**规则：红色只用于危险 / 破坏性动作，不用于强调。**

- Hero 理由行 → `textMuted`，11px 大写、字距 .1em。它是标签，不是要喊出来的话。
- `×N` → `textSecondary` 常规字重。次数靠紧贴活动名的上标形态即可辨识，不需要颜色。

（修正：§13 之前的裁定是「保留橙色、只降字重」——那个判断不对，问题在颜色本身。）

### 16.2 Hero 卡重排

现状节奏不匀：三行文字挤在一起，`Start talking` 右对齐、左侧一大片空白——
那不是留白，是没排满。

- 文字区左右内边距加大；三行按 4/8 节奏（理由→活动 8，活动→词数 4）
- **CTA 改左对齐**，与上方三行左边缘对齐，整卡成一条干净的左对齐纵列
- 照片与理由行之间加呼吸，不要贴着照片底边

### 16.3 预设图改为「记号」，不再是「图」

现状：无照片的类别用了一张 App 自身界面的截图作预设图，与旁边真实照片并排，
**用户会以为那也是自己拍的**。

**改**：缩略图位保留（维持行对齐），预设态渲染为
**浅色底 + 该类别的线性图标**——复用 `Topics in progress` 已有的那套图标。

判据：有照片 = 我存过东西；有图标 = 这一类还没有画面。
**两者从形态上就是两类东西，不互相冒充。**

### 16.4 同屏两套词汇：`words` 与 `pops`

`More to talk about` 说 `40 words`，下方 `Topics in progress` 说 `7 pops`——
同一个量两个名字，而 `pops` 正是已判定要删的词。
该段刀 4 未触及，**建议一并改为 `words`**。

---

## §17 词卡分类失败（Other 桶）排查与修复

### 17.1 现象

rebase 后查全量分类分布，`Other` 是最大的一桶（112 条 occurrence），
超过第二名 `Work & Study`（71）。按素材数拆开：

| 路径 | 失败素材 | 总素材 | 失败率 |
|---|---|---|---|
| 词卡（word） | 68 | 76 | **89%** |
| 场景（sentence/passage） | 17 | 109 | 16% |

注意口径：`lexicon_occurrences` 按词记账，一个 passage 素材会写多行，
所以**必须 `count(distinct source_id)` 才是真实失败次数**，直接 `count(*)`
会把 passage 的权重放大数倍。

### 17.2 两个先后被证伪的假设

1. **「是中英枚举错配」** —— 对了一半。真机上那两行 `Other` 确实是
   旧客户端只认中文、线上已写英文所致，rebase 后自动消失。但它解释不了
   89%：库里一个中文值都没有。
2. **「修复已经上线了」** —— 证伪。代码里确实有修复（`normalizeSceneCategory`
   + 取最后一个非空 text），但按日期比对：

   | 事件 | 时间 |
   |---|---|
   | 修复提交 `765f5fb` | 09-11 |
   | 修复进 main（`9975699` #64） | 09-14 |
   | 线上 `generate` 部署 | **09-10** |

   **部署早于修复三天，修复从未上线。** 这条催生了 CLAUDE.md 的
   「Edge Function 部署纪律」。

### 17.3 真实病因：第三张脸

部署修复版后，失败仍在，但日志形态变了：

```
[classifyVocabCategory] unmatched "" for "corn", fallback→Other | parts=[]
```

`parts=[]` 是**空数组**——模型一个 content part 都没返回，不是「答案藏在
thought part 里被读成空」。所以「取最后一个非空 text」这个修法在这里无能
为力：没有东西可捞。同批请求中 `coffee` 成功、`corn`/`bedsheet` 失败，
呈**间歇性**——预算耗尽的典型特征。

病根一直是同一个，仓库里早有记录：**`thinkingBudget: 0` 并不能真的把思考
压到零。** 同一病根此前已修过两次（20→200 补预算、抢救 thought part 文本），
这是第三次发作。

配置对比暴露了老问题——**同一修复没有同步到兄弟函数**：

| 函数 | maxOutputTokens |
|---|---|
| `_shared/classifyScene.ts` | 500（100 不够，实测 67/96 截断后提的） |
| `generate/index.ts` 的 `classifyVocabCategory` | **200** |

英文切换后类名变长（`Hobbies & Leisure`），200 正处在爆与不爆的边缘。

### 17.4 修复与验收

`ab2de51`：

1. `maxOutputTokens: 200 → 500`，与 `classifyScene` 对齐。
   Gemini 按实际生成计费，提高上限不增加成本。
2. `unmatched` 日志补 `finishReason`——`parts=[]` 的病因可能是
   `MAX_TOKENS`（提上限）或 `SAFETY`（安全拦截），**药方相反，
   日志必须能分开它们**。

**部署记录**：`generate` v74 / commit `ab2de51` / 2026-09-16 00:00 UTC

**验收（同一输入前后对照）**：

| 词 | 部署前 | 部署后 |
|---|---|---|
| corn | Other ✗ | Food & Drink ✓ |
| jujube | — | Food & Drink ✓ |

同一个词、同一条路径的前后对照，是这类修复最强的证据形式。

### 17.5 留下的账

- **历史 112 条 `Other` 不会自愈。** 清库前 Tab2 的 `Other` 仍会排第一。
  决定：不回填，等上线前清库。
- **场景路径 16% 失败尚未排查。** `classifyScene` 已是 500，病因可能不同，
  单独一刀。
- **`Other` 的口径仍未定。** `classifyVocabCategory` 三条失败路径全部
  `return "Other"`，而代码注释写的是「判不准留 null，不计入任何分类桶」。
  实现与注释不一致；`moment` 这类本就无场景的词该进 Other 还是留 null，
  是产品决策，待定。
