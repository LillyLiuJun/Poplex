# Tab2 · More to talk about 列表 · 设计方案 v1

> **范围**：Tab2 已解锁态里 hero 卡下方的备选列表。
> **前置**：hero 卡已落地（`eb0498f`）。本文复用它定下的术语、模式判据、同源规则与选取尺子，不重复论证。
> **不动**：`Topics in progress` 整段（标题、`CategoryProgressRow`、手风琴、进度条）一行不改。
> **冲突时以代码为准。**
> 硬约束遵守 `CLAUDE.md`：iOS 17+ / `@Observable` / 颜色字号走 `AppTheme` token / 产品 UI 文案为目标语言。

---

## 一、现状

hero 重构时把原来的 `otherUnlocked` 横滑区整个删掉了。现在 `MineView.contentSections` 只剩两块：

```
Talk about today
  [hero 卡]          ← Tab2HeroCard，已定稿

Topics in progress
  [CategoryProgressRow …]   ← 未解锁分类
```

**已解锁但没被选成 hero 的分类，当前在首页完全不出现。** 本文补上这一块。

---

## 二、定位：它和 hero 是什么关系

### 2.1 同质的是内容，不同的是推荐强度

hero 和 More 的每一行装的是**同一类东西**——一个分类的代表 moment（`featured`）。同一个候选池、同一把尺子、同一套模式判据。

区别只在**系统对它的推荐强度**：

- **hero**：我很有把握，这件事你现在说得出来 → 大卡 + 实心 CTA
- **行**：这些也说得出来，只是我没那么有把握 → 小行 + 箭头

### 2.2 推荐强度到底在断言什么

不是"你最想聊"（那是偏好预测，我们没有任何偏好信号——点击频次明确不做）。
不是"你最该练"（那是学习价值判断，我们没有难度、掌握度、遗忘曲线）。

排序规则实际在测的是：

| 信号 | 在测什么 |
|---|---|
| `featured.createdAt` 一周内 | 记忆还热，细节还在手边 |
| moment 数最多 | 这个话题有储备，聊得下去 |

两条指向同一件事：**此刻你对这件事的可说度最高**——你现在开口最不费力。

这个断言诚实，因为两个信号都是它的直接证据，不需要揣测用户心理。

> 2026-09-01 起删除「还没聊过」信号：对话功能未上线，「已聊过」机制经产品拍板整体删除（见 §5.4），所有行一律按未聊过呈现。

### 2.3 三条由此推出的规则

**① 二元呈现是对的，尽管信号连续。** 连续置信度对用户没有可操作性。他只需要知道"系统建议这个"和"还有这些"。

**② hero 不需要最准，需要最稳。** 用户要的是一个决定，不是排名。边界情况下选谁是任意的，但"选了"本身有价值——它把决策成本从用户身上拿走。这就是 hero 存住不换的理由：**稳定 > 精准**。

**③ 这把尺子不能挪作他用。** 大卡不用来表达"词最多"（那是成就，所以 pops 不参与排序）、不用来表达"最新"（新≠可说，所以时效是分档不是主键）。

### 2.4 为什么每行是「一个分类的代表 moment」而不是别的

**不是「一行一个分类」**：hero 给的是一件具体的事，行若是抽象话题，用户点进去系统还得再选一次，两者语义不平行。

**不是「跨分类打平所有 moment」**：那是 Library 的活。Tab2 首页要给的是**少数几个备选**，不是全量清单。而且打平就必须用 `sub_scenes` 里的 `quote` / `target_expression` / `image_url`——**那三个是各自独立的子查询，可能来自三条不同的 material**，图文会错配，正是 hero 卡上刚修掉的 bug。

**每分类取一个**同时拿到三个好处：多样性有保证、行数可控（= 已解锁分类数 − 1）、直接复用天然同源的 `featured`。

---

## 三、结构

```
Talk about today
  ┌──── hero 大卡 ────┐
  └───────────────────┘

More to talk about              ← 保留标题
  [行] [行] [行] …

Topics in progress              ← 本轮不动
  [进度行] …
```

**三块的边界**：

| 边界 | 性质 |
|---|---|
| hero ↔ More | 推荐强度（软），靠视觉层级表达 |
| More ↔ Topics in progress | **能聊 / 还不能聊**（硬，解锁与否） |

---

## 四、选取逻辑

候选 = 全部已解锁分类，**排除 hero 已占用的那个**。分两组，组间有序，组内各自排序。
「聊过」维度已整体删除（见 §5.4），行状态由行组件按 featured 有无自行判定。

```
组 1 · 有可说的事
    featured != nil
    排序：复用 Tab2HomeViewModel.ranked()
          ① featured.createdAt 一周内的排前
          ② moment 数降序（subScenes.count）
          ③ featured.createdAt 最新
          ④ id 升序（稳定兜底）

组 2 · 没有可说的事（纯查词）
    featured == nil
    排序：wordCount 降序
    视觉：弱化 + 词表行样式（见 §5.5）
```

**组 2 排最后的理由**：用同一把尺子量——组 1 有具体 moment 可说，组 2 "根本没有一件事可聊"。后者更低。

**不设行数上限。** 最多 11 行，且随解锁逐个长出来，早期只有 2–3 行。设上限反而要多一个"查看全部"入口。

**`ranked()` 直接复用，不新写。** 它已经在 `Tab2HomeViewModel` 里，签名是 `ranked(_:momentCount:)`，本文只是换一批输入。

---

## 五、行的规格

### 5.1 版式：卡片行

每行是一张独立白卡，左侧缩略图满高。

| 项 | 值 |
|---|---|
| 卡片宽 | 350（与 hero 同轴，左右各留 `Space.paddingPage`） |
| **行高** | **固定 100** |
| 圆角 | 16 |
| 阴影 | `radius 6 · y 2`，比 hero 轻一档 |
| 底色 | `Color.warmGlassSurface` |
| 行间距 | 11 |
| 交互 | **整行可点** → 直接进对话页。无按钮 |

**为什么行没有 CTA**：这就是推荐强度的表达。hero 说"就这个，点这里"给实心按钮；行说"也可以"只给箭头。如果每行都配按钮，页面上就有 N 个同等强度的号召，「系统替你选了一件事」的价值立刻消失。

### 5.2 内容布局

```
┌────────┬──────────────────────────────────┬───┐
│        │ WORK & STUDY            41 pops  │   │
│  缩略图 │ I totally blanked when they      │ → │
│  84×100│ asked me for the timeline.       │   │
│        │ Meetings · +5 more moments       │   │
└────────┴──────────────────────────────────┴───┘
```

| 元素 | 取值 | 规格 |
|---|---|---|
| 分类标签 | `scene_category` → 英文映射 | 9.5 / 800 / 字距 1.2 / 全大写 / `textMuted`，单行截断 |
| pops | `word_count` | 9.5 / 600 / `neutralFaint`，右对齐，与分类标签同基线，`layoutPriority(1)` |
| 主句 | `featured` 主句，模式判据**完全复用** `Tab2HeroCard.featuredMode` | 衬线 15 / 600 / 行高 1.32 / `textPrimary`，**固定两行高度**，超出尾部省略号 |
| meta | `scene_detail · +N more moments` | 10.5 / 600 / `textMuted`；分隔点与 `+N` 用 `neutralFaint`，单行 |

**间距**：顶内边距 12 → 分类行 → 4 → 主句（2 行 40）→ 3 → meta → 底内边距 12。

**主句为什么固定两行而不是最多两行**：真实数据里长句占多数——你们截图里那五条主句是 63 / 42 / 45 / 41 / 69 字符，行内正文宽约 214、衬线 15 一行约 28 字符，**五条全部需要两行**。既然绝大多数都是两行，固定两行等于白拿一个统一行高，短句留白的代价极小。

> ⚠️ **上线前用真实数据复核一次**。若"一行以内（≤28 字符）"的占比超过 15%，或"两行仍截断（>56 字符）"超过三成，回来重新评估——后者要先改的是缩略图宽度而不是行数。
>
> ```sql
> SELECT CASE WHEN len <= 28 THEN '1 行' WHEN len <= 56 THEN '2 行' ELSE '截断' END AS lines,
>        COUNT(*), ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (), 1) AS pct
> FROM (SELECT length(COALESCE(raw_content->>'target_expression',
>                              raw_content->>'user_original')) AS len
>       FROM materials WHERE material_type='scene' AND deleted_at IS NULL) t
> GROUP BY 1 ORDER BY 1;
> ```

**meta 行抢位**：`scene_detail` 自适应剩余宽 + 尾部截断；`· +N more moments` 用 `layoutPriority(1)` 永远完整。规则与 hero 一致。

**不放**：母语行、`created_at`、引号、CTA 按钮。
引号是 hero 的特权（"这是你真的说过的目标语言"），行上放会和主句抢重量。母语在 hero 上是兜底（看不懂时瞄一眼），但行上主句已经是截断的摘要，再叠一个截断的母语摘要，两个残句一起读更费劲；且中文笔画密，12px 中文压在 15px 英文下会把重心拽下去。

### 5.3 缩略图

| 情况 | 用什么 |
|---|---|
| `featured.imageUrl != nil` | 那一张照片，填满 84 × 100 |
| `featured.imageUrl == nil` | **行内预设图**（见 §5.6） |

**同源规则与 hero 完全一致：要么是 `featured` 那条素材自己的照片，要么不用照片。** 绝不退回"这个分类里最近的一张"。

**照片处理——比 hero 更暗**：

| 层 | hero | 行内 |
|---|---|---|
| 饱和度 | `.70` | **`.65`** |
| 暖橙 multiply | `.20` | **`.24`** |
| 暖纸 soft-light | `.45` | **不加** |

暖纸 soft-light 那层在 hero 上的作用是提亮暗部、让 150pt 的大图不至于闷。行内只有 84 宽、且要退到主句后面，**提亮反而喧宾夺主**——去掉它，同时把 multiply 加重一档，整体压暗。

### 5.4 聊过的行（组 2）——已废弃

> **2026-09-01 产品拍板删除。** 对话功能未上线，判定「已聊过」所依赖的
> `Tab2Defaults.spokenMoments` 写入路径从未接通（对话页返回只给分类、不给
> scene_detail），机制本身是死代码。删除后 More 列表 = 所有已解锁分类（排除
> hero），**所有行一律按未聊过呈现**，不再区分。相关 token
> （`tab2MoreRowSpokenCheck` / `tab2MoreRowSentenceSpoken` / `spokenThumbnail*`）
> 与 `markMomentSpoken` 已随代码移除；后端词条级 `spoken_count` 数据契约保留
> （它是词汇账本的证据，与 UI 无关）。

### 5.5 纯查词的行（组 2）

这类分类已解锁、有 pops，但**一件可聊的事都没有**。

```
┌────────┬──────────────────────────────────┬───┐
│ 预设图  │ TECH & GADGETS          24 pops  │   │
│（更淡） │ back up 备份 · glitch 小故障      │ → │
│        │ No moment yet                    │   │
└────────┴──────────────────────────────────┴───┘
```

| 位 | 内容 | 规格 |
|---|---|---|
| 主句位 | `preview_words` **前 2 个**，`词 + 释义`，中点分隔 | **无衬线** 14 / 600 / `textSecondary`；释义 11 / 400 / `textMuted`，紧跟词后左距 4 |
| meta 位 | `No moment yet` | 同 meta 规格，用 `neutralFaint` |
| 整行 | 透明度 `.82` | 见下 |
| 缩略图 | 行内预设图的**更淡变体**（见 §5.6） | |

**为什么主句位用无衬线**：衬线在这套设计里是"内容"的标记。三个词用衬线放在主句位，**形式在撒谎**——它冒充了一个句子，但它不是句子，读起来就别扭。换成无衬线，再加上中文释义，形式本身就说清了"这是词表"。

**为什么是 2 个词不是 3 个**：加释义后一行只放得下两个。行内正文宽约 214，`back up 备份 · glitch 小故障` 已经贴边。这行的作用不是列词表（那是 Library 的活），是让用户知道"这里有料但还没成形"，两个词够了。

**为什么整行降一档**：不降的话，"点进去能聊一件事"和"点进去只有一堆词"两种行长得几乎一样，而点下去的体验差别很大。`No moment yet` 四个字作为唯一区分信号太弱。

**`+N more moments` 不显示**——它本来就是 0。**pops 照常显示**——这行唯一能说的就是"这里攒了 24 个词"。

### 5.6 行内预设图

**它不是 hero 预设图的缩小版。** hero 那张是 350×150 的横幅（三段渐变底 + 两团 `blur 36` 光晕 + 96 图标 + 橙点）。缩到 84 宽之后光晕糊成一坨、橙点变成一个脏点。

行内变体只保留**暖色渐变底 + 居中图标**：

| 项 | 常规行 | 纯查词行 |
|---|---|---|
| 底色 | `#FFF3EB → #FFDFCC` 斜向 | `#FCF7F2 → #F5EDE6` |
| 图标 | 28，描边 `rgba(150,88,50,.42)` | 28，描边 `rgba(150,88,50,.30)` |
| 光晕 / 橙点 | **无** | **无** |

共用同一个 `SceneCategory` → `Path` 映射。

> **实现注意**：`PresetIconShape` 目前是 `CategoryPresetArtView.swift` 里的 `private struct`，行内变体用不到。需要把它提到文件级 `internal`，或抽成独立文件。**不要复制一份 path 定义**——12 个图标的 path 必须只有一处真相。

---

## 六、边界情况

| 情况 | 表现 |
|---|---|
| **只有 1 个已解锁分类** | 只有 hero，`More to talk about` 标题与列表**整块不渲染**，下方直接是 `Topics in progress`。不做任何补白——本来就只有一件事可聊，不假装有选择 |
| 一个 `featured` 都没有 | hero 出模式 D 卡；More 只剩组 2（纯查词） |
| `scene_detail` 为 `nil` 或非目标语言 | meta 行只显示 `+N more moments`，不留空位、不留分隔点。校验规则复用 hero |
| `preview_words` 为空（组 2） | 主句位留空，只显示 `No moment yet`。不再降级到别的字段 |

---

## 七、改动清单

**零后端改动。** 所有字段都来自 `categories[].featured` 与 `sub_scenes`，`get_tab2_home` 与 `Tab2HomeData` 一行不用改。

| # | 文件 | 改动 |
|---|---|---|
| 1 | **新增** `Mine/Components/Tab2MomentRow.swift` | 行组件。两种状态（常规 / 纯查词）由行组件按 featured 有无自判，不拆两个 View |
| 2 | **新增** `Mine/Components/RowPresetThumb.swift` | 行内预设图（§5.6）。或作为 `CategoryPresetArtView` 的第二个尺寸变体放同一文件 |
| 3 | `Mine/Components/CategoryPresetArtView.swift` | `PresetIconShape` 由 `private` 提升为文件级可见，供 #2 复用 |
| 4 | `Mine/Tab2HomeViewModel.swift` | 新增 `moreCategories(excludingHero:)`，按 §4 分两组排序。`ranked()` 直接复用不改 |
| 5 | `Mine/MineView.swift` `contentSections` | hero 之后插入 `More to talk about` 标题 + 列表。`Topics in progress` 整段**一行不改** |
| 6 | `Theme/Theme.swift` | 新增 `AppTheme.Tab2MoreRow` 命名空间：行高 100、缩略图宽 84、圆角 16、阴影、两档透明度（照片 tone 与纯查词行）、行内照片的饱和度与 multiply 值 |

**间距**：hero → `More to talk about` 标题用 `Space.paddingBetweenSections`；标题 → 首行用 `Space.paddingCard`；列表末行 → `Topics in progress` 用 `Space.paddingBetweenSections`。

---

## 八、待验证 / 以后迭代

| # | 项 | 说明 |
|---|---|---|
| 1 | **主句长度分布** | §5.2 那句 SQL，上线前跑一次。这是"固定两行"这个决定的唯一依据 |
| 2 | 场景碎片化归并 | `classifyScene` 的 TODO。它让 `+N more moments` 虚高、moment 数失真——**同时影响 hero 与本列表的排序** |
| 3 | 点击频次「曝光未点」负向降权 | 只做负向，不做正向（位置偏差 + 舒适区强化 + 冷启动无解） |
| 4 | 缩略图宽度 | 若截断率高，84 → 70 能给正文多约 2 字符/行 |

---

## 附 · 本节明确拍板不做

| 不做 | 理由 |
|---|---|
| 母语行 | 两个截断的摘要叠在一起更难读；中文视觉重量把重心拽下去 |
| 行上的 CTA 按钮 | N 个同等号召 = 没有号召，稀释 hero 的推荐强度 |
| 一行一个分类（而非代表 moment） | 与 hero 语义不平行 |
| 跨分类打平所有 moment | 那是 Library 的活；且 `sub_scenes` 三字段不同源会导致图文错配 |
| 行数上限 / 「查看全部」入口 | 最多 11 行，随解锁生长，不需要 |
| 纯查词行用衬线摆词 | 形式撒谎——冒充句子 |
| 纯查词行用 chips 胶囊 | chips 是独立视觉语言，会和其余行断开 |
| 缩小 hero 预设图当行内缩略图 | 光晕糊成一坨、橙点变脏点 |
