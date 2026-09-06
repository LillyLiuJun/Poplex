# Tab2 Hero 卡 · 视觉与选取 v2

> **范围**：Tab2 已解锁态的**顶部大卡**。`More to talk about` 列表与 `Topics in progress` 不在本轮。
> **与现有文档的关系**：替代 `Tab2首页_实现规范_v1.md` §4.2；修订 `Tab2_练习入口与信息架构_设计方案_v2.md` 的 featured 排序。
> **冲突时以代码为准**——与代码不符时改本文并说明。
> 硬约束遵守 `CLAUDE.md`：iOS 17+ / `NavigationStack` / `@Observable` / 颜色字号走 `AppTheme` token / 产品 UI 文案为目标语言。

---

## 一、术语

本文之前，"moment"在代码注释、设计方案、SQL 里指的是三种不同的东西。先统一。

```
分类  scene_category    饮食 / 工作与学业 / …（12 个固定枚举，全局共享）
  └─ moment  scene_detail    "Cooking"（同一标签下的一组素材 = 一件反复发生的事）
       └─ 素材  material     一条 material_type='scene' 的 material
```

| 词 | 对应 | 说明 |
|---|---|---|
| **分类** | `scene_category` | `materials` 表的 `CHECK` 枚举，12 个中文值，全局共享。UI 经 `SceneCategoryMap` 转目标语言展示 |
| **moment** | `scene_detail` 分组 | 同一 `scene_detail` 下的所有 scene 素材。**不是某一次，是一件反复发生的事** |
| **素材** | 一条 material | `material_type='scene'`（sentence / passage）。`material_type='vocabulary'`（查词）不是素材层的成员 |

**`featured` 不是 moment**，它是「某个 moment 里被选中来代表它的那一条素材」。卡片上三行的语义因此是：

```
Cooking                                  ← moment 名（这是件什么事）
"The sauce came out way too salty."      ← 代表这个 moment 的那条素材
今晚酱汁太咸了                             ← 母语兜底
```

**`moment_count` 数的是 moment，口径正确**——`get_tab2_home` 里它是 `scene_counts` 按 `(scene_category, scene_detail)` 分组后的组数。但那段 SQL 的注释写着「moment = 非 word 素材」，与实现不符，需修正（见 §9.1）。

---

## 二、页面结构

```
Talk about today

┌───── hero 单卡 ─────┐   ← 本文范围
└─────────────────────┘

More to talk about       ← 下一轮设计
  [列表行] …

Topics in progress       ← 本轮不动
```

**为什么不是横向轮播**（现状 `MineView.contentSections` 是 `ScrollView(.horizontal)` + `frame(width: 350)`）：横滑要成立需同时满足「同级、定量、等高」。三条都不满足——hero 与其余分类是明确的层级关系（非同级）；分类逐个解锁，数量从 1 长到十几（非定量）；卡片高度由内容驱动（非等高）。且 `Topics in progress` 必须在下方，页面本就竖滚，横滚子区只带来手势归属歧义。

**Topics in progress 本轮完全不动**，包括其手风琴展开、`CategoryProgressRow`、进度条样式。

---

## 三、卡片视觉规格

### 3.1 骨架

| 项 | 值 |
|---|---|
| 卡片宽 | 350（列表内左右各留 `Space.paddingPage`） |
| 图区高 | **150**（固定） |
| 文字区高 | **自适应**，138.5 – 179 |
| 卡片总高 | **274 – 315**（= 150 + 文字区 − 14 重叠） |
| 圆角 | 20 · `Radius.glassContainer` |
| 阴影 | `radius 8 · y 2 · Shadow.cardColor`（原 `radius 12 · y 4`） |
| 底色 | `Color.warmGlassSurface` |
| 图文重叠 | 文字区 `offset y: -14`，**照片卡与预设卡统一** |

**为什么高度自适应而不是固定**：固定高度的理由是「多张卡连续排列时高矮不一像锯齿」——这条**只对 More 列表成立**。hero 是页面上唯一的一张卡，没有比较对象，高一点矮一点用户只感知为下方列表整体位移。反之固定到 329 的代价是实打实的：短句卡下方空出 40pt，CTA 孤零零飘着，像没加载完。这也与 `PRD.md` 的「内容驱动 UI」一致。

四种实际行数的高度：

| 主句 × 母语 | 文字区 | 卡片总高 |
|---|---|---|
| 1 + 1 | 138.5 | 274 |
| 1 + 2 | 156 | 292 |
| 2 + 1 | 161.5 | 297 |
| 2 + 2 | 179 | 315 |

**关于那 14pt 重叠**：照片底部是渐隐的，最后一小截几乎全透明，看上去是一条空白带；文字区上挪 14 正好盖掉它，不浪费版面。预设图没有渐隐（见 §6），本不需要这个重叠——但它的底色本来就渐变到**纯白**，而文字区也是白的，用白盖白视觉上什么都不发生；图标底边落在 128，被盖区域从 136 才开始，碰不到。**所以两种卡统一用 -14，卡片高度对齐，且预设图构图一个像素都不用动。**

### 3.2 图区

| 项 | 规格 |
|---|---|
| 高度 | 150 |
| 底部渐隐 | 42% `mask`（`linear-gradient` 58% 处开始透明）。**仅照片**——mask 的作用是化开照片的硬边缘，预设图本身就是暖纸底、没有硬边要化，改用底色自渐变（见 §6） |
| 拼图张数 | **≤3**。c1 满铺 / c2 左右等分 / c3 左 1.55 : 右 1、右侧上下二分 |
| 间隙 | 3 |
| slot 1 | **恒为 featured 那条素材的照片**（见 §5） |
| 照片滤镜 | `saturation 0.7`（原 0.9） |
| 色调层 1 | `#FFB588` · multiply · 20% |
| 色调层 2 | `#FFF3EB` · soft-light · 45% |
| 顶部压暗 | 高 54，`rgba(33,24,17,.30) → 0`。**仅照片；预设图不加** |

底部渐隐取代了原来的硬边——图区不再是一个贴在文字上方的矩形块，而是渐隐进纸面。两层色调把杂乱的用户照片（泡面锅、货架、榻榻米）拉进同一色系，读作材质而不是六张互不相关的照片。

### 3.3 标签行

| 元素 | 位置 | 字体 | 颜色 |
|---|---|---|---|
| 分类名 | 左 16 · 顶 12 | 10.5 / 800 / 字距 1.4 / 全大写 | 照片上 `#FFFFFF` + 阴影<br>预设图上 `#8A4A20` 无阴影 |
| pops | 右 16 · 同一基线 | 10.5 / 600 / 字距 0.2 | 照片上白 82% + 阴影<br>预设图上 `#8A4A20` 62% |

两者 `alignment: .firstTextBaseline`，读作一组信息（这是哪个分类、它有多满）而不是两个独立徽标。文字阴影 `y1 blur6 黑50%`。

### 3.4 文字区三行

| 行 | 字体 / 行高 | 颜色 | 上间距 | 行数 |
|---|---|---|---|---|
| 主句 | 衬线 **17** / 600 / 1.35 · `Font.cardSentence` | `#211811` | 0（贴文字区顶） | `lineLimit(2)` |
| 母语 | 12.5 / 400 / 1.4 · `Font.chineseFaint` | `#7C7773` | 8 | `lineLimit(2)` |
| meta | 11.5 / 600 / 1.4 | `#7C7773`；分隔点与 `+N` 用 `#C7C3BD` | 4 | 1 行 |

**meta 行的两段抢位规则**：

- `scene_detail`：`lineLimit(1)` + `.frame(maxWidth: 175, alignment: .leading)` + 尾部截断
- `· +N more moments`：`layoutPriority(1)`，**永远完整**

宽度验算：可用宽 350 − 32 = 318。`+999 more moments`（最坏情况）约 120 + 分隔点 11 + `scene_detail` 175 = 306 < 318。

那个数字比场景名更需要完整——它是「这个话题还有货」的唯一信号。

### 3.5 CTA

| 项 | 值 |
|---|---|
| 尺寸 | 高 42，左右内边距 22，圆角 21 |
| 位置 | 右下角，距右 16 距底 16 |
| 底色 / 字色 | `#211811` / `#FFFFFF` |
| 字体 | 13.5 / 650 · `Font.ctaLabel` |
| 图标 | `arrow.right`，`imageScale(.small)`，与文字间距 7 |
| 文案 | `Start talking`（不变，四模式统一） |
| 按压 | 整卡 `scaleEffect 0.97` + `spring(0.25, 0.7)`（沿用 `HeroCardPressStyle`） |

它是全页唯一的实心深色按钮。唯一性本身就是强调，不需要靠尺寸。

### 3.6 删除的元素

| 删除 | 理由 |
|---|---|
| 图上的 `+N more moments` overlay | 与 pops 重复表达「这个分类有多满」；移到 meta 行 |
| `created_at`（`18 days ago`） | 旧不旧不影响想不想说，是库存视角的元数据 |
| `from your photo`（**连相机图标一起**） | ① 对「要不要开口」无影响 ② 顶部那张照片已经说了同一件事 ③ 占 85pt，把 `scene_detail` 压到放不下 |

---

## 四、四种模式

### 4.1 判据

只看 `(user_original, input_lang)` 两个值（沿用 `Tab2HeroCard.featuredMode`，不改）：

| 模式 | 判据 | 主句 | 母语行 | 引号 |
|---|---|---|---|---|
| **A** 你说过的英语 | `user_original` 非空 且 `input_lang == "target"` | `user_original` | `native_meaning` | **有** |
| **B** 想说没说出 | `user_original` 非空 且 `input_lang != "target"` | `target_expression` | `user_original` | 无 |
| **C** 你拍下的场景 | `user_original` 为空 | `target_expression` | `native_meaning` | 无 |
| **D** 全是查词 | 无 `featured` | 见 §4.4 | — | — |

**上目标语言、下母语**在四个模式里恒定，不因来源翻转（Tab1 才有不对称，Tab2 统一）。引号只在 A 出现，语义是「这串目标语言是你真的产出过的」。B 的母语行是用户自己打的中文，比翻译有温度，不要弱化过头。

`input_lang == "other"`（第三语言）按非目标语言处理，落 B。

### 4.2 passage

**现状是坏的**：长文卡的 `target_expression` 按 prompt 定义存的是**整篇原文**（`generate/index.ts:339`），hero 卡把它当一句话渲染，主句变成一整篇被截成两行。`native_meaning` 同理，是整篇中文翻译。

**修法**：`passage_lines` 是现成的双语逐句数组（`generate/rawContent.ts:26`，`{en, zh}[]`），长文卡在 Tab1 本就逐句对照展示，所以这个数组一直在存。

| 卡片位置 | 句子卡 | 长文卡 |
|---|---|---|
| 主句 | `target_expression` | `passage_lines[0].en` |
| 母语行 | `native_meaning` | `passage_lines[0].zh` |

回退链：`passage_lines[0].en ?? target_expression`，母语同理。SQL 侧两个 `COALESCE`，前端零改动。

**不加任何来源标记。** 原设想的 `from a long read` 已删——`a long read` 要求读者熟悉这个英文惯用法；更根本的是用户不需要知道这句出自长文还是单句，他要做的事一样。来源是系统的内部区分，不是他的决策信息。

**够用与不够用**：第一句通常是话题句，最能代表这篇讲什么。但用户被记账的那个词可能在第八句——理想是显示「那个词所在的那一句」，需在记账时绑定行号，即缺口 7（见 §10）。缺口 7 修完后本节的取值自然升级，卡片排版一行不用改。

### 4.3 模式 D

这个分类只有查词，没有任何可聊的事。

| 位 | 内容 |
|---|---|
| 图区 | **与「featured 无图」共用同一张预设图**，不做任何特殊设计 |
| 文字区 | **3 行**，每行一个词：`英文（衬线 16/600）· 词性（10.5 斜体 #C7C3BD）· 释义（12.5 #7C7773）` |
| 取哪 3 个 | `preview_words` 前 3（最近入账） |
| CTA | 不变 |

**数量 3 是排版倒推的结果**：文字区可用 152 − 42 CTA − 16 底边距 − 12 `Spacer` 最小值 = 82，词行高 26，正好 3 行。

**释义必须有。** 这些恰恰是用户当时**不认识**才查的词。只放 `back up / glitch / firmware` 是一串需要解码的符号，用户得先回忆每个是什么意思——在 hero 位上这是反向的，它应该降低开口门槛而不是抬高。

**明确不做**：

| 不做 | 理由 |
|---|---|
| 标题行 `Your collected words` | 词本身就是内容，不需要一句话介绍。省下的一行正好让三个词都放下 |
| 词数 `24 words` | 与顶部 pops 是同一个数 |
| 底纹 | 与图区渐变叠在一起，上半部出现两层暖色块界限反而模糊；且给 D 卡加了一个只属于它的容器，A/B/C 的文字区都是直接落白底 |
| chips 胶囊 | chips 是一套独立的视觉语言，D 卡一用就和其他卡断开 |
| 词墙 / 词云图区 | 同上，破坏图区统一 |

释义与词性来自 `preview_words`，需改 RPC 返回结构（见 §9.1）。

### 4.4 截断规则

| 行 | 上限 | 溢出 |
|---|---|---|
| 主句 | 2 行 | 系统默认尾部省略号 |
| 母语 | 2 行 | 同上 |
| `scene_detail` | 1 行 / 175pt | 尾部省略号 |
| `+N more moments` | — | **永不截断** |
| 模式 D 释义 | 1 行，占满剩余宽 | 尾部省略号 |

**不做自适应字号、不做滚动、不做展开。放不下就截。** 卡片只负责让用户决定要不要点，完整内容在对话页。

`generate` 的 prompt 对 `target_expression` / `user_original` / `native_meaning` **没有任何长度约束**（已核查），所以卡片必须自己扛住任意长度。

---

## 五、图文绑定

本轮最核心的修正。

### 5.1 现状：只有一种分支会错配

`featured` 的主句和 `featured.image_url` 来自同一条 material（SQL 里都是 `m.raw_content->>'…'`），这两者永远同源。但屏幕上那块图是 `hero_photos[]`——**分类级**数组，来自该分类下所有有照片的 material。

关键那段：

```sql
COALESCE(r.material_id = f.material_id, false) AS is_featured,
ROW_NUMBER() OVER (PARTITION BY scene_category
  ORDER BY COALESCE(r.material_id = f.material_id, false) DESC, r.created_at DESC)
```

`r` 只装有照片的 material。featured 若无图，它不在 `r` 里 → 所有行 `is_featured = false` → 第一个排序键失效，退化成纯 `created_at DESC` → slot 1 变成「该分类最近拍的那张」，与主句毫无关系。

按分类照片数分三种：

| 照片数 | 单图绑定 ⓪ | featured 有图 | slot 1 | 会错配 |
|---|---|---|---|---|
| 0 | 不触发 | 必然无图 | `hero_photos` 为空 → 预设图 | 不会 |
| 恰好 1 | **触发**，强制选那张照片的 material | 必然有图 | 必然是它 | 不会 |
| **≥2** | 不触发 | **可能无图** | 退回 `created_at DESC` | **会** |

发生条件：分类有 2 张以上照片，而五层排序恰好选中一条无照片的 material。因为排序第 ① 层「方向×粒度」高于第 ② 层「意图明确度」，一条 `express + sentence 无图` 会赢过 `comprehend + sentence 有图`。屏幕上就成了昨天拍的泡面配上周打字写的会议那句话——而用户会本能地以为它们是一回事。

### 5.2 规则

> **拼图 slot 1 要么是主句那条素材的照片，要么这张卡就不配图。**

| 情况 | 顶部区 |
|---|---|
| `featured.image_url != null` | 拼图，slot 1 = featured 的照片 |
| `featured.image_url == null` 但分类有其他照片 | **不拼图**，走预设图 |
| 分类完全无照片 | 预设图 |

代价是有照片的分类偶尔显示预设图。收益是**图文永不说谎**——这个信任破一次就很难修回来。这是 hero 独有的严格要求；More 列表的缩略图只是装饰，可以宽松。

### 5.3 featured 排序改动

「有图」不是视觉需求，是**内容决策**：hero 卡的上半部分就是图，占接近一半。featured 无图不是「少一张配图」，是整张卡的上半身退化成一块什么都没说的色块。这个权重高于 express/comprehend。

| 层 | 改动前 | 改动后 |
|---|---|---|
| ⓪ | 单图绑定 | **删除**（已冗余） |
| ★ | — | **有照片优先**（新增，第一层） |
| ① | 方向×粒度 | 保留，降为第二层 |
| ② | 意图明确度 | 保留 |
| ③ | 新鲜度 `spoken_count = 0` | **删除**（字段不可信，见 §7.4） |
| ④ | 场景高频 `occurrence_count DESC` | 保留 |
| ⑤ | `created_at DESC` | 保留 |

**为什么删单图绑定**：它原本解决「分类只有一张照片时别浪费它」。加了 ★ 之后，只有一张照片就只有一条素材有照片，★ 自动把它选出来。少一段特殊逻辑，少一处 bug。

**关于「系统性偏向 comprehend」的担心**：有图优先确实会让无图素材排在后面（`express` 多为打字输入，常无图；`comprehend` 多为拍照，必然有图）。但配合 §7.3 的硬过滤「还没聊过」，有图素材聊过一轮后就退出候选，实际效果不是「无图永远上不了 hero」而是「有图的先轮完，再轮到无图的」。**这两件事是绑定的**——若不做那条硬过滤，有图素材会被反复推送，无图的真的永远见不到光。

---

## 六、预设图

### 6.1 触发场景

三个场景共用同一套，不细分——预设图的语义就是「这里没有可信的照片」，不该按原因再分：

1. 分类完全没有照片
2. **`featured` 那条素材没有照片**（本轮新增，防图文错配，见 §5.2）
3. 模式 D（全是查词）

### 6.2 与照片图区的关键差别：不套 mask

照片要套底部渐隐 mask，是因为照片有**硬边缘**，不化开就像贴上去的一块。预设图本身就是暖纸底，它和纸面是同一种东西，**没有硬边要化**。照搬 mask 的代价是吃掉一半构图空间（可用高度从 150 压到 55），图标会被截。

所以预设图**不套 mask**，改为底色自身渐变到卡片白：

```
background: linear-gradient(to bottom, #FBF6F1 0%, #FCF8F5 62%, #FFFFFF 100%)
```

接缝一样看不见，整个 150pt 全部可用。文字区仍按 §3.1 上挪 14 —— 被盖住的那 14pt 本来就是纯白，无任何视觉损失。

### 6.3 规格

**基座**

| 项 | 值 |
|---|---|
| 尺寸 | 350 × 150 |
| 底色 | `linear-gradient(to bottom, #FBF6F1 0%, #FCF8F5 62%, #FFFFFF 100%)` |
| mask | 无 |

**光晕**（两团，`blur 36`）

| # | 尺寸 | 位置 | 颜色 | 透明度 |
|---|---|---|---|---|
| 1 | 220 × 165 | `left: 20, top: -20` | `#FFD3B8` | `.55` |
| 2 | 180 × 140 | `right: -40, top: 24` | `#FFEEE2` | `.90` |

**图标**

| 项 | 值 |
|---|---|
| 尺寸 | 96 × 96（`viewBox "0 0 24 24"`） |
| 位置 | `right: 38, top: 32` |
| 描边 | `rgba(150, 88, 50, 0.19)` |
| 线宽 | 1.9，`lineCap: .round`，`lineJoin: .round`，无填充 |

**橙点**

| 项 | 值 |
|---|---|
| 尺寸 | 8 × 8 圆 |
| 位置 | `left: 46, top: 74` |
| 颜色 | `#FF7622`，透明度 `.90` |

**标签行**：同 §3.3 的预设图配色（分类名 `#8A4A20` 无阴影，pops `rgba(138,74,32,.6)`）。

### 6.4 12 张的变量

**只有图标那段 path 变，其余逐字复用。** 底色、两团光晕、图标尺寸与位置、描边色与线宽、橙点位置与颜色、标签行——12 张完全一致。

实现上是一个接收 `Path` 的视图，`SceneCategory` 提供各自的图标。视觉稿见 `design/tab2_preset_b.html`（方案 B1）。

**接口不变**：`CategoryPresetArtView(category:categoryLabel:popsText:moreCount:)`。`moreCount` 参数保留但不再渲染（moments 已移到 meta 行）。

## 七、hero 选取逻辑

### 7.1 两层机制

**第一步（SQL）**：给每一个分类各挑出一个 `featured`（§5.3 的排序）。挑不出的（全是查词）返回 `featured = null`。

**第二步（Swift）**：在这些已各自选好 featured 的分类里，挑一个当 hero。

前端拿到的其实是这样一张表：

| 分类 | 攒够料 | 有可说的事 | 那件事什么时候的 | 还剩几个没聊的 moment |
|---|---|---|---|---|
| 饮食 | ✅ 40 pops | ✅ 榴莲那件 | 19 天前 | 4 |
| 工作与学业 | ✅ 41 pops | ✅ 会上大脑空白 | 昨天 | 2 |
| 科技数码 | ✅ 24 pops | ❌ 全是查词 | — | 0 |
| 家庭与人际 | ❌ 11 pops | — | — | — |

### 7.2 现状三个毛病

`Tab2HomeViewModel.heroCategory`（第 141–156 行）现在是：有 featured 的按 `lastMaterialAt` 降序取第一；否则取 `wordCount` 最大的。

**① `lastMaterialAt` 被查词污染。** 它是 `MAX(lexicon_occurrences.created_at)`——查词也会刷新。用户查了个词，那个分类被顶到 hero，但 featured 展示的可能是一个月前的句子。排序依据说的是「这个话题最近有动静」，展示的是「这个话题里最值得说的那件事」，两句话说的不是一回事。

**② 没考虑聊过没聊过。** 用户昨天刚对着这张卡聊过，今天打开还是它。hero 从「承诺」退化成壁纸。

**③ 降级路径是反的。** 没有 featured 时取 `wordCount` 最大——但没有 featured 恰恰意味着这个分类全是查词、**没有可说的经历**。给用户一个说不出话的开场。

### 7.3 新规则

```
候选 = unlocked
       && featured != nil
       && 该分类还有「没聊过」的 moment
   ↓ 有候选
① 分档：featured.createdAt 在一周内的排前面
② 档内：按「没聊过的 moment 数」降序
③ 平手：按 featured.createdAt 最新
   ↓ 候选为空（都聊过了）
兜底 1：忽略「聊过」，同规则重排一遍（复习也是练习）
   ↓ 一个 featured 都没有
兜底 2：取 pops 最多的分类，出模式 D 卡
```

**hero 位永远有卡。** 不显示 hero 会让用户第一眼看到一个空开头，比给他一张不完美的卡更糟。

**三个维度分工**：

| 维度 | 角色 | 为什么 |
|---|---|---|
| 是否练过 | **硬过滤**（二元） | 不参与比大小 |
| 时效 | **分档**，不是连续值 | 「3 天前」和「5 天前」对用户是一样的「最近」，让它们分胜负没意义，只会让 hero 天天换 |
| 剩余量 | **档内排序** | 用「没聊过的 moment 数」而非 `moment_count`——总量回答「攒了多少」，hero 要回答「还剩多少能聊」 |

**为什么按时间而不是别的**：不是「新的比较好」，是**记忆有热度**。昨天开会大脑空白，用户还记得当时的尴尬、对方的表情——他有一肚子话。三周前的榴莲他大概只记得「很大、很贵」，聊起来是干的。产品核心是「有话想说但说不出来」，而**「有话想说」是有保质期的**。

**为什么用 `featured.createdAt` 而非 `lastMaterialAt`**：见 §7.2 ①。换用之后「选哪个分类」和「露哪条素材」用同一个时间，图、句、时间三者同源。

**为什么剩余量不用 `word_count`**：`word_count` 包含查词。一个分类 40 pops 可能是 35 次查词 + 5 件事，看着厚聊起来薄。pops 继续在卡片上给用户看成就感，但**排序不用它**。

**`createdAt` 的诚实缺陷**：它是素材被记录的时间，不是事情发生的时间。可以接受，且偏差方向是对的——用户今天特意去记上周的事，说明这件事今天还在他脑子里，按记录时间排反而更贴近「现在有多少话想说」。

### 7.4 「聊过」记在 moment 层，本地存储

**不用 `spoken_count`。** 它在 `lexicon_entries` 上，是**词条级**的（只有 `source_type='dialogue'` 的记账才 +1，是 breakthrough 北极星指标的来源）。SQL 的 `DISTINCT ON (scene_category)` 每分类只保留一行，那一行对应某**一个词**。所以 `featured.spoken_count` 的真实含义是：

> 「这条素材上，恰好被 `DISTINCT ON` 选中的那个词，被说过几次」

而哪个词被选中是排序规则的副产品——不稳定，也不代表整条素材。一句话里 6 个词，聊过一轮后可能只有 3 个的 `spoken_count` 涨了，选中一个没涨的就会判成「没聊过」。

**改为前端记。** 对话结束时把 `scene_detail` 写进本地集合（`UserDefaults`，同 `tab2_unlocked` 的写法）：

- **记在 moment 层，不是素材层**：聊的是「煮晚饭」这件事，不是某一条具体素材。一个 `scene_detail` 只要聊过一次就算练过。
- 准确、零 SQL，且顺便把 §7.5 的稳定机制做掉了——这份记录本来就是「哪些聊过了」的真相来源。
- 附带好处：以后想做「聊过的打个勾」或「本周聊了 3 件事」，数据现成。

### 7.5 hero 稳定

§7.3 决定的是「**第一次**该露哪件事」。用户可能看一眼、犹豫、退出、再进来——每次重算的话那张卡就不见了，「有一件非做不可的事」的感觉随之消失，首页退回成一个随机推荐器。

**选中后存住 `material_id`，只在两种情况下换**：

1. 用户对着它聊完了
2. 有更新的 moment 进来（用户记录了新东西）

除此之外，无论退出几次、刷新几次，回来还是那张卡、还是那句话。

### 7.6 明确不做：点击频次

作为**正向**信号有三个问题：

- **位置偏差污染**：hero 的点击率天然比列表行高几倍。用点击喂回排序 = 「因为它是 hero 所以被点，因为被点所以继续当 hero」。这个循环里只有位置的信息，没有偏好的信息。
- **与产品目标反向**：用户爱聊饮食就一直给饮食，但他真正需要练的可能是工作场景。这会把系统推向**舒适区强化**。
- **冷启动无解**：新用户零数据，前几周纯噪音。

**以后可做的变体**：用「露出了但没点」当**负向**信号——连续 3 次当 hero 未被点击则降权一轮。分母是曝光不是位置，不受位置偏差影响，捕捉的是真实的「我现在不想聊这个」。列入 §10。

---

## 八、`scene_detail` 的语言与长度

### 8.1 现状

`generate/index.ts` · `classifyScene()`（586–661 行）。

**Prompt（602–604 行）**：

```
JSON: {"category":"<from list above>","sub_scene":"<specific activity in English, never null>"}

sub_scene: complete activity in English, strip qualifiers ("做晚饭"→"Cooking").
Anchors: 饮食→Cooking/Eating out; 休闲娱乐→Watching sports/Watching a show;
         运动健康→Running/Playing sports; 出行交通→Commuting/Driving.
```

三个问题：

1. **两处写死 `in English`** — 违反 `CLAUDE.md:132`（prompt 必须用 target/native 抽象）
2. **示例里带中文** — `("做晚饭"→"Cooking")`；加上输入里的 `Context: "${userOriginal}"` 本身就是母语，而 `in English` 埋在句中权重太弱，模型顺着母语走的概率被抬高。截图中出现过 `安全提醒` 这类中文 `scene_detail`
3. **完全没有长度约束** — `complete activity` 没说几个词。`maxOutputTokens: 100` 是 token 上限，不是内容约束

**后端校验（653–656 行）**：

```ts
const subScene =
  (typeof parsed.sub_scene === "string" && parsed.sub_scene.trim())
    ? parsed.sub_scene.trim()
    : null;
```

只校验「是不是非空字符串」。**没有语言校验，没有长度校验。** 对比同段的 `category`（649–652 行）有白名单 `SCENE_CATEGORIES.includes(...)`，`sub_scene` 一个都没有。

### 8.2 违反的两条已定约束

| 出处 | 原文 |
|---|---|
| `CLAUDE.md:132` | **Target / native language must not be hardcoded.** MVP is English-as-target and Chinese-as-native, but **prompts** and field names reason in terms of "target" and "native" |
| `Tab2首页_实现规范_v1.md:222` | 子场景标签**用目标语言生成**（`Making dinner` / `Commuting`） |

`设计方案 v2 §896`（待确认项 0c3）当年就点出了病因：「子场景标签用目标语言还是母语生成…**但 §2.3 现有示例全是中文**」。所以这不是新决策，是**对齐已有约束**。

### 8.3 `sub_scene` 是什么

**开放词表 + 高抽象度。**

不是从固定列表里选（那会让它退化成第二个 `scene_category`，每个用户的科技数码都叫 `Using an app`，整个 moment 层塌掉）；也不是描述这一次的具体事件（那会让每次输入生成一个新标签，碎片化更严重）。

而是：自由生成，但挑一个**足够宽、能容纳后续同类场景**的词。`Cooking` 能吸收未来所有做饭的记录，`Cooking dinner tonight` 只能装它自己。

**抽象度本身就是防碎片化的机制**，而且是当前唯一可用的机制——见 §8.5。

### 8.4 改法

**一、Prompt**

```
JSON: {"category":"<from list above>","sub_scene":"<recurring activity, never null>"}

sub_scene: the recurring activity this scene belongs to — a broad label that
many similar scenes can share, not a description of this one occasion.
Write it in the TARGET LANGUAGE only; never echo the native language, even
when the Scene or Context above is written in it.
Strip qualifiers and specifics: "Cooking", not "Cooking dinner tonight";
"Fixing a device", not "Helping mum set up her new phone".
Aim for this level of abstraction:
Cooking / Eating out / Commuting / Driving / Running / Watching sports /
Watching a show / Working / Studying / Shopping / Chores / Catching up
```

改动清单：

| 原 | 新 | 理由 |
|---|---|---|
| `<specific activity in English>` | `<recurring activity>` | 去掉硬编码语言；`recurring` 点出抽象度 |
| `complete activity in English` | `TARGET LANGUAGE only` + `never echo the native language, even when the Scene or Context above is written in it` | 对齐主 prompt 的抽象说法；补的那句针对真正的病因——输入里的 `Context` 本身是母语 |
| `("做晚饭"→"Cooking")` | `"Cooking", not "Cooking dinner tonight"` | 纯目标语言即可演示「去修饰语」 |
| `Anchors: 饮食→Cooking/…` | `Aim for this level of abstraction:` + 纯目标语言列表 | 锚点的作用是校准抽象度，不需要按分类逐条给；去掉左侧中文 |
| — | — | **不写字数**。给了上限模型就往上限靠，而示例本身已经示范了长度 |

上面那份 `Categories:` 中文枚举列表**保留**——那是数据库 enum 的值，不是输出语言问题（相关技术债见 §10）。

**二、后端校验**

```ts
// 与目标语言绑定；MVP = English-as-target。换目标语言时只改这一行。
const TARGET_SCRIPT = /^[A-Za-z][A-Za-z\s'\-]*$/;
const MAX_SUB_SCENE = 24;

const rawSub = typeof parsed.sub_scene === "string" ? parsed.sub_scene.trim() : "";
const subScene = rawSub && TARGET_SCRIPT.test(rawSub)
  ? rawSub.slice(0, MAX_SUB_SCENE).trimEnd()   // 超长截断，不丢
  : null;                                       // 语言不对才丢
```

**关键是两种失败分开处理**：

| 校验 | 失败处理 | 为什么 |
|---|---|---|
| 语言 | 落 `null` | 内容本身错了，截断救不回来 |
| 长度 | **截断，不落 null** | 只是显示问题，前 N 个字符照样能用，也照样能当分组键 |

若长度也落 `null`，模型多说一个词就整个丢掉 `scene_detail`，meta 行少一段——把一个能修的问题当成不能修的处理。**改后长度不再产生任何 `null`。**

`24` 按新锚点定：最长的 `Watching sports` / `Morning routine` 是 15，余量充足；真超过 24 一定是模型没听话，截掉不影响它作为分组键的稳定性（截断是确定性的）。

用正向白名单而非「排除 CJK」：后者等于把「目标语言不是中日韩」写死进代码，同样违反 `CLAUDE.md:132`。白名单加注释把耦合点集中在一行。

**三、前端兜底**

- `scene_detail` 为 `null` 时，meta 行只显示 `+N more moments`，不留空位、不留分隔点
- 渲染前跑一次同样的 `TARGET_SCRIPT` 校验，不通过按 `null` 处理

### 8.5 存量数据不 backfill

已落库的中文 `scene_detail`（如 `安全提醒`）由 §8.4 第三层挡住，不洗库。

理由是 `scene_detail` 除了上屏还承担 **moment 分组**（`moment_count`、`+N more moments`、`§7.3` 的「没聊过的 moment 数」全按它分组）。分组只要值稳定就行，是不是中文无所谓。**让它在数据层继续活着、只在展示层挡掉**，比洗库安全，也不影响任何计数。新数据从第一层起就是干净的，旧值随新素材自然稀释。

---

## 九、改动清单

### 9.1 后端 SQL — `get_tab2_home`

| # | 改动 | 位置 | 说明 |
|---|---|---|---|
| 1 | featured 排序：新增「有照片优先」为第一层 | `featured` CTE 的 `ORDER BY` | `CASE WHEN m.raw_content->>'source_image_path' IS NOT NULL THEN 0 ELSE 1 END`，插在现 ⓪ 与 ① 之间的位置成为新首键 |
| 2 | featured 排序：删除「单图绑定」 | 同上 ⓪ 层 + `single_photo_mat` CTE + `LEFT JOIN spm` | 已被 #1 覆盖，整段删除 |
| 3 | featured 排序：删除「新鲜度」 | 同上 ③ 层 `CASE WHEN le.spoken_count = 0 …` | 字段不可信（§7.4） |
| 4 | passage 取值 | `featured` CTE 的 `user_original` / `target_expression` / `native_meaning` 投影 | 主句 `COALESCE(m.raw_content->'passage_lines'->0->>'en', m.raw_content->>'target_expression')`；母语 `COALESCE(…->0->>'zh', …->>'native_meaning')` |
| 5 | `preview_words` 改对象数组 | `cat_words` CTE 的子查询 | `jsonb_agg(sub.lemma)` → `jsonb_agg(jsonb_build_object('lemma',…,'display_form',…,'pos',…,'native_meaning',…))`，需 join `lexicon_entries` 取后三个字段。供模式 D 显示释义 |
| 6 | 修正 `moment_counts` 注释 | `moment_counts` CTE 上方 | 现写「moment = 非 word 素材」，实际数的是 `scene_detail` 组。按 §1 术语改 |

**不改**：`sub_scenes` CTE 本轮仍保留（清理见 §10）。`hero_photos` 的 `slot <= 5` 不改——前端只取前 3，多返回的不渲染，留给 More 列表将来可能的用途。

### 9.2 后端 Edge Function — `generate/classifyScene`

| # | 改动 | 位置 |
|---|---|---|
| 7 | prompt 替换 | 592–604 行，按 §8.4 全文替换 `sub_scene` 说明段与锚点 |
| 8 | 新增语言 + 长度校验 | 653–656 行，按 §8.4 替换 `subScene` 赋值 |

`category` 的白名单校验（649–652 行）不动。

### 9.3 iOS

| # | 文件 | 改动 |
|---|---|---|
| 9 | `Mine/Components/Tab2HeroCard.swift` | 按 §3 重写布局：图区 150、文字区自适应、三行结构、meta 行抢位规则、删除 §3.6 三个元素、模式 D 改 3 行词表 |
| 10 | `Mine/Components/HeroCollageView.swift` | 张数 5→3、高度 178→150、加底部 mask 渐隐、加两层色调、`saturation` 0.9→0.7、`HeroTopOverlay` 去掉 `moreCount` 渲染 |
| 11 | `Mine/Components/CategoryPresetArtView.swift` | 按 §6.3 重做：高度 178→150、去掉 mask 改底色自渐变、两团光晕、图标 96、橙点；新增触发场景「featured 无图」（判据从 `heroPhotos.isEmpty` 改为 `heroPhotos.isEmpty \|\| featured?.imageUrl == nil`）；`moreCount` 不再渲染 |
| 12 | `Mine/MineView.swift` `contentSections` | 横向 `ScrollView` 改为 hero 单卡；`Your topics` 标题去除；`IgnoredTabSwipeFrameKey` 相关的横滑手势规避可一并删除。`Topics in progress` 段落**完全不动** |
| 13 | `Mine/Tab2HomeViewModel.swift` `heroCategory` | 按 §7.3 重写：硬过滤 → 时效分档 → 未聊 moment 数 → `createdAt` 平手 → 两级兜底 |
| 14 | 新增 · 已聊 moment 本地存储 | `UserDefaults` 集合，键存 `scene_detail`；写入点在对话结束回调。参照 `tab2_unlocked` 的写法 |
| 15 | 新增 · hero 稳定 | 存 `material_id`，仅在「聊过」或「有更新 moment」时重算 |
| 16 | `Models/Tab2HomeData.swift` | `previewWords: [String]` → `[Tab2PreviewWord]`（新结构体：`lemma` / `displayForm` / `pos` / `nativeMeaning`）。旧客户端兼容：`decodeIfPresent` 失败时降级为空数组 |
| 17 | 展示层脏数据兜底 | `scene_detail` 渲染前跑 `TARGET_SCRIPT` 校验，不通过按 `nil` 处理 |

### 9.4 依赖顺序与切分建议

```
切片 1（后端，可独立发）
  #7 #8  classifyScene prompt + 校验     ← 越早发，干净数据积累越多
  #6     注释修正

切片 2（后端，前端的前置）
  #1 #2 #3  featured 排序
  #4        passage 取值
  #5        preview_words 结构

切片 3（iOS，依赖切片 2）
  #9–#13 #16 #17  视觉与选取
  #14 #15         本地存储与稳定
```

**#5 与 #16 必须同批发**（RPC 返回结构变更）。#16 的降级路径要在 #5 上线前先发，否则旧客户端会解码失败。

**#14 的写入点依赖对话页**——对话功能当前状态见 `CLAUDE.md` Current State，若对话页尚未接线，先把存储层建好、写入点留 TODO，`heroCategory` 的硬过滤在集合为空时自然退化为「全部候选」，不阻塞。

---

## 十、以后迭代（不在本轮）

| # | 项 | 说明 |
|---|---|---|
| 1 | **More to talk about 列表** | 行构成、缩略图取值、是否显示 pops、排序规则。整块未设计 |
| 2 | **场景碎片化归并** ⚠️ | `classifyScene` 的 TODO：写入前与该用户该分类下已有 `scene_detail` 比对归并。**这是本文选取逻辑的前置依赖**——`Cooking` / `Making dinner` 各成一个 moment 会让 `+N more moments` 虚高，且用户聊过 `Cooking` 后 `Making dinner` 仍算「没聊过」，§7.3 的硬过滤永远为真、该话题被反复推上 hero。§8 的抽象度约束是缓解，不是根治 |
| 3 | 缺口 7 · passage 记账绑定行号 | 修完后 §4.2 的取值自然升级为「那个词所在的那一句」，卡片排版不用改 |
| 4 | 点击频次「曝光未点」负向降权 | §7.6。等有真实用户数据 |
| 5 | RPC 每分类返回 top-3 featured | 解决「featured 恰好聊过，整个分类退出 hero 竞选，哪怕它下面还有 10 件没聊过的事」。`DISTINCT ON` → `ROW_NUMBER() <= 3`，前端跳过聊过的。只有重度用户会遇到，等抱怨再做 |
| 6 | A6 · `scene_category` 中文枚举键 | 见 `优化需求全量清单_v1.md` A6。随 A5 一起做 |
| 7 | `sub_scenes` 死字段清理 | Hero 卡自 v3 起已不用它。但 §7.3 的「没聊过的 moment 数」**需要它**（它提供每分类的 `scene_detail` 列表），所以本轮**不能删**，反而是复活。等 More 列表设计完再评估 |
| 8 | 首次解锁动效 `isFirstUnlock` | 新版式下是否还成立，未评估 |
| 9 | `passage_lines: {en, zh}` 键名 | 写死了 en/zh。目前纯内部不上屏，低优先级 |

---

## 附 · 本轮明确拍板不做

记录决定，防止将来被重新打开讨论。

| 不做 | 理由 |
|---|---|
| 卡片横向滑动 | 同级/定量/等高三条都不满足（§2） |
| 主句三档自适应字号 | 要的是规格不是算法。固定 17pt + 省略号 |
| 「优先在标点处断」的自定义截断 | 用系统默认 `.tail` |
| 卡片内滚动 / 展开 | 放不下就截，完整内容在对话页 |
| 模式 D 词墙 / 词云图区 | 破坏图区统一，给 D 卡一套独有视觉 |
| 模式 D chips 胶囊 | 独立的视觉语言，与 A/B/C 断开 |
| 模式 D 底纹 | 与图区渐变叠出两层暖色块；给 D 卡加了独有容器 |
| 照片满幅 + 渐变压字 | 用户随手拍的照片亮度不可控，白字可读性无下限保障 |
| 卡片固定高度 | hero 只有一张，无比较对象；固定会让短句卡下方空 40pt |
| 点击频次作为正向排序信号 | 位置偏差污染 + 舒适区强化 + 冷启动无解（§7.6） |
| 洗库修正存量中文 `scene_detail` | 展示层挡掉即可，数据层它还要当分组键用（§8.5） |
