# Tab2 探索区与待解锁态重构 · 需求与前端改动规格 (v1)

> **文档定位**：本文件为 Tab2（Library / 练习与成长）待解锁态视觉重构，以及“未开启生活分类探索区”（`More topics to explore`）在解锁前、解锁后贯穿落地的权威产品与前端设计改动规格说明书。  
> **上级权威依据**：`docs/prd/整体架构_两个Tab与对话页_v1.md`、`docs/prd/Agent内容组织与成长系统_PRD_v2.md`。

---

## 一、需求背景与业务目标

### 1.1 现状痛点
1. **标题层级冗余且解锁前后断层**：
   - 现网待解锁态顶部套了一层 `Not open yet` 大标题及副标题，其下方才是 `Topics in progress` 进行中卡片；
   - 而解锁后页面直接以 `Talk about today`、`Topics in progress` 为一级标题，**根本不存在 `Not open yet` 这一层级**，导致用户达到 20 词解锁时页面框架发生突兀跳变。
2. **早期用户生活图景感知缺失**：
   - 新用户刚产生 1~2 个词汇时（例如拍了工作电脑，仅有 `Digital & Tech 1/20`），整屏只有孤零零的一张卡片，其余 10 个生活分类完全不可见；
   - 用户无法感知 App 具备丰富的生活场景体系，不知道咖啡、通勤、购物等也能自动归类，削弱了持续拍照探索的意愿。
3. **解锁后未开启分类被遗忘**：
   - 当用户第一个主题解锁后，视图聚焦在已解锁卡片，但尚未涉足的生活主题（`wordCount == 0`）没有出口，全生活维度的探索引导断链。

### 1.2 核心改造原则
1. **双一级标题对齐，大标绝无副标**：
   - 彻底废除 `Not open yet` 顶层外壳，将 `Topics in progress` 扶正为一级大标题（22pt Charter Bold）；
   - 新增平级区块标题 `More topics to explore`（22pt Charter Bold）；
   - 两个大标题均保持极简纯净，不设置任何副标，契约完全对齐解锁后风格。
2. **贯穿全生命周期的全生活探索区**：
   - 无论**解锁前（待解锁态）**还是**解锁后**，只要用户存在词数为 0 的生活主题，统一在 `More topics to explore` 区域展示，展现完整生活版图。
3. **克制高级的中性灰自然字长标签**：
   - 严禁使用任何高饱和橙色背景方框；统一采用纸白/中性浅灰胶囊；
   - 标签宽度严格随文字实际长短自适应（`max-content`），绝不人为拉伸或压扁。

---

## 二、页面结构与终版文案规范

### 2.1 待解锁态（Locked State）垂直视口结构
页面自上而下包含以下三个部分：

```text
┌──────────────────────────────────────────────┐
│  [顶栏：Today | Library 胶囊切页 + 汉堡按钮]   │
├──────────────────────────────────────────────┤
│                                              │
│  Topics in progress (22pt 衬线大标)          │
│  ┌────────────────────────────────────────┐  │
│  │ 💻 Digital & Tech       1 / 20 words ▾ │  │
│  │ [========                            ] │  │
│  └────────────────────────────────────────┘  │
│  Any topic with 20 words unlocks speaking.   │
│  (注脚 1 · 11pt 微缩轻注脚 · 客观无命令腔)      │
│                                              │
│  More topics to explore (22pt 衬线大标)      │
│  ┌── 3 + 1 非对称节奏标签流 ───────────────┐ │
│  │ [🌅 Daily Routine] [💼 Work] [☕️ Food]  │ │
│  │ [🛍️ Shopping]                           │ │
│  └─────────────────────────────────────────┘ │
│  Moments you capture will automatically      │
│  sort into these life themes.                │
│  (注脚 2 · 11pt 微缩轻注脚 · 生活主题承诺)      │
│                                              │
├──────────────────────────────────────────────┤
│  [📷 Capture something] (常驻底部黑胶囊)     │
└──────────────────────────────────────────────┘
```

### 2.2 终版文案与排版全量清单

| 位置 | 英文文案内容 | 字体 Token | 颜色 Token | 间距与排版说明 |
| :--- | :--- | :--- | :--- | :--- |
| **区块 1 标题** | `Topics in progress` | `AppTheme.Font.sectionTitleSerif` (22pt Charter Bold) | `AppTheme.Color.textPrimary` | 下边距 12pt，纯大标无副标 |
| **卡片下方注脚 1** | `Any topic with 20 words unlocks speaking.` | `AppTheme.Font.metaNote` (11pt Gothic A1 Regular) | `AppTheme.Color.textMuted` (`#8A8079`) | 上边距 8pt，下边距 28pt，行高 1.35 |
| **区块 2 标题** | `More topics to explore` | `AppTheme.Font.sectionTitleSerif` (22pt Charter Bold) | `AppTheme.Color.textPrimary` | 下边距 16pt（全 13pt 呼吸韵律），纯大标无副标 |
| **探索标签文字** | 官方生活分类名 (如 `Daily Routine`) | `AppTheme.Font.tab2ExploreTagLabel` (13pt Gothic A1 Regular) | `AppTheme.Tab2ExploreTopics.Color.tagLabel` | 高 30pt，左右内边距 13pt，图标 13.5pt，自然字宽 |
| **标签下方注脚 2** | `Moments you capture will automatically sort into these life themes.` | `AppTheme.Font.metaNote` (11pt Gothic A1 Regular) | `AppTheme.Color.textMuted` (`#8A8079`) | 上边距 10pt，行高 1.35，静谧留白 |
| **常驻底部按钮** | `Capture something` | `AppTheme.Font.ctaLabel` (15pt Gothic A1 SemiBold) | `#FFFFFF` | 高 52pt 黑胶囊，常驻底部安全区 |

> **文案价值说明**：
> - **注脚 1（1C 方案）**：彻底摆脱了 `Reach...` 动词给用户的“发号施令/布置作业感”，以客观事实陈述“任何达到20词的主题都将解锁speaking”，纯正自然且完全消除跨分类凑词的歧义。
> - **注脚 2（原版生活主题文案）**：明确生活主题（life themes）的归类价值，向用户承诺 AI 自动分类，自然承接底部拍摄记录。
> - **微缩字号（11pt metaNote）**：视觉表现收敛至杂志页脚般的微弱批注，呼吸感倍增，绝不抢占卡片主体视线。

---

## 三、`More topics to explore` 标签自适应排布规则

根据用户剩余未开启（`wordCount == 0`）的主题数量 $N$，布局严格执行自适应流转：

```text
       ┌────────── 未开启分类数量 N ──────────┐
       │                 │                   │
    N >= 5             N = 4               N <= 3
       │                 │                   │
       ▼                 ▼                   ▼
[两排并列横滑流]     [3 + 1 非对称节奏]    [单排靠左自然摆放]
2 行 × 动态列横滑     第一排 3 个标签       N=3: 单排 3 个自然标签靠左
自然字宽，无拉伸     第二排 1 个靠左       N=2: 单排 2 个自然标签靠左
右侧微露渐隐提示     单滚动容器联动        N=1: 单排 1 个自然标签靠左
                                          (右侧正常留白，绝不撑满整行！)
                                          N=0: 整块自然隐藏 (0 渲染)
```

1. **$N \ge 5$（初期阶段）**：
   - 采用 2 行并排横滑容器，行高 38pt，间距 8pt；右侧自然微露，支持横向滑动。
2. **$N = 4$（重点定案态 · 3 + 1 非对称节奏）**：
   - 第一排展示 3 个标签，第二排展示 1 个标签靠左；
   - 采用**单一水平滚动容器包裹联动**，手势一致，呈现手账便签般自然错落的编辑风韵律。
3. **$N \le 3$（进阶阶段 · 核心规范）**：
   - 退化为单排（1 行）横滑容器；
   - **靠左自然摆放**：每个标签严格保持自身字长宽度，右侧自然大面积留白；
   - ❌ 严禁等分 50% 或拉伸 100% 撑满整行。
4. **$N = 0$（全部主题已触碰）**：
   - 整个 `More topics to explore` 标题、标签及注脚 2 **彻底隐藏（0 渲染）**。

---

## 四、前端核心改动清单 (Frontend Changes)

无需后端变更或新设接口，前端在现有架构上做 3 处清晰聚焦的改造：

### 改动 1：新建独立组件 `Tab2MoreTopicsSection.swift`
- **新建文件**：`AIEnglishApp/Mine/Components/Tab2MoreTopicsSection.swift`
- **组件职责**：
  1. 封装 `More topics to explore` 标题（`sectionTitleSerif` 22pt Bold）；
  2. 内部包含标签排布容器：
     - 当传入未开启主题数量 $\ge 5$ 时：渲染双排网格；
     - 当数量 $= 4$ 时：渲染 `3 + 1` 联动结构；
     - 当数量 $\le 3$ 时：渲染单排靠左结构；
     - 当数量 $= 0$ 时：渲染 `EmptyView()`；
  3. 标签组件（`NeutralTopicTag`）统一使用白底中性边框微胶囊，保持自然字宽；
  4. 标签下方渲染微缩注脚 2：`Moments you capture will automatically sort into these life themes.`（11pt `metaNote`，`textMuted`）。

### 改动 2：重构待解锁态视图 `Tab2LockedView`
- **修改文件**：`AIEnglishApp/Mine/MineView.swift` 中的 `Tab2LockedView`
- **具体改动**：
  1. **移除旧外壳**：彻底删去原有的 `headerSection`（包含 `Not open yet` 大标题及副标题）；
  2. **扶正一级标题**：将进行中区域顶部设置为 `Topics in progress` 衬线大标；
  3. **挂载注脚 1**：在进行中卡片下方挂载微缩轻注脚：`Any topic with 20 words unlocks speaking.`（11pt `metaNote`，`textMuted`）；
  4. **挂载探索区**：在注脚 1 下方直接调用 `Tab2MoreTopicsSection(unstartedTopics: unstartedCategories)`；
  5. 底部维持现有的常驻 `[📷 Capture something]` 按钮及毛玻璃安全区。

### 改动 3：挂载已解锁态视图 `Tab2UnlockedView`
- **修改文件**：`AIEnglishApp/Mine/MineView.swift` 中的 `Tab2UnlockedView`
- **具体改动**：
  1. 在现有已解锁页面的最底部（原 `Topics in progress` 区域下方）追加调用 `Tab2MoreTopicsSection`；
  2. 传入当前词数为 0 的分类；若用户全部分类均已开启，组件自动隐藏；
  3. 完美承接最底部的页面暖光底托（`BottomAuraFooter`）。
