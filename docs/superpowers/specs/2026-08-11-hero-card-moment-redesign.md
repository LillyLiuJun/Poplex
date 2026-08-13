# Hero Card Moment 分类展示重设计

> 状态：设计稿 · 待评审 · 2026-08-11
> 范围：Tab2 已解锁 Hero 卡（`Tab2HeroCard`）与分类卡（`Tab2CategoryRow`）的 moment 引文行重设计

## 一、现状与问题

### 1.1 当前逻辑

Hero 卡和分类卡取该分类下 **频次最高的 3 个子场景**（按 `occurrence_count DESC`），
每条子场景从 `lexicon_occurrences` 中取该 `scene_detail` 下最新一条 `user_original`（≥6 字），
一行 `"` 引号 + `lineLimit(1)` 截断。多于 3 条追加「+N more moments」。

### 1.2 问题

1. **所有 moment 无差别加引号**：有图、有原话、纯场景名——统一一个 `"` 衬线引号。无法展示内容的丰富度差异。
2. **不展示场景标签**：只露一句原话，用户看到的是一句孤立的引用，缺少场景语境（如「通勤」「做饭」）。
3. **不展示频次**：频次是「触动用户」的核心信号（这个是你说过最多的话题），但卡面上完全看不到。
4. **引号刷屏，视觉单调**：三行引号排在一起，像三句语录罗列，没有信息层级，也没有"人味"。
5. **卡面整体「小家子气」**：固定 335×295 框架、橙色胶囊 Badge 居顶、引号雷同，缺乏 Topics in Progress 那种「高级与克制」——干净的排版层级、Serif 标题、通透玻璃质感。

### 1.3 参照：Topics in Progress 的设计语言

- `.warmGlassCard()` 磨砂玻璃容器，柔和不闷
- `sectionTitleSerif` / `pageTitleSerif` Serif 字体建立层级
- Category badge：`symbolVariant(.fill)` SF Symbol，0.42 不透明度——存在但不叫嚷
- PopsPill 词数胶囊——信息克制的表达
- 2.5px 极轻进度条——一个元素只做一件事，做到刚好
- 排版节奏：宽裕的 padding、行间呼吸

Hero 卡的目标是把这套克制感平移过来，同时利用 **图片缩略图 + 场景标签 + 频次** 让 moment 的信息密度和"人味"都翻倍。

---

## 二、Moment 分类逻辑

### 2.1 两种类型

moment = 一个子场景（scene_detail）。判定类型只看 `imageUrl`：

| 类型 | 判定条件 | 含义 |
|---|---|---|
| **Photo Moment** | `imageUrl != null` | 用户拍照输入。图是场景的视觉证据，最丰富、最有"人味" |
| **Text Moment** | `imageUrl == null` | 纯文字输入（sentence / passage）。sentence 与 passage 暂不区分 icon，共用一类 |

sentence vs passage 的细分留到后端 RPC 暴露 `granularity` 后再做。本次不改 RPC。

### 2.2 Icon 规则（这个位置我的想法是不一定要用icon，如果大气一点可以直接用图片，不过下面是用icon写的示例吧）

| 类型 | Icon | 说明 |
|---|---|---|
| Photo Moment | **真实缩略图** 32×32 | 复用 `CachedRemoteImage`，降饱和 + 暖纸蒙版（与 `WordEntryRow` 中图标的处理一致），圆角 8px |
| Text Moment | **场景类别 SF Symbol**，`symbolVariant(.fill)` | 映射规则同 `SceneCategory.iconName`，0.42 不透明度（与 `CategoryProgressRow.categoryBadge` 一致），色用 `textPrimary` |

Text Moment 的 category→icon 映射：

| scene_category | SF Symbol |
|---|---|
| 工作与学业 | `briefcase` |
| 家庭与人际 | `house` |
| 日常起居 | `bed.double` |
| 饮食 | `fork.knife` |
| 出行交通 | `car` |
| 运动健康 | `figure.run` |
| 休闲娱乐 | `tv` |
| 购物消费 | `bag` |
| 科技数码 | `laptopcomputer` |
| 天气环境 | `cloud.sun` |
| 情绪社交 | `bubble.left.and.bubble.right` |
| 其他 | `tag` |

### 2.3 何时没有 moment

- 分类下没有合格子场景（`scene_detail IS NULL` 或子场景全部不合格）→ 退回展示 `previewWords`（现有兜底，不变）
- 合格条件：**仅 `scene_detail IS NOT NULL`**。只要后端给出了场景标签，不管 quote 多短或为空，都作为一条 moment 展示

---

## 三、展示规则

### 3.1 每条 moment 行 = 两行内容

每行 moment（无论 Photo / Text）固定两行布局：

```
Line 1: [Icon 32×32]  Scene Label     (+N if > 1)
Line 2:                 Content
```

其中：

- **Line 1 · Scene Label**：`scene_detail` **使用目标语言**（MVP 目标语言是英语，所以场景标签应为英文。原则上不硬编码语言——但当前 MVP 目标语言还未做成动态配置，prompt 直接写死 target=English）。如果 `scene_detail` 本身已是目标语言格式（后端改 prompt 后），直接用；兜底方案为前端映射表（详见 §五）。
- **Line 1 · Frequency**：`occurrenceCount > 1` 时才展示「+N」，柔和灰色小字，挂在 Line 1 右侧。`count == 1` 不展示（1 是默认，不叫频次）。
- **Line 2 · Content**：
  - **Photo Moment**：展示 `quote`（用户原话）。若 quote 为空：Line 2 省略，行高自然收缩。
  - **Text Moment**：展示 `quote`（用户原话），`lineLimit(1)` 单行截断。若 quote 为空：退回用 `sceneDetail`。

注意：**两行布局是固定的（排版结构），与是否展示频次无关**。频次是 Line 1 的附加信息字段。

### 3.2 取数与排序

**后端不变**（复用 `get_tab2_home` RPC 现有 `sub_scenes`）。

- 排序：`occurrenceCount DESC`（不变）
- 展示前 3 条；剩余 →「+N more moments」（不变）

### 3.3 纯查词分类兜底

无合格子场景时退回展示 `previewWords`，`·` 分隔，不带引号，`lineLimit(2)`（不变）。

---

## 四、Card 整体视觉重设计方向

目标：把 Hero 卡从"小家子气"拉到 Topics in Progress 的"高级与克制"。

### 4.1 原则

1. **Show, don't decorate**：图片本身就是装饰，原话本身就是情感。少加引号、胶囊、阴影。
2. **Typography as hierarchy**：Serif 承载"人说的话"，system 承载元信息。字体本身区分层级。
3. **Breathing room**：卡内 padding 宽裕，内容不必撑满 295pt 高度。
4. **Warm restraint**：品牌橙保留但只作微点缀（如频次 badge / 类别小点），大面积走暖中性。

### 4.2 布局草案

```
┌──────────────────────────────────┐
│  [Scene Category SF Symbol]      │  ← 类别图标 + 分类名（替代现有橙色胶囊）
│  WORK                            │
│                                  │
│  ┌──────┐                        │
│  │ 📷   │  Commuting      +3    │  ← Photo Moment
│  │ photo│  "今天地铁好挤..."      │
│  └──────┘                        │
│                                  │
│  [🏠]    Cooking          +5    │  ← Text Moment（带 category icon）
│          "今晚做了红烧排骨"        │
│                                  │
│  [💼]    Meeting                  │  ← Text Moment（频次=1，不显 +N）
│          "Q3 target is..."       │
│                                  │
│  +2 more moments                 │  ← 溢出提示
│                                  │
│  ──────────────────────────────  │
│  [mic]  Start talking            │  ← CTA（克制版）
└──────────────────────────────────┘
```

### 4.3 与现有卡的关键差异

| | 现状 | 重设计 |
|---|---|---|
| 卡高 | 固定 295pt | 自适应内容 |
| 分类标头 | 橙色胶囊 badge | 细线 icon + 分类名 |
| Icon | 所有行统一 `"` | Photo = 缩略图；Text = 场景图标 |
| 场景标签 | 无 | 有（目标语言） |
| 频次 | 无 | Line 1 右侧 +N（>1 时） |
| CTA | 深色实心胶囊、带阴影 | 克制刷新（待定，优先保留现有但减弱） |
| 整体氛围 | 引号刷屏、橙色突出 | 暖中性克制、内容自述 |

### 4.4 复用与提取

`Tab2HeroCard` 与 `Tab2CategoryRow` 目前各有一套 `QuoteRow` / `quoteSection` / `goodScenes`——两处**代码几乎完全相同**。本次重设计将提取以下共用：

- `MomentRow`：单条 moment 行组件（含两行布局、icon 分派、频次展示）
- `MomentList`：moment 列表 + 兜底 logic

---

## 五、Scene Label 目标语言方案

### 5.1 原则

场景标签使用目标语言展示（不硬编码英文）。当前 MVP 目标语言 = English。

### 5.2 实施方案

**首选（后端 prompt 改）：** 修改 `classifyScene` prompt，要求 `sub_scene` 用目标语言输出。

改前（中文标签）：
```
sub_scene: "做饭"
```

改后（英文标签）：
```
sub_scene: "Cooking"
```

prompt 改动：在 `supabase/functions/generate/index.ts` 的 `classifyScene` 函数 prompt 中加入 `"sub_scene should be in English"` 约束。当前目标语言是硬编码的（MVP），后续换目标语言时此处需同步改为动态参数。

**兜底（前端映射表）：** 若 prompt 改造后存量数据仍含中文标签，前端在 `SceneCategory` 或新建一个 `SceneDetailLabel` 映射表中做中→目标语言转换。这是兜底，不依赖。

### 5.3 历史数据处理（目前没有历史数据）

prompt 改造后，只有**新增材料**的 `scene_detail` 会是英文。存量中文 `scene_detail`：
- 不改历史数据（避免数据迁移）
- 前端兜底映射表覆盖最常见的中文标签
- 无法映射的保留原文展示

---

## 六、数据需求

### 6.1 前端

- `Tab2SubScene` 现有字段足够（`sceneDetail`、`quote`、`imageUrl`、`occurrenceCount`）
- 需新增 `SceneCategory` 的 `iconName` 属性（如不存在）供 Text Moment 取 category icon
- Photo Moment 的缩略图渲染复用 `CachedRemoteImage`

### 6.2 后端

| 改动 | 文件 | 说明 |
|---|---|---|
| `classifyScene` prompt 改 | `supabase/functions/generate/index.ts` | `sub_scene` 改为英文输出 |
| （暂不做）RPC 暴露 granularity | `20260804000000` 迁移 | sentence / passage 细分延后至此 |

---

## 七、范围与边界

### 本次做

1. ✅ 两类型 moment 分类（Photo / Text）
2. ✅ Icon 分派：缩略图 vs 场景图标
3. ✅ 两行布局：Scene Label + Content
4. ✅ 频次展示（>1 时 Line 1 右侧 +N）
5. ✅ Scene label 目标语言（改 prompt + 前端兜底映射）
6. ✅ 卡面整体重设计（排版、间距、自适应高度）
7. ✅ 提取共用 `MomentRow` / `MomentList`
8. ✅ Hero 卡 & 分类卡同步改

### 本次不做

- ❌ sentence vs passage 细分 icon（待 granularity 入 RPC）
- ❌ 场景标签碎片化合并（独立 slice）
- ❌ passage 段落截取优化（独立 slice）
- ❌ 对话功能上下线逻辑（FeatureFlags 现有逻辑不变）
- ❌ RLS / 权限变更
