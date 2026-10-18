# Tab2 首页 · 实现规范 v1（切片 B）

> **本文只管"怎么建"**。为什么这么定，见 `Tab2_练习入口与信息架构_设计方案_v2.md`（下称"设计方案"）。
> 冲突时以设计方案为准；与代码冲突时**代码是事实**，改文档并说明。
> 硬约束一律遵守 `CLAUDE.md`：iOS 17+ / `NavigationStack` / `@Observable` / 所有颜色字号走 `AppTheme` token / **所有产品 UI 文案为英文**。

---

## 一、范围

| 在本切片 | 不在本切片 |
|---|---|
| Tab2 首页两个状态（待解锁 / 已解锁） | 对话页本身 |
| 解锁判定 | `Your words` 界面、词详情 |
| 分类卡、进度、可展开词表 | 场景页（已取消，见设计方案拍板 8） |
| 进入对话页的转场 | 成长层 |

**前置依赖**（不满足则本切片做出来是空壳）：

1. 分类判定作业上线（否则 `scene_category` 全是「其他」）
2. `scene_detail`（子场景）落地
3. 词卡也判分类（设计方案 §1.05-3）
4. 长文 `sample_sentence` 修复（设计方案 §8.2）

---

## 二、状态机

```
              ┌─ 不满足 ──→ 【待解锁态】
解锁判定 ─────┤
              └─ 满足 ────→ 【已解锁态】（永不回退）
```

### 2.1 解锁判定

> ⚠️ **过期提示（2026-10-18）**：下表条件 2（Tab1 累计 ≥5 次输入）已于 2026-08-04 移除，现行规则只看条件 1（任一分类 ≥20 词）。依据：迁移 `20260804000000_tab2_unlock_words_only.sql` 与最新 `get_tab2_home`（v6：`v_unlocked := (v_max_words >= 20)`）。以代码为准。

**两个条件都满足即解锁（已过期，见上）：**

| # | 条件 | 口径 |
|---|---|---|
| 1 | **某单个分类下 ≥20 个有效词汇** | 去重 `lexicon_entries`（同 lemma 算一次）、`status='active'`、按其 occurrences 的 `scene_category` 归属。查词来的词条**计入**；`scene_category` 为 null 的**不计入任何分类** |
| 2 | **Tab1 累计 ≥5 次输入** | 所有输入类型都算，含查词卡 |

- **数据来源**：条件 1 复用现有 `get_lexicon_scenes`（已是 `COUNT(DISTINCT entry_id) GROUP BY scene_category` 且已过滤 active）。
- **永不回锁**：一旦解锁，即使用户删素材导致条件不再满足，也保持解锁。本地持久化一个 `tab2_unlocked` 标记，判定只做「未解锁 → 解锁」的单向跃迁。
- **分类各自解锁**：解锁不是一次性事件。达标的分类进卡片区，未达标的进「Still filling up」。

---

## 三、待解锁态

### 3.1 版面

```
┌─────────────────────────────────┐
│  [头像]              [Today|Mine]│
│                                 │
│  Almost there                   │  标题
│  Talking works once one area    │  说明（把原因归给产品）
│  has enough of your own         │
│  material. One more thing       │  ← 这句由数据算出
│  about work and it opens.       │
│                                 │
│  INPUTS                  4 of 5 │  ← 全局条件，一条
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░           │
│                                 │
│  AREAS      （任一满 20 即可）    │  ← 分类条件，每类一条
│  Work & study          14 of 20 │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░░  ⌄       │
│  set up · run late · agenda ·+11│
│                                 │
│  Food                   6 of 20 │
│  ▓▓▓▓▓░░░░░░░░░░░░░░░   ⌄       │
│  marinate · simmer · +4         │
│                                 │
│  [ 📷  Capture something ]      │
│  Takes you to Today             │
└─────────────────────────────────┘
```

### 3.2 元素规范

| 元素 | 取数 | 规则 |
|---|---|---|
| 标题 | 固定 | `Almost there` |
| 说明句 | 计算 | 指出**最接近达标的那个分类**：`One more thing about {category} and it opens.` |
| INPUTS 条 | Tab1 输入总数 / 5 | 满 5 后仍显示但置灰打勾，**不隐藏**（否则用户以为条件变了） |
| AREAS 条 | 每分类词数 / 20 | **最接近的那条用 `brandStrong`，其余用中性灰** |
| 预览词 | 该分类**最近入账**的 3 个 + `+N` | 收起态显示 |
| 展开态 | 该分类**全部**词条 | 见 3.3 |
| CTA | 固定 | `Capture something` → 切到 Tab1；副文案 `Takes you to Today` |

**分类条的显示范围**：词数 ≥1 的分类才显示。**0 词的分类不渲染**（12 类里大多数对某用户是空的，全列出来是噪音）。

### 3.3 分类展开（就地展开，不跳页）

点分类行 → 展开该分类**全部**词条：

```
Work & study                     14 of 20   ⌃
  set up          phr.   [icon] I need to set up the meeting room…
  run late        phr.   [img]  I'm going to run late again.
  invoice                [icon] looked up
  …全部 14 个
```

| 列 | 取数 |
|---|---|
| 词 | `lexicon_entries.display_form ?? lemma` |
| 类型缩写 | `entry_kind` → 已有映射 `LexiconEntry.kindAbbrev`；为 `word` 时显示 `pos`，都没有则不显示 |
| 左槽图标 | 见 3.4 |
| 右侧说明 | `lexicon_occurrences.sample_sentence`，见 3.5 |

**边界**：这**不是**提前做 `Your words`——只读、不排序、不筛选、不进详情页。它只回答"这 14 个是哪 14 个"。

### 3.4 左槽图标（granularity 单轴 + 一个例外）

| 值 | 含义 |
|---|---|
| `word` | 查词 |
| `sentence` | 一句话素材 |
| `passage` | 长文素材 |
| `dialogue` | **例外**：属 `source_type` 不属 `granularity`。因 §7.1 用"说出来"定义用户输出，值得单列。**这是有意破轴，不要"修正"它** |

**有图时用缩略图顶替图标**（该 occurrence 的来源 message 有 `image_url`）。

### 3.5 右侧说明文字

取 `lexicon_occurrences.sample_sentence`（已在流水行上，**不用 join `materials`**）。

| 来源 | 显示 |
|---|---|
| `word`（查词） | `looked up` |
| `sentence` | `sample_sentence`，截断 |
| `passage` | `sample_sentence`，截断（**前提是缺口 7 已修**，否则是整篇文章） |
| `dialogue` | `sample_sentence`（他实际说的那句），截断 |
| `sample_sentence` 为空 | 只留图标；图标也没有则整个说明不渲染 |

**截断规则**（必须有：prompt 定义 sentence 上限为 **300 字符**）：单行、全角约 18 字 / 拉丁约 30 字、尾部省略号、**优先在标点处断**。

---

## 四、已解锁态

### 4.1 版面

```
┌─────────────────────────────────┐
│  [头像]              [Today|Mine]│
│                                 │
│  Talk about something           │  ← 标题，无副标题
│                                 │
│  ┌───────── hero（橙）────────┐  │
│  │ WORK & STUDY              │  │
│  │ [图] "我得在九点前把会议室…"│  │
│  │ [图] "又要开会了，一天三个" │  │
│  │ [ico] "这个文档还没写完"    │  │
│  │ +5 more                   │  │
│  │ [ 🎤  Start talking ]     │  │
│  └───────────────────────────┘  │
│                                 │
│  ┌──── 其余已解锁分类 ───────┐   │
│  │ Food                     │   │
│  │ Making dinner · +2  [Talk]│  │
│  ├──────────────────────────┤   │
│  │ Getting around           │   │
│  │ Commuting          [Talk]│   │
│  └──────────────────────────┘   │
│                                 │
│  STILL FILLING UP               │
│  Home & people        11 of 20  │
│  ▓▓▓▓▓▓▓▓▓▓░░░░░░░░░            │
└─────────────────────────────────┘
```

**无副标题**（设计方案：副标既不解释交互也不驱动决策，删除）。

### 4.2 hero 卡

#### 选取规则

```
候选 = 最近有新素材的已解锁分类
若该候选凑不出 2 句引文（子场景 <2 或可用原话 <2）
   → 改用词数最多的已解锁分类
```

#### 内容（只有四样）

| 元素 | 取数 | 规则 |
|---|---|---|
| 分类名 | `scene_category` → 英文映射 | 小字全大写标签 |
| **引文行 ×1–3** | 每个子场景取一句 `raw_content.user_original` | 见下 |
| `+N more` | 该分类剩余子场景数 | **只有 1 个子场景时整行不显示** |
| CTA | 固定 | `Start talking` |

**没有**：词数、子场景名列表、AI 生成的句子、进度条。

#### 引文行规则

1. **每个子场景只取一句**，避免三句来自同一件事。
2. **按子场景出现次数排**，取前 3。
3. **太短的跳过**：低于 6 个字（如「好累」）无信息量，取该子场景的下一条；仍不够则该子场景不出行。
4. **纯照片输入没有 `user_original`** → 该行退回显示子场景名。
5. **左槽**：该时刻有图 → 缩略图（46×34）；无图 → granularity 图标。**槽位永不为空，引文左边缘始终对齐**。
6. 零图的分类：整列仍保留图标，**不塌成纯文字列表**。

#### 首次解锁专属

首次解锁时，hero 卡在分类名下方多一行：

> `You've got enough here to talk about it now.`

- **说能力，不说奖励。** 不用 `Unlocked!` / `You earned it` / 任何计分口吻。
- **只出现这一次**，之后恢复常规版式。

### 4.3 非 hero 分类行

| 元素 | 取数 |
|---|---|
| 分类名 | 英文映射 |
| 描述行 | **子场景名**（按出现次数取前 2 + `+N`）。子场景标签**用目标语言生成**（`Making dinner` / `Commuting`） |
| CTA | 描边胶囊 `Talk` |

**无引文、无图**——密度自适应：分类多时用户在领域间挑，不在领域内看。

**描述行降级**：子场景 → 时刻标题 → 词本身。

### 4.4 Still filling up 区

**与待解锁态的 AREAS 区是同一个组件**，只是降到底部、变灰、默认折叠。**实现上只做一个组件**，保证两处口径一致。

---

## 五、交互与动效

| 动作 | 行为 |
|---|---|
| 点 hero 卡任意位置 / 点 CTA | **同一个动作**：进对话页。卡片没有详情页这个去处——**不要给"点卡片"另配行为**，否则等于又造一个浏览目的地 |
| 点非 hero 行 / 其 `Talk` | 同上 |
| 转场 | **卡片展开成对话页**（共享元素），让人觉得是"这张卡打开了"而非"跳到了别处" |
| 点分类进度行 | 就地展开/收起词表 |
| 首次解锁 | 锁定态短暂可见 → 进度走满 → 锁图标淡出 → 第一张卡淡入上移落位。**一次性、≤0.6s、无粒子/彩带/音效**，用 `AppTheme.Motion` 现有 token。**不弹窗**。之后各分类达标时**不再播** |

---

## 六、必须实现的状态（`CLAUDE.md` 硬约束）

| 状态 | 处理 |
|---|---|
| Loading | 骨架屏，沿用 `SkeletonCardRow` 模式 |
| 空（0 素材） | **不会出现**——0 素材必然未解锁，走待解锁态 |
| 待解锁但 0 分类有词 | 待解锁态只显示 INPUTS 条 + CTA，AREAS 区整块不渲染 |
| 网络错误 · 有缓存 | 显示缓存 + toast `Couldn't update — showing saved content` |
| 网络错误 · 无缓存 | 错误态 + 重试，沿用现有 `ConnectionRetryView` |
| 麦克风权限被拒 | **归对话页**，不在本切片 |

---

## 七、数据接口

需要一个只读 RPC（暂命名）：

```
get_tab2_home(p_user_id uuid)
  → unlocked            boolean
    input_count         integer          -- Tab1 输入总数
    categories[]        -- 每个分类一条
      scene_category    text
      word_count        integer
      unlocked          boolean          -- word_count >= 20
      last_material_at  timestamptz      -- hero 选取用
      sub_scenes[]      -- 按出现次数降序
        scene_detail    text
        occurrence_count integer
        quote           text             -- user_original，可空
        image_url       text             -- 可空
      preview_words[]   -- 最近入账 3 个（待解锁态收起用）
```

展开词表可另起一个按需调用（避免首屏一次拉全量）：

```
get_category_words(p_user_id uuid, p_scene_category text)
  → words[] { lemma, display_form, entry_kind, pos, granularity, source_type, sample_sentence, image_url }
```

---

## 八、文案表（全英文）

| 位置 | 文案 |
|---|---|
| 待解锁标题 | `Almost there` |
| 待解锁说明 | `Talking works once one area has enough of your own material. One more thing about {category} and it opens.` |
| 分区标题 | `INPUTS` / `AREAS` / `STILL FILLING UP` |
| AREAS 注解 | `Any one reaching 20 opens it.` |
| 待解锁 CTA | `Capture something` + `Takes you to Today` |
| 已解锁标题 | `Talk about something` |
| hero CTA | `Start talking` |
| 非 hero CTA | `Talk` |
| 首次解锁句 | `You've got enough here to talk about it now.` |
| 更多 | `+{n} more` |
| 离线 toast | `Couldn't update — showing saved content` |

**中文只允许出现在一个地方**：hero 卡的引文（用户自己的原话）。它属于用户内容，不是产品文案。首屏因此是中英混排——**这是有意的**，两者性质不同（他的话 vs 我们的标签），混排把这个区别显示出来。

---

## 九、埋点

| 事件 | 属性 |
|---|---|
| `tab2_locked_viewed` | `input_count`, `top_category_word_count` |
| `tab2_unlocked_first_time` | `category`, `days_since_signup` |
| `tab2_category_expanded` | `category`, `word_count` |
| `tab2_chat_started` | `category`, `is_hero`, `sub_scene_count`, `quote_count` |

> **首屏卡片 → 进入对话的转化率**是本切片最该看的单指标。hero 先按"原话"做，把"子场景名"版留作对照组（设计方案 §2.4b 待验）。

---

## 十、未定项

| # | 问题 | 阻塞什么 |
|---|---|---|
| 1 | 12 个分类的英文映射文案（`工作与学业` → `Work & study`？） | 全页文案 |
| 2 | 12 个分类的锚点子场景例子（每类 4–8 个） | 子场景生成 prompt |
| 3 | 引文长度下限 6 字是否合适 | 引文行取句 |
| 4 | 缩略图圆角与尺寸是否新增 token | 设计 token 审计 |
