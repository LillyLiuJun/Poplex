# Tab2 · More to talk about 列表 v1 · 三刀执行提示词

> 每刀一个独立会话。规格来源：`docs/prd/Tab2_More列表_设计方案_v1.md`（下称「规格文档」）。
> 第 1、2 刀彼此无依赖，可并行；第 3 刀依赖前两刀。
> **零后端改动**——`get_tab2_home` 与 `Tab2HomeData` 一行不改。任何一刀里想动 SQL 或数据模型，都说明理解错了，停下来问。

---

## 第 1 刀 · 选取逻辑（纯数据层）

```
读 docs/prd/Tab2_More列表_设计方案_v1.md 的 §2、§4、§6（只读这三节）。
遵守 CLAUDE.md 的全部硬约束。

任务：在 AIEnglishApp/Mine/Tab2HomeViewModel.swift 里新增 moreCategories，
决定 hero 之外还有哪些分类进 More 列表、按什么顺序。本刀不碰任何视图。

签名：
  func moreCategories(
      excluding excludedCategoryIDs: Set<String> = [],
      hero: Tab2CategoryData?
  ) -> [Tab2CategoryData]

规则（§4）：候选 = 已解锁 && 不在 excludedCategoryIDs && id != hero?.id，
分三组，组间有序、组内各自排序，最后拼接返回：

  组 1  featured != nil && 未聊 moment 数 > 0
        用 ranked(_:momentCount:)，momentCount 传 unspokenMomentCount
  组 2  featured != nil && 未聊 moment 数 == 0
        用 ranked(_:momentCount:)，momentCount 传 subScenes.count
  组 3  featured == nil
        按 wordCount 降序，相等时 id 升序

必须复用现有私有方法，不要新写：
  · ranked(_:momentCount:)            —— 已实现「一周内分档 → moment 数降序 → createdAt → id」
  · unspokenMomentCount(in:spokenMoments:)
  · Tab2Defaults.spokenMoments        —— 已聊 moment 的本地集合

绝对不要：
  · 不要用 featured.spokenCount 判断聊过没聊过（词条级，不可信，见 hero 那轮的结论）
  · 不要用 lastMaterialAt 参与排序（被查词污染）
  · 不要修改 heroCategory 或 ranked 的任何一行
  · 不要新增或修改任何 RPC、migration、Tab2HomeData 字段

不动：本文件里 heroCategory / 稳定策略 / Tab2Defaults 的既有键，以及所有视图文件。

完成标准 —— 新增单测覆盖：
  · 三组分别非空时，返回顺序确实是 组1 → 组2 → 组3
  · hero 所在分类不出现在结果里
  · excludedCategoryIDs（milestone）里的分类不出现
  · 未解锁分类不出现
  · 组 1 内部：一周内的排在更早的前面；同档内未聊 moment 数多的在前
  · 反例：某分类 lastMaterialAt 很新但 featured.createdAt 很旧，不应因此靠前
  · 边界：候选为空时返回空数组，不 crash
项目编译通过。
```

---

## 第 2 刀 · 行组件（纯视图）

```
读 docs/prd/Tab2_More列表_设计方案_v1.md 的 §5 全节。
遵守 CLAUDE.md 的全部硬约束——特别是：所有颜色/字号/间距必须走 AppTheme token，
不得出现字面量 Color(hex:) 或 .font(.system(size:))；产品 UI 文案一律目标语言。

任务：做出 More 列表的行组件和它的缩略图。本刀不碰 MineView、不碰 ViewModel。

范围：
1. Theme/Theme.swift 新增 AppTheme.Tab2MoreRow 命名空间（§7 第 6 条）
   行高 100 / 缩略图宽 84 / 圆角 16 / 阴影 radius 6 y 2 / 三档透明度 /
   行内照片的饱和度 .65 与暖橙 multiply .24 / 两套预设图底色与描边透明度。
   数值一律照 §5 的表，不要自行调整。

2. 新增 Mine/Components/RowPresetThumb.swift（§5.6）
   · 只有「暖色渐变底 + 居中图标 28」两层
   · 两个变体：常规（#FFF3EB→#FFDFCC，描边 .42）/ 更淡（#FCF7F2→#F5EDE6，描边 .30）
   · 关键：不放光晕、不放橙点。它不是 CategoryPresetArtView 的缩小版，
     缩到 84 宽后光晕会糊成一坨、橙点变成脏点。理由见 §5.6

3. Mine/Components/CategoryPresetArtView.swift
   · 仅一处改动：把 private struct PresetIconShape 提升为文件级可见，供 #2 复用
   · 绝对不要复制一份 path 定义——12 个图标的 path 必须只有一处真相
   · 该文件其余任何一行都不要动（hero 预设图已定稿）

4. 新增 Mine/Components/Tab2MomentRow.swift
   · 三种状态用一个 enum RowState 驱动（normal / spoken / wordsOnly），
     不要拆成三个 View——它们只差配色和主句位内容
   · 布局见 §5.2 的示意图与间距表
   · 行高 固定 100，主句区 固定两行高度（短句留白，长句省略号）。
     不要用「最多两行」——理由见 §5.2，多数真实句子都是两行
   · 模式判据完全复用 Tab2HeroCard.featuredMode，不要重写一套
   · meta 行：scene_detail 自适应 + 截断，「· +N more moments」用 layoutPriority(1) 永不截断
   · spoken 状态（§5.4）：缩略图饱和 .22 透明 .72，主句转 muted、字重 600→500，meta 前置 ✓
   · wordsOnly 状态（§5.5）：主句位改「词 + 释义」，**无衬线**，只放 preview_words 前 2 个；
     meta 位 No moment yet；整行透明度 .82；不显示 +N more moments；pops 照常显示
   · 照片处理：饱和 .65 + 暖橙 multiply .24，**不加暖纸 soft-light**。
     三个数是一起定的——soft-light 在 hero 上是提亮暗部，行内会喧宾夺主（§5.3）

不动：
  · MineView.swift（下一刀）
  · Tab2HomeViewModel.swift（上一刀）
  · Tab2HeroCard / HeroCollageView（已定稿）
  · Topics in progress 相关的 CategoryProgressRow 及其一切
  · 任何 SQL、任何 Edge Function、任何数据模型

完成标准 —— 在 Tab2MomentRow.swift 里写 #Preview 穷举并逐个目检：
  · 三种 RowState 各一行
  · 有照片 / 无照片（走 RowPresetThumb）
  · 主句：短句（1 行，下方留白）/ 正好两行 / 超长（两行 + 省略号）
  · scene_detail 超长 + 三位数 +N，确认「+999 more moments」完整未截
  · scene_detail 为 nil，确认 meta 行只剩 +N、无空位无多余分隔点
  · wordsOnly：preview_words 有 2 个 / 只有 1 个 / 为空（只剩 No moment yet）
  · 三行并排放一起，确认 spoken 和 wordsOnly 明显弱于 normal
项目编译通过，无新增 AppTheme token 违规。
```

---

## 第 3 刀 · 接线

```
读 docs/prd/Tab2_More列表_设计方案_v1.md 的 §3、§6、§7（只读这三节）。
遵守 CLAUDE.md 的全部硬约束。

前置：第 1、2 刀都已完成。

任务：把 More 列表接进 MineView.contentSections。

范围：仅 AIEnglishApp/Mine/MineView.swift 的 contentSections
  · hero 之后插入：Serif 小标题 "More to talk about" + Tab2MomentRow 列表
  · 数据来自 vm.moreCategories(excluding: milestoneIDs, hero: hero)
  · 每行整行可点 → onTalk(cat.sceneCategory)，与 hero 的 CTA 等价。**不要给行加按钮**
  · 行状态判定（哪一行是 normal / spoken / wordsOnly）放在这里算，
    依据同 §4 的分组条件；不要把 UserDefaults 读取塞进行组件
  · 间距：hero → 标题用 Space.paddingBetweenSections；
          标题 → 首行用 Space.paddingCard；
          末行 → Topics in progress 用 Space.paddingBetweenSections
  · 行左右边距与 hero 卡对齐（Space.paddingPage），在同一根轴上
  · 列表不套 .surfaceCard()——那是 Topics in progress 的容器形态，两区要能分开

边界（§6）：
  · moreCategories 返回空时，标题与列表**整块不渲染**，hero 下面直接是 Topics in progress。
    不要加占位、不要加空状态文案——本来就只有一件事可聊，不假装有选择

不动（重要）：
  · contentSections 里 Topics in progress 那一整段：Serif 标题、CategoryProgressRow、
    surfaceCard 容器、手风琴 toggleExpand、milestone 相关逻辑——一行都不要改。
    它和新增的 More 区在同一个函数里，注意不要顺手「统一」两者的样式
  · hero 那段（Tab2HeroCard 的调用与 padding）
  · Tab2MomentRow / RowPresetThumb（上一刀已定稿）
  · Tab2HomeViewModel（上一刀已定稿）
  · 任何 SQL、Edge Function、数据模型

完成标准：
  · 真机：多分类时 hero 下出现 More 列表；只有 1 个已解锁分类时整块消失，
    hero 下直接是 Topics in progress
  · 真机：点任意一行进入对话页，与点 hero 的 CTA 行为一致
  · 真机：Topics in progress 的展开/收起、进度条、milestone 表现与改动前完全一致
  · 目检：hero → 标题 → 列表读作一块（间距 34 : 16），列表 → Topics in progress
    之间的 34 明显更宽
  · 项目编译通过
```

---

## 执行顺序

```
第 1 刀（ViewModel）  ─┐
                      ├─→ 第 3 刀（接线）
第 2 刀（组件）       ─┘
```

第 1、2 刀无依赖，可并行开两个会话。

## 上线前必做

规格文档 §5.2 那句 SQL 跑一次，确认主句长度分布。
「固定两行」这个决定的唯一依据是「长句占多数」，而该判断来自 5 条截图样本，样本太小。
若「1 行以内（≤28 字符）」占比 >15%，或「两行仍截断（>56 字符）」>30%，回到规格文档重新评估。

---

## 第 4 刀 · 行排版减重

> 目标是把 More 列表从「一堵墙」改成「两个声部」。本刀只调排版，不动结构、字段、逻辑。

```
读 docs/prd/Tab2_More列表_设计方案_v1.md 的 §5（只读这一节），
以及 CLAUDE.md 里关于 AppTheme.Font token 与 Dynamic Type 的那条硬约束。

【要解决的问题】
More 列表五行连排显得拥挤。病因不是「主句太重」，而是一张卡片里有四个各说各话的声部：
分类标签是全大写加大字距的强调手势，pops 淡到几乎看不见，meta 又是另一档字重，
主句则是全卡唯一的深色。中间没有过渡，主句只好独自撑起整张卡。

【要做成什么样】
一张卡片里只有两个声部：

  内容    —— 主句。全卡唯一的深色，是用户判断「点不点这一行」的依据
  元数据  —— 分类标签、pops、meta 三者。写法完全相同，读作同一档

具体呈现：

· 主句：衬线，比 hero 卡的主句小一档字号、轻一档字重。
  hero 主句是 .body 衬线 semibold，这里就是 .subheadline 衬线 regular。
  颜色仍是 textPrimary——不要降色，降了五行扫下来会失去落点。
  仍是固定两行：短句下方留白，长句两行加省略号。

· 元数据三者：.caption regular，textMuted，字距回归常规。
  三者统一之后，不要再给其中任何一个单独加粗、改色或改字号。
  分类标签改成句首大写（Work & study），不再全大写。
  这是有意与 hero 拉开——hero 卡上仍是全大写，同一个字段越靠近推荐位越响。

· 行高约 104，但用 minHeight 而不是固定高度：默认字号下每行正好是这个高度，
  用户调大系统字号时行要能长高，不能裁字。

· 缩略图宽 76，照片填满整个行高。阴影比 hero 轻两档。

【验收标准】
· 五行真实长度的数据排在一起，不再像一堵墙
· 分类、pops、meta 三者读作同一档，没有哪一个跳出来
· 主句仍是一眼能落到的焦点，没有被削弱
· 把系统字号调到最大，行长高、文字不裁

【不要碰】
· hero 卡的任何一处（Tab2HeroCard / CategoryPresetArtView / HeroCollageView）
· Topics in progress
· 选取逻辑、字段、行的结构与层级顺序
· 任何 SQL、Edge Function、数据模型

【硬约束】
所有字号必须走 AppTheme.Font token 的语义档位（.body / .subheadline / .caption …），
不得在组件里写 .system(size:) 磅值——这条 CLAUDE.md 里是明令禁止的，
项目里所有字号都靠语义档位保住 Dynamic Type。
需要新档位就在 AppTheme.Font 里加，不要在视图里硬写。
```
