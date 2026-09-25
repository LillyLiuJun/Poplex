# Tab2 话题卡 1.0 · Claude Code 执行指令

> 每一刀是**一个独立的 Claude Code 会话**。不要把两刀塞进同一个会话，
> 也不要在一刀没验收通过时开始下一刀。
>
> 每段「指令」可直接整段粘贴。

---

## 通用规则（每次开新会话前先说这句）

```
这个仓库的 docs/prd/ 下有三份本次改造的文档，动手前先读：
- Tab2_话题卡_字段变更_实现规格_v2.html   ← SQL 规格，可直接抄
- Tab2_话题卡_1.0上线方案与切片_v1.md     ← 范围与切片
- Tab2_话题卡_字段变更_v1.md              ← 字段变更背景

规则：
1. 只做我这次指定的这一刀，不要顺手做下一刀的事。
2. 不要"顺便优化"我没要求的代码。
3. 改完先给我 diff，我确认后再继续。
4. 遇到文档没写清楚的地方，停下来问我，不要自己拍板。
```

---

## 刀 0 · 数据摸底（不改代码）

```
读 docs/prd/Tab2_话题卡_1.0上线方案与切片_v1.md 的「刀 0」一节，
里面有三条 SQL。帮我确认这三条 SQL 在当前 schema 下语法正确、
字段名都存在（对照 supabase/migrations/ 里的建表脚本核实）。

注意：查询 ① 和 ③ 里的 AND source_type = 'material' 是刻意加的，不要当成
冗余删掉——source_id 是多态外键，对话记账接线后对话来源的行也会带
scene_category，不过滤会让这条基线在两次运行之间悄悄改变口径。

不要执行，我会自己去 Supabase 控制台跑。
如果发现字段名有误或有更准确的写法，直接改好给我。
```

跑完后把三个数字填回该文档的 §6。

---

## 刀 1 · 标签一致性（唯一的硬前置）

> ⚠️ 这一刀不只是改 prompt 字符串，还要加一次数据查询。

```
目标：让 classifyScene 生成的 scene_detail 在跨次调用间保持一致，
不再每次无记忆地重新起名。这是 supabase/functions/generate/index.ts
里 classifyScene 上方那条 TODO（"写入前与该用户该分类下的已有
scene_detail 比较归并"）的 prompt 层解法。

文件：supabase/functions/generate/index.ts

要做三件事：

【1】新增一个查询函数，取该用户已有的活动标签

在 classifyScene 附近加一个函数，用 PostgREST 查
lexicon_occurrences，取该用户所有非空的 (scene_category, scene_detail)
组合，在 TypeScript 里去重，返回形如：
  "饮食: Cooking, Eating out | 工作与学业: Working, Studying"
的紧凑字符串。

要求：
- 用现有的 SUPABASE_URL / SUPABASE_SVC_KEY 走 fetch，和文件里其他
  PostgREST 调用保持同一写法
- 加 limit（比如 500）防止行数失控
- 查询失败时返回空字符串，绝不能因为它失败而让整个生成流程失败
- 不要新建 migration，不要加 RPC

【2】把它接到调用点

classifyScene 目前在 index.ts:872 附近被调用，那个作用域里有
userId。在调用 classifyScene 之前先查好标签，作为第四个参数
existingLabels 传进去。

【3】改 prompt

classifyScene 里的 prompt 改成下面这样（保持模板字符串写法，
category 列表和 safetySettings 不动，maxOutputTokens 保持 100，
不要新增任何 JSON 字段）：

  sub_scene 的说明部分替换为：

  sub_scene — the recurring activity this scene belongs to. It is a
  GROUPING KEY: many separate occasions must share it, and the SAME
  wording must come back next time the user does this again.
  · If one of the user's existing activities listed above fits, reuse it
    VERBATIM. Invent a new one only when none fits.
  · Strip qualifiers and specifics: "Cooking", not "Cooking dinner
    tonight"; "Fixing a device", not "Helping mum set up her new phone".
  · It must say more than the category already does. Under 饮食,
    "Eating" is useless; "Cooking" / "Eating out" / "Grocery shopping"
    are useful.
  · Target language only (English). Never echo the native language, even
    when Scene or Context is written in it. Max 24 characters.
  · Aim for: Cooking / Eating out / Commuting / Driving / Running /
    Watching a show / Working / Studying / Shopping / Chores / Catching up

  同时把 Context 那一行改成明确的权威声明：
    What the user actually wrote: "${userOriginal}"
    ← the user's own intent; trust this over Scene when they differ

  并在 Scene / Context 之后插入（existingLabels 非空时才渲染）：
    Activities this user already has:
    ${existingLabels}

不要动的：
- validateSubScene 的校验规则（24 字符 / 英文）
- classifyVocabCategory
- 任何其他函数

改完给我完整 diff。
```

**验收**（上线后跑，对照刀 0 的基线）：

`frag_ratio = distinct scene_detail / 素材数`

| 结果 | 判定 |
|---|---|
| ≈ 1.0 | 不合格，**后面三刀不许开始** |
| 0.35 – 0.6 | 勉强，回来再调 prompt |
| ≤ 0.35 | 放行 |

---

## 刀 2 · RPC + Edge Function

> 前置：刀 1 ✅ 通过（85→24 标签）；刀 1.5 ✅ 通过；
> `last_talked_at` 取数路径已拍板：**方案 B**。

**方案 B 的具体内容（拍板于 2026-09-09）**：
在 `dialogue_sessions` 上新增 `last_turn_at timestamptz`，
由 `dialogue/index.ts` 的 `handleTurn` 在写入 `role='user'` 的轮次时顺手更新。
RPC 侧对 `dialogue_sessions` 做 `MAX(last_turn_at)` 分组，
走现成的 `idx_dialogue_sessions_user_created`。

不走「直接扫 `dialogue_turns`」：那是全系统写入量最大的表，
唯一可用索引 `idx_dialogue_turns_user` 是单列 `(user_id)`，
建表注释写明用途是「数据审计 / 隐私删除用」——罕用管理路径的索引，
不能拿来撑每次进 Tab2 都跑的首页 RPC。

口径：**最后一次对话 = 最后一次用户开口**（`role = 'user'`）。
**不要用 `ended_at`**——该列全仓无任何写入方，按它过滤会恒为 null。
存量测试数据不回填，`last_turn_at` 从 null 起步（表现为 Never talked，可接受）。

```
按 docs/prd/Tab2_话题卡_字段变更_实现规格_v2.html 的 §2 和 §3 改造。

【A】新建 migration 改 get_tab2_home
基线是 supabase/migrations/20260831061214_get_tab2_home_hero_v4.sql，
用 CREATE OR REPLACE 写一个新的 migration 文件，不要改旧文件。

规格文档 §2 里的 SQL 可以直接抄。以下六条是必须逐条确认的陷阱，
写完请逐条自查并告诉我结果：

1. not_spoken_count 必须写成
   COUNT(DISTINCT lo.entry_id) FILTER (WHERE le.spoken_count = 0)
   写成 COUNT(*) FILTER 会虚高（数的是 occurrence 行数不是词条数）。
   本项目已中过一次这个坑，见 scene_counts CTE 的注释。

2. 基线第 276 行的最终 ORDER BY 是
   ORDER BY cw.word_count DESC, cw.last_material_at DESC
   删掉 last_material_at 输出后这行会失效。改成在 cat_words 里保留
   MAX(lo.created_at) AS sort_last_at 作纯排序键（不输出到 JSON），
   ORDER BY 改用它。

3. cover 的 LATERAL 子查询必须带 m.deleted_at IS NULL。
   软删除素材的 lexicon 流水是被有意保留的
   （见 20260820000000_lexicon_orphan_cleanup.sql 的注释），
   不加过滤会把已删除素材的图选成封面。

4. cover LATERAL 必须在排名截断之后执行：
   先 ROW_NUMBER() 排名 → WHERE rn <= 5 → 再对这 5 条跑 LATERAL。
   谓词 (user_id, scene_category, scene_detail) 上没有索引，
   不截断的话每个活动都要扫该用户全部 occurrence 行。

5. activity_count 由 moment_counts 全量计算，
   不受 activities 的 rn <= 5 截断影响。

6. scene_counts 里计算 occurrence_count 的那一段要加
   AND lo.source_type = 'material'。
   source_id 是多态外键（material | dialogue），建表注释写明对话来源的行
   也会带 scene_category。不加过滤的话，对话记账接线后「Cooking ×7」
   会把"聊过做饭"也算进去，静默改变卡面对用户的承诺。
   写法参考 20260728030000_lexicon_backfill_reconcile_rpcs.sql:32。

   反过来，cat_words 里的 word_count 和 not_spoken_count
   【不要】加这个过滤——那两个语义是"词条数"不是"素材条数"，
   一个词只在对话里说过也照样属于该类别的词库。

删除项：featured CTE、hero_photos CTE、它们的两个 LEFT JOIN、
preview_words 子查询、last_material_at 的 JSON 输出。

【B】改 Edge Function
supabase/functions/get-tab2-home/index.ts 的 signImagePaths：

- 收集侧：从 sub_scenes[].image_url / featured.image_url /
  hero_photos[].image_url 三处，改为 activities[].cover.image_url
  一处，注意多了一层嵌套。
- 回写侧：必须写成 cover: {...cover, image_url: signed}，
  不能把 cover 整体替换成 URL，否则 material_id 丢失，
  客户端的图片缓存 key 和去重会失效。
- 签名失败时只把 image_url 置 null，不要像现在的 hero_photos 那样
  把整条丢掉——activity 的 scene_detail 和 occurrence_count
  没有图也要展示。

A 和 B 必须一起改。漏改 B 的后果是裸 Storage 路径原样透传给客户端，
静默失败，不报错。

改完先给我两个文件的 diff，我确认后再说要不要 apply migration。
```

**验收清单**：

- [ ] `not_spoken_count ≤ word_count` 对全部类别恒成立
- [ ] `activities[].cover.image_url` 是签名 URL，不是裸路径
- [ ] 没有 cover 指向 `deleted_at IS NOT NULL` 的 material
- [ ] `activities` 每类别 ≤ 5 条，`activity_count` 仍是全量
- [ ] `EXPLAIN ANALYZE` 总耗时不高于基线

---

## 刀 3 · 客户端模型与命名（不动 UI）

```
按新的 RPC 返回结构改客户端数据模型。这一刀不改任何 UI 和布局，
目标是"数据能解码、App 不崩"。

文件：AIEnglishApp/Models/Tab2HomeData.swift 为主

【1】删除 struct Tab2FeaturedMoment、struct Tab2HeroPhoto

【2】Tab2SubScene 改造为 Tab2Activity：
- 保留 sceneDetail、occurrenceCount
- 删除 quote、targetExpression、imageUrl、isPhotoMoment
- 新增嵌套 struct Cover { materialId: String, imageUrl: String }
  和 let cover: Cover?
- Cover 保留 stableImageKey 计算属性（剥掉签名参数取路径部分）

【3】Tab2CategoryData：
- 新增 notSpokenCount: Int（JSON key: not_spoken_count）
- 新增 lastTalkedAt: Date?（JSON key: last_talked_at）
  ← 复用文件里现有的双格式 ISO8601 解析逻辑，就是 lastMaterialAt
     那段（带 withFractionalSeconds 的 fallback），照抄
- 删除 lastMaterialAt、previewWords、featured、heroPhotos
- momentCount 改名 activityCount（JSON key: activity_count）
- subScenes 改名 activities，类型 [Tab2Activity]
- struct Tab2PreviewWord 整个删除

【4】全仓改名 moment → activity：
- Tab2MomentRow.swift → Tab2ActivityRow.swift，struct 同步改名
- 所有 momentCount / moreCount 相关引用

【5】Tab2HomeViewModel 里对 featured 的判空
（ranked / heroCategory / moreCategories，约 157-230 行）
改为对 activities 判空。

【6】把 Tab2HeroCard / Tab2ActivityRow 里所有引用已删字段的地方
改到能编译通过即可，UI 长什么样这一刀不管——下一刀重做。

改完确保 xcodebuild 能过，然后给我 diff。
```

**验收**：真机能拉到数据、能解码、卡片即使样式还是旧的也不崩。

---

## 刀 4 · 卡片内容重做

```
重做 Tab2 解锁态的两种卡片。设计规格见
docs/prd/Tab2_话题卡_字段变更_v1.md，视觉参考本仓库
docs/design-system/ 下已有的画板风格。

文件：Tab2HeroCard.swift、Tab2ActivityRow.swift、MineView.swift

【Hero 卡】自上而下：
1. 顶部图（规则见下）+ 类别名 overlay
2. 理由行（Geist 12 semibold, brandInk）——1.0 只有两条规则：
   lastTalkedAt == nil  → "Never talked about"
   否则                 → "\(notSpokenCount) words waiting"
3. 活动行（Charter 20 bold）：前 3 个活动名，· 分隔，末尾 +N
   N = activityCount - 已展示数，N == 0 时不渲染 "+N"
4. 状态行（Geist 13, textMuted）："\(notSpokenCount) words not said yet"
   notSpokenCount == 0 时改为 "All caught up"
5. CTA "Start talking →"（保持现有样式，不加时长）

【推荐行】
1. 类别名（Geist 15 semibold）+ 右上欠账徽章
   徽章：notSpokenCount >= 1 → "\(n) not said"（brandInk）
        notSpokenCount == 0 → "All said"（textMuted，整行 opacity 0.62）
2. 活动行（Charter 14.5, textSecondary）：前 2 个活动名 + "+N"
3. 状态行（Geist 12, neutralFaint）：
   "Never talked" / "Talked N days ago"

【×N 的规则 —— 重要】
occurrence_count >= 2 时才在活动名后渲染 "×N"；
== 1 时只显示活动名，不显示任何数字或占位符。
×N 用 Geist 小一号 + brandInk，与活动名的 Charter 拉开层次，
不要让"没有数字"读起来像"数据缺失"。

【图片取用规则 —— 重要】
主图 = 被点名的前 3 个活动中，第一个 cover != nil 的那个的 cover。
前 3 个都没有 cover → 走 CategoryPresetArtView 预设图。
禁止向后查找第 4 个及之后的活动取图——那会让图和文字说两件事。

【顺带改】
MineView 里 "More to talk about" 和 "Topics in progress" 两个分区标题，
从 AppTheme.Font.sectionTitleSerif 改为 Geist 13 semibold 全大写
+ 字距 0.1em + textMuted。"Talk about today" 保持衬线，作为页面级标题。
（现在三个标题同为 22pt Charter-Bold，层级是塌的。）

【Hero 选取】
Tab2HomeViewModel 的 heroCategory 排除 scene_category == "其他"。
那是 classifyScene 的兜底桶，会长期欠账最多而反复霸占 hero。

必须处理的边界态，逐个给我截图确认：
- 全部活动 occurrence_count == 1（卡面只有裸标签，排版不塌）
- 前 3 个活动全无图（预设图，不能像加载失败）
- notSpokenCount == 0（All caught up）
- activityCount <= 3（不渲染 +N）
```

---

## 刀 5 · 收尾（可延后）

```
两件独立的事，分别开会话做：

【1】dialogue_sessions.ended_at
该列有 CHECK 约束和"NULL = 进行中"的注释，但全仓没有任何写入方。
帮我确认这一点（grep 全仓），确认后开一个 issue 描述现状，
不要现在动代码。

【2】Theme.swift 的字重映射
AppTheme.Font 里 charter() / geist() / hiragino() 三个工厂函数用的是
二值映射：isBold = (weight == .bold || .semibold || .heavy)。
后果是 .medium 静默退成 Regular，.bold/.heavy 在 Geist 上退成 SemiBold。
Charter 系统字体本身只有 Roman/Bold，没有 semibold。
先给我一份影响面报告（哪些 token 的实际渲染字重与声明不符），
不要直接改——这是全局改动，要单独评估。
```

---

## 执行顺序速查

```
刀0 摸底 ──┐
           ├─→ 刀1 prompt ──[frag_ratio ≤ 0.35]──→ 刀2 RPC+Edge ──→ 刀3 模型 ──→ 刀4 卡片
拍板 A/B/C ┘

刀5 任意时候，独立。
```

**刀 1 不需要等任何拍板，可以立刻开始。**
