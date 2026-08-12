# Tab2 Hero 卡改造 · Claude Code 开发提示词

按 §10.6 的发布顺序拆成三刀，**必须串行**：A 验证通过再做 B，B 验证通过再做 C。
每刀开一个新会话，把对应段落整段贴进去。

---

## 通用前缀（每刀开头都带上）

```
先读 CLAUDE.md 全文，再读 docs/prd/Tab2_Hero卡_数据提取与展示_设计方案_v1.md 全文。
这份设计方案是本次改造的权威文档；它与旧文档冲突时以它为准，与代码冲突时以代码为事实——
若发现代码与文档不符，先停下来告诉我，不要自行按文档改代码。

工作方式：
- 动手前先给我一个改动清单（文件 + 改什么 + 为什么），我确认后再写代码。
- 每个文件改完后简述改了什么，不要一次性改完再汇报。
- 不要顺手重构无关代码，不要格式化未涉及的文件。
- 涉及 migration 的，文件名沿用项目现有时间戳命名规范，且只用 CREATE OR REPLACE / ADD COLUMN，
  不写破坏性 DDL。
- 写完跑一遍相关测试；没有测试的地方告诉我该补哪些。
```

---

## 第 1 刀 · generate 侧：纯图片 direction + intent_source

> 权威段落：设计方案 §10（全节）
> 风险面：prompt + 线上账本语义。**必须单独发布并线上验证后再做第 2 刀。**

```
本刀范围 = 设计方案 §10 全节，不碰 Tab2 RPC、不碰前端。

要做的事：

1. supabase/functions/generate/index.ts —— 纯图片（无附带文字）分支
   现状：direction = 'comprehend'，卡型 s2（见 index.ts 约 114-131 行）。
   改为：direction = 'express'。
   先告诉我卡型该走 s6 还是新开一型——判断依据是目标卡型的输出契约能否容纳
   user_original = null / input_lang = null。给出你的判断和理由，我确认后再改。
   注意：target_expression 与 native_meaning 在这个分支仍是 REQUIRED、never null，不要动。

2. 新增 migration：lexicon_occurrences 增加 intent_source 列
   ALTER TABLE lexicon_occurrences
     ADD COLUMN intent_source text CHECK (intent_source IN ('stated','inferred'));
   写入规则见 §10.4.3 的表格。

3. 存量数据 backfill（同一个 migration 里做）
   历史行中 intent_text 非空且来源为用户母语输入的，回填 intent_source = 'stated'。
   回填条件要你自己从 lexicon_occurrences 现有列推导（input_lang='native' 且 intent_text
   非空），推导逻辑先说给我听。

4. 收窄既有聚合的部分索引
   20260728000000 里的 idx_lexicon_occurrences_user_intent，条件改为
   WHERE intent_text IS NOT NULL AND intent_source = 'stated'。
   同时全仓搜索所有读 intent_text 的地方，逐个确认是否需要补 intent_source = 'stated' 条件，
   列给我看，不要自行修改业务语义。

5. record_lexicon_material_units RPC
   确认 input_lang = null 时不会被枚举校验拒绝（它已有 coerce-to-null 逻辑，只需验证）。
   并让它接收/写入 intent_source。

6. 测试
   supabase/functions/generate/rawContent_test.ts 里现有断言明确写了 comprehend，需要更新。
   补一条纯图片 → express 的用例。

验收（§12 对应项）：
- 纯图片输入后，materials.raw_content.direction = 'express'
- 该素材产出的 lexicon_occurrences 行：source_direction='express'、intent_source='inferred'、
  intent_text 非空、input_lang 为 null
- 有文字的 native express 输入：intent_source='stated'
- comprehend 来源：intent_source 为 null
- 既有意图聚合查询的结果不因本次改动而改变（backfill 正确的话应完全一致）——
  请给我一段可以在改动前后各跑一次对比的 SQL。

明确不要做：
- 不要用 native_meaning 直接覆盖 intent 而不打 inferred 标记（理由见 §10.4.4）
- 不要碰 get_tab2_home
- 不要改 Tab1 前端
```

---

## 第 2 刀 · 数据层：get_tab2_home 重构

> 权威段落：设计方案 §3、§6、§8、§9
> 前置：第 1 刀已线上验证

```
本刀范围 = 设计方案 §8 + §9，外加 §3（排序键）和 §6（取图规则）作为逻辑依据。不碰前端渲染。

要做的事：

1. 新 migration：CREATE OR REPLACE FUNCTION get_tab2_home
   核心是修 §8.1 的 bug —— 现状 quote / target_expression / image_url 是三个各自独立的
   标量子查询，各自 ORDER BY created_at DESC LIMIT 1，导致同一张卡的图/话/时间可能来自
   三条不同的 material。
   改为 §8.1 给出的 DISTINCT ON 结构：按 scene_category 分组，用五层排序键选出唯一一条
   featured material，从这一行取全部字段。
   §8.1 里的 SQL 是骨架不是成品——scene_counts CTE 需要你补全，且要自己验证
   DISTINCT ON 与 ORDER BY 的列顺序合法。

2. 排序键严格按 §3.3 的五层实现，注释里标上每层的编号，方便对照文档 review。
   granularity='word' 不参选 featured（§3.2）。

3. 新增 hero_photos（§6.2）
   最多 5 条，按 material_id 去重，created_at DESC。
   featured 自带照片时该照片置于 slot 1 并标 is_featured=true（§3.6）。
   §3.5 的窄规则：分类恰好只有 1 张照片时，featured 反向绑定到该照片所属 material —— 
   这条会和排序键冲突，实现前先告诉我你打算怎么表达这个约束。

4. 修 §8.2 的阈值 bug
   现状 length(user_original) >= 6 对中英文语义完全不同。
   按 input_lang 分开：native 字符数 >= 6，target 词数 >= 4，null（纯图片）不适用。

5. 输出结构按 §9.1 的 JSON，新增 moment_count / hero_photos / featured。
   §9.4：sub_scenes 数组理论上已无消费方。动手前先全仓搜索谁在读 subScenes
   （Tab2CategoryRow / MomentRow / 任何直读路径），把结果列给我，我决定这次删不删。
   §9.5：本刀先新旧字段并行返回，不要直接删 sub_scenes。

6. AIEnglishApp/Models/Tab2HomeData.swift 按 §9.2 加模型
   新增 Tab2FeaturedMoment、Tab2HeroPhoto；Tab2CategoryData 加 heroPhotos / momentCount / featured。
   created_at 解析复用文件里现有的 fractional-seconds 双格式兜底逻辑。
   本刀只加模型不改 UI，保证编译通过即可。

验收（§12.1、§12.3）：
- 同一张卡的 image_url（is_featured=true 时）/ user_original / created_at 必须来自同一 material_id
  —— 给我一段可以直接跑的断言 SQL
- 单图分类：hero_photos[0].is_featured 必须为 true
- §12.3 的五条排序用例，每条构造数据跑一遍

明确不要做：
- 不要动 lexicon 表结构
- 不要在本刀里删 sub_scenes
- 不要改前端渲染
```

---

## 第 3 刀 · 前端：Hero 卡重构

> 权威段落：设计方案 §2、§4、§5、§7、§11
> 设计参考：`docs/design-demos/tab2-hero-collage-redesign.html`
> 前置：第 2 刀已合并

```
本刀范围 = 设计方案 §11 的改造清单，视觉规则见 §2 / §4 / §5 / §7。
先在浏览器打开 docs/design-demos/tab2-hero-collage-redesign.html 看一眼拼图布局
（c1–c5 的 grid 定义直接照搬，demo 里已验证过）。

要做的事：

1. 新增 HeroCollageView
   1–5 张真实照片的拼图布局，c1–c5 五种排布照搬 demo 的 grid 规则。
   叠加层：分类标签（左上）、pops（右上）、+N more moments。
   顶部渐变暗角照搬 demo 的 .topgrad。

2. 新增 CategoryPresetArtView
   hero_photos 为空时整块替换（§6.3：判定源必须是 hero_photos 是否为空，
   不要用 sub_scenes 里有没有图）。
   12 张分类预设插画尚未产出——先用占位实现，接口留好，我后面替换资源。

3. Tab2HeroCard.featuredMoment 拆成模式 A / B / C 三个 @ViewBuilder
   判据严格按 §4.2 的表：用 (user_original, input_lang) 组合判断，
   不能只看 input_lang（纯图片的 input_lang 是 null）。
   - 模式 A（§4.3）：引号 + 衬线，正文色
   - 模式 B（§4.4）：target_expression 衬线主角 + user_original 小字 muted 注脚，无引号
   - 模式 C（§4.5）：target_expression 主角 + "from your photo" 来源标记，无引号
   §4.1 硬约束：引号只用于用户实际用目标语言产出的字面文本。B / C 下出现引号即为 bug。

4. 底部 meta 行（§5）
   {scene_detail} · seen {N}× · {相对时间}
   seen N× 仅 occurrence_count > 1 时显示（沿用现状）。
   时间按 §5.4 的粗粒度：today / yesterday / N days ago / last month / earlier，不精确到小时。

5. CTA 改造（§7）
   从卡内整条大按钮改为右下角短 pill，文案 Talk + 箭头。
   整卡仍可点（现状已是 Button），所以 CTA 是 affordance 提示 —— 视觉要轻，
   用描边或次要色，不与主角句抢注意力。

6. 高度（§2.3、§4.7）
   底部固定高度：模式 A 112–120px，模式 B/C 124px。
   各模式必须对齐，卡片在列表滚动中不得跳动。

7. 模式 D（§4.6）
   词 chips 固定 4–6 个，按词长做打包预算 —— 现状用 flex-wrap + 固定高度会裁掉半行。
   排序：最近攒的 + spoken_count = 0 优先。
   文案改为 "N words waiting to be used"。

8. MomentRow.swift
   +N 上移顶部后底部不再列其他 moment，确认它是否还有消费方，结果告诉我再决定删不删。

9. 设计 token
   衬线用 design: .serif；注脚与来源标记用 AppTheme.Color.textMuted + 11pt。
   不要硬编码颜色，全部走 AppTheme。

验收（§12.2、§12.4）：
- 模式 B、C 下不得出现引号
- 模式 C 必须渲染来源标记
- 截图：模式 A/B/C/D × 拼图 c1/c3/c5/预设图，共 8 组关键组合

明确不要做：
- 不要改 RPC
- 不要为了填满布局而自造文案
- 不要在 featured 无图时用别的 moment 的图去补 slot 1（§3.6：这是加分项不是必要条件）
```

---

## 提交前自查（每刀都问一遍）

```
对照 docs/prd/Tab2_Hero卡_数据提取与展示_设计方案_v1.md 自查本刀的所有验收项，
逐条给我结论（通过 / 未通过 / 不适用 + 理由）。
另外告诉我：本次改动有没有任何一处与文档不符？如果有，是文档需要回写，还是实现需要改？
```
