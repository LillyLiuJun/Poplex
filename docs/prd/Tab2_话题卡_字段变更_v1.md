# Tab2 话题卡 · 字段变更记录 v1

> 配套设计：卡面从「一句被随机挑中的话」改为「活动 ×次数 + 欠账 + 一句会变的理由」。
> 本文只记录**字段层**的变更：哪些废弃、哪些保留、哪些改名、哪些新增，以及图片与字段的关联规则。
> 不含 UI 尺寸与排版规格。

---

## 0. 一句话结论

**复活 `sub_scenes`，退休 `featured`。**

`featured` 的语义是「整个类别挑一条样本素材」，而点击契约是「聊整个类别」——用样本代表整体，是卡面所有问题的源头。
`sub_scenes` 的语义是「这个类别下的各个复现活动，每个带自己的次数和图」，与新卡面一一对应。

注意方向：`get_tab2_home` 第 2 刀（20260812020000）曾用 `featured` 替代 `sub_scenes`，
migration 里 `sub_scenes` 标注为「旧结构，§9.5 并行保留；前端切新字段后的清理刀再删」。
**本次变更取消那次清理，反向执行。**

---

## 1. 字段变更总表

### 1.1 废弃（RPC 与客户端模型都删）

| 字段 | 当前来源 | 废弃理由 |
|---|---|---|
| `featured` **整个对象** | `featured` CTE | 语义错误：单条样本代表整类。其下字段的去向见 §1.4 |
| `featured.target_expression` | `passage_lines[0].en` ?? `target_expression` | 卡面那句失控的话。纯照片输入时它是 AI 对图片的**描述**，不是可说出口的话 |
| `featured.user_original` | `materials.raw_content` | 卡面不再展示句子 |
| `featured.native_meaning` | `passage_lines[0].zh` ?? `native_meaning` | 卡面全英文，中文只留在聊天页与词条详情 |
| `featured.input_lang` / `source_direction` / `source_granularity` | `lexicon_occurrences` | 只服务 `featured` 的选取排序；`featured` 退休后客户端无消费者 |
| `featured.spoken_count` | `lexicon_entries.spoken_count` | 单个词的说出次数，粒度错。改用类别级 `not_spoken_count`（§1.3） |
| `hero_photos` | `hero_photos` CTE | 按 `created_at DESC` 取最近 5 张，与卡面点名的活动无关 → 图文错位。改由 activity 自带封面（§2） |
| `last_material_at` | `MAX(lexicon_occurrences.created_at)` | 客户端零消费；且是**存素材**时间，易被误用作「上次聊过」 |
| `preview_words` | `cat_words` CTE 的 `DISTINCT ON` 子查询 | 唯一两个消费点是 `Tab2HeroCard:174` 和 `Tab2MomentRow:193`，均为本次改造的卡面。卡上不列词后归零消费。子查询有成本，建议一并删 |

> **保守方案**：`preview_words` 可先保留一版观察，但必须在 RPC 里标注「零消费，下一刀删」，
> 否则它会像 `sub_scenes` 一样以「并行保留」的名义长期滞留。

### 1.2 保留（不动）

| 字段 | 现有消费者 | 说明 |
|---|---|---|
| `scene_category` | 全部 | 主键 |
| `unlocked` | `MineView` 分组 | 不变 |
| `word_count` | `CategoryProgressRow:170/183/325`、`MineView:603/607/710` | Topics in progress 的 pops 计数与排序仍在用。**仅从话题卡卡面移除**，字段本身保留 |
| `input_count` / 顶层 `unlocked` | 解锁判定 | 不变 |

### 1.3 新增

| 字段 | 类型 | 定义 | 数据源 | 卡面用途 |
|---|---|---|---|---|
| `not_spoken_count` | int | 该类别下 `spoken_count = 0` 的词条数 | `COUNT(*) FILTER (WHERE le.spoken_count = 0)`，加在 `cat_words` CTE | 「6 words not said yet」；More 行的右上徽章；列表排序键 |
| `last_talked_at` | timestamptz? | 该类别最后一次对话的时间；null = 从没聊过 | `MAX(dialogue_sessions.created_at) WHERE scene_category = ...` 新增 CTE | 「Never talked」/「Talked 3 days ago」；理由池的触发条件 |

两个字段的索引均已存在，不需要建新索引：

- `idx_lexicon_entries_user_spoken` on `lexicon_entries (user_id, spoken_count)`
- `idx_dialogue_sessions_user_created` on `dialogue_sessions (user_id, created_at DESC)`

### 1.4 改名 / 改结构

| 现在 | 改成 | 变化 |
|---|---|---|
| `moment_count` | `activity_count` | **仅改名，取值不变**（仍是该类别下 `occurrence_count > 0` 的 `scene_detail` 个数）。理由见 §3 |
| `sub_scenes` | `activities` | 改名 + 收窄字段，见下 |
| `sub_scenes[].quote` | — | 删。卡面不展示句子 |
| `sub_scenes[].target_expression` | — | 删。同上，且这是失控体裁的来源 |
| `sub_scenes[].scene_detail` | `activities[].scene_detail` | 不变 |
| `sub_scenes[].occurrence_count` | `activities[].occurrence_count` | 不变。SQL 原注释即「= 卡面 seen N×」，本次终于用上 |
| `sub_scenes[].image_url` | `activities[].cover.image_url` | 见 §2 |
| — | `activities[].cover.material_id` | **新增**。图片缓存 stableKey 与去重需要，`Tab2SubScene` 当前缺这个字段 |

**`activities` 排序**：按 `occurrence_count DESC`，同值时 `MAX(created_at) DESC`。
卡面只点名前 3 个，其余计入 `+N`（`N = activity_count - 已点名数`）。

---

## 2. 图片与字段的关联规则

这是本次变更的核心，也是现状最大的隐性错误。

### 2.1 现状：图挂在 category 上，与文字无关

```
category
 ├─ featured.image_url    ← More 行缩略图取这里（一条样本素材的图）
 └─ hero_photos[0..4]     ← Hero 拼贴取这里（按 created_at DESC 最近 5 张）
```

两者都与卡面文字**没有对应关系**。卡上写「Daily routines」，图是某一条素材的图；
换成新卡面写「Cooking ×7 · Chores ×4」之后，错位会更明显——文字讲三件事，图讲第四件事。

这与「卡片承诺一句话、交付一个类别」是同一种病的安静版本。

### 2.2 新规则：图属于 activity，不属于 category

```
category
 └─ activities[]
     ├─ scene_detail       "Cooking"
     ├─ occurrence_count   7
     └─ cover              ← 该活动自己的封面
         ├─ material_id
         └─ image_url
```

**封面选取**：该 activity 下**最新的一条带图 material**（`ORDER BY m.created_at DESC`，
`raw_content->>'source_image_path' IS NOT NULL`）。该活动下没有任何带图素材时 `cover = null`。

### 2.3 卡片主图的取用规则

> **卡片主图 = 被点名的前 3 个 activity 中，第一个 `cover != null` 的那一个的 cover。**
>
> 前 3 个全部无图时 → 走 `CategoryPresetArtView` 预设图兜底。
> **禁止**向后查找第 4 个及之后的 activity 取图。

最后一条是硬规则。允许向后查找会重新制造图文错位：
卡上写着 `Cooking ×7 · Chores ×4 · Getting up ×3`，图却来自第 9 个活动 `Doing laundry`——
用户看到的仍是「图和字在说两件事」。宁可退兜底图，也不要一张对不上的真实照片。

### 2.4 Hero 拼贴的处置

`hero_photos` 废弃后，Hero 顶部有两种走法，需要拍板：

| 方案 | 做法 | 取舍 |
|---|---|---|
| **A（推荐）** | Hero 改单张大图 = §2.3 的卡片主图 | 图文严格一一对应；实现最简；失去拼贴的丰富感 |
| B | 拼贴 3 格 = 被点名的 3 个 activity 各自的 cover，缺图的格走兜底纹样 | 保留拼贴；每格与一个活动名对应，仍然可读；实现较复杂，且 3 格中有 1–2 格是兜底纹样时观感碎 |

无论哪种，都**不再按时间取最近 N 张**——那是与文字脱钩的取法。

---

## 3. 命名：`moment` → `activity`

英文 `moment` 指一次性的时刻；代码里它是聚合的：
一个 `scene_detail` = 一类复现活动 = 多条素材（`occurrence_count` 条）。

UI 用一次性的词讲聚合的概念，读起来永远差一口气——
`+12 more moments` 的真实语义是「你有 12 类反复发生的活动」。

`activity` 准确，且与 `scene_category` / `scene_detail` 的既有代码命名一致。

**改名范围**：`moment_count` → `activity_count`；`sub_scenes` → `activities`；
客户端 `Tab2MomentRow` → `Tab2ActivityRow`（组件名）；UI 文案 `moments` → `activities`。
`Tab2FeaturedMoment` 整个删除，不需要改名。

---

## 4. 变更后的返回结构

```jsonc
{
  "unlocked": true,
  "input_count": 143,
  "categories": [
    {
      "scene_category": "日常起居",
      "unlocked": true,

      "word_count": 46,            // 保留：Topics in progress 用
      "not_spoken_count": 6,       // 新增：卡面「6 words not said yet」
      "last_talked_at": null,      // 新增：null = Never talked

      "activity_count": 12,        // 原 moment_count，仅改名
      "activities": [              // 原 sub_scenes，收窄 + 加 cover.material_id
        {
          "scene_detail": "Cooking",
          "occurrence_count": 7,
          "cover": {
            "material_id": "a1b2…",
            "image_url": "https://…/signed"
          }
        },
        { "scene_detail": "Chores",     "occurrence_count": 4, "cover": { … } },
        { "scene_detail": "Getting up", "occurrence_count": 3, "cover": null  }
      ]
    }
  ]
}
```

`activities` 是否需要全量返回（12 条）还是只返回前 3 条 + `activity_count`：
建议**只返回前 5 条**。卡面只用 3 条，多给 2 条是为 §2.3 的兜底查找留余量，
全量返回会让 payload 随用户使用时长线性膨胀。

---

## 5. 边界与已知风险

### 5.1 `×N` 依赖标签稳定性 —— 这是前置条件，不是优化项

`Cooking ×7` 只有在 7 次都被归成**同一个字符串**时才成立。
现在 `classifyScene`（`supabase/functions/generate/index.ts`）每次都是无记忆地重新起名，
没有任何跨次一致性机制。同一件事被归成 `Cooking` / `Cooking meals` / `Making food`，
`×7` 就碎成 `×3 ×2 ×2`，卡面立刻失去说服力。

该函数上方那条 TODO（「写入前与该用户该分类下的已有 scene_detail 比较归并」）
**从「以后再优化」升级为本次变更的前置条件**。

最省的解法在 prompt 层：把该用户该分类下已有的 sub_scene 列表塞进 prompt，
要求命中时逐字复用。另需新增一条约束防止标签退化成类别名的同义词
（`饮食 / Eating`、`工作与学业 / Working` 这类，现 prompt 无防护）。

### 5.2 `其他` 类别会劫持 Hero

`classifyScene` 失败时兜底写 `其他`，所以这一类是垃圾桶，会持续攒到最多的词与素材。
新设计下它会长期是「欠账最多」，反复被选成 Hero。

**规则**：`其他` 排除在 Hero 候选之外，只在 More 列表里出现。

### 5.3 `activity_count` 会比预期小

现 prompt 明确要求高抽象度（「Cooking, not Cooking dinner tonight」），
一个类别下 12 条素材可能只归并出 3–4 个不同的 `scene_detail`。
`+N` 里的 N 会比现在的 `+11` 小很多，甚至为 0。

这不是 bug——抽象化是归并键的正确设计。但卡面文案要能容纳 `+0`（即不渲染 `+N`）。

### 5.4 老客户端兼容

`Tab2CategoryData` 的解码对新增字段使用 `decodeIfPresent`，
但 `featured` / `hero_photos` 被移除后，旧版本 App 会退化为 `isWordsOnly` 分支
（`Tab2MomentRow:11` 判 `featured == nil`），展示纯查词行——不崩，但内容为空。

建议：RPC 变更与强制更新同期发布，或在过渡期同时返回新旧字段一个版本。

---

## 6. 落地顺序

前后依赖明确，不可乱序：

1. **改 `classifyScene` prompt**（喂回已有标签 + 逐字复用 + 防类别同义）
   —— §5.1 的前置条件，独立于 UI，可先上
2. **改 `get_tab2_home` RPC**：新增 `not_spoken_count` / `last_talked_at`，
   复活并收窄 `sub_scenes` → `activities`（含 `cover`），删 `featured` / `hero_photos` / `last_material_at`
3. **改客户端模型**：`Tab2HomeData.swift` 按 §4 重写；删 `Tab2FeaturedMoment` / `Tab2HeroPhoto`
4. **改卡片组件**：`Tab2HeroCard` / `Tab2MomentRow`（→ `Tab2ActivityRow`）
5. **删 `preview_words`**（确认零消费后）

第 1 步不做就上第 2 步，卡面会展示碎掉的 `×N`，比现在更糟。
