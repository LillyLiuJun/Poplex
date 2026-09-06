# Tab2 Hero 卡 v2 · 五刀执行提示词

> 每刀一个独立会话，按顺序执行，前一刀验证通过再开下一刀。
> 规格来源：`docs/prd/Tab2_Hero卡_视觉与选取_v2.md`（下称「规格文档」）。
> **不要把五刀合成一个 prompt。** 顺序约束（第 2 刀必须早于第 3 刀发布）靠切片边界保证，不靠提示词里的一句话。

---

## 第 1 刀 · classifyScene 的语言与长度

```
读 docs/prd/Tab2_Hero卡_视觉与选取_v2.md 的 §8（只读这一节）。
遵守 CLAUDE.md 的全部硬约束。

任务：修 supabase/functions/generate/index.ts 里 classifyScene() 的两个问题——
sub_scene 会返回母语、以及长度完全无约束。

范围（只能动这两处）：
1. classifyScene 的 prompt（当前 592–604 行附近）：按 §8.4「一、Prompt」全文替换
   sub_scene 说明段与 Anchors 段。
2. classifyScene 的返回值解析（当前 653–656 行）：按 §8.4「二、后端校验」替换
   subScene 的赋值逻辑。

不动：
- prompt 里的 Categories: 中文枚举列表（那是 DB enum 值，不是语言问题，见 §8.4 末）
- category 的白名单校验（649–652 行）
- classifyVocabCategory 及本文件其余任何函数
- 任何客户端代码、任何 SQL

关键约束：
- 语言校验失败 → 落 null；长度超限 → 截断，不落 null。两者不能混。
  理由见 §8.4「二」下方的表：长度是能修的问题，不该丢数据。
- TARGET_SCRIPT 正则上方必须保留注释，说明它与目标语言绑定、换语言时只改这一行。
  这是为了不再次违反 CLAUDE.md:132。
- prompt 里不要写字数上限。示例已经示范了长度，写数字会让模型往上限靠。

完成标准：
- 用一条纯中文输入（如「今天帮我妈弄手机」）走一遍 generate，
  scene_detail 是目标语言且是宽泛标签（如 Fixing a device），不是 Helping mum with her phone。
- 用一条会让模型说长的输入，确认 scene_detail 被截断到 24 字符内且不为 null。
- deno check / deno lint 通过。
```

---

## 第 2 刀 · 客户端解码降级（必须早于第 3 刀发布）

```
读 docs/prd/Tab2_Hero卡_视觉与选取_v2.md 的 §9.3 第 16 行（Tab2HomeData 那条）和 §4.3。
遵守 CLAUDE.md 的全部硬约束。

背景：下一刀会把 RPC 的 preview_words 从字符串数组改成对象数组。本刀先让客户端
能同时吃下两种格式，避免 RPC 发布后旧客户端解码失败。本刀单独发布、单独验证。

任务：AIEnglishApp/Models/Tab2HomeData.swift
1. 新增 struct Tab2PreviewWord: Decodable，字段 lemma / displayForm / pos / nativeMeaning，
   后三个可空，CodingKeys 走 snake_case 映射。
2. Tab2CategoryData.previewWords 类型由 [String] 改为 [Tab2PreviewWord]。
3. 自定义解码：先按 [Tab2PreviewWord] 解；失败则按 [String] 解并把每个字符串包成
   Tab2PreviewWord(lemma: s)；再失败落空数组。三层都不能抛。

不动：
- 本文件其余任何模型
- 任何使用 previewWords 的视图（下刀处理；本刀只需让它们仍能编译，
  必要时用 .map(\.lemma) 做最小适配，不改视觉）
- 任何 SQL、任何 Edge Function

完成标准：
- 项目编译通过。
- 新增单测：分别用旧格式 ["back up","glitch"]、新格式 [{"lemma":"back up",...}]、
  以及畸形 JSON 三种输入解码 Tab2CategoryData，均不抛异常且 previewWords 结果符合预期。
```

---

## 第 3 刀 · get_tab2_home 迁移

```
读 docs/prd/Tab2_Hero卡_视觉与选取_v2.md 的 §4.2、§5、§9.1。
遵守 CLAUDE.md 的全部硬约束。

前置：第 2 刀已发布（客户端能吃新的 preview_words 结构）。若未发布，停下来告诉我。

任务：新建一个 migration，CREATE OR REPLACE get_tab2_home。以
supabase/migrations/20260812030000_get_tab2_home_v3.sql 为基准，做 §9.1 的六项改动：

1. featured 排序新增首键「有照片优先」：
   CASE WHEN m.raw_content->>'source_image_path' IS NOT NULL THEN 0 ELSE 1 END
   放在现 ORDER BY 的最前面（在原 ⓪ 单图绑定键的位置之前）。
2. 删除「单图绑定」：ORDER BY 里的 ⓪ 键、single_photo_mat CTE、
   以及 featured 里的 LEFT JOIN single_photo_mat spm，三处一起删干净。
   理由见 §5.3：加了 #1 之后它已冗余。
3. 删除「新鲜度」：ORDER BY 里 CASE WHEN le.spoken_count = 0 那一层。
   注意 le.spoken_count 仍要留在 SELECT 投影里（前端 featured 对象仍返回该字段）。
4. passage 取值，两处 COALESCE：
   target_expression 投影 → COALESCE(m.raw_content->'passage_lines'->0->>'en',
                                     m.raw_content->>'target_expression')
   native_meaning  投影 → COALESCE(m.raw_content->'passage_lines'->0->>'zh',
                                     m.raw_content->>'native_meaning')
5. preview_words 改对象数组：cat_words 里那个子查询的 jsonb_agg(sub.lemma ORDER BY sub.ts DESC)
   换成 jsonb_agg(jsonb_build_object('lemma',…,'display_form',…,'pos',…,'native_meaning',…)),
   子查询需相应 join lexicon_entries 取 display_form / pos / native_meaning。
   保持原有的 DISTINCT ON (lemma)、status='active'、LIMIT 3 语义不变。
6. 修正 moment_counts CTE 上方那句注释——现写「moment = 非 word 素材」，
   实际数的是 scene_detail 组。按规格文档 §1 的术语改写。

不动：
- hero_photos CTE 的 slot <= 5（前端只取前 3，多返回不渲染，留给 More 列表）
- sub_scenes CTE（本轮仍需要它，见 §10 第 7 条，不要当死代码删掉）
- 解锁判定、input_count、任何其他 RPC

完成标准：
- 迁移可重复执行（CREATE OR REPLACE）。
- 对一个真实用户调用 get_tab2_home，检查：
  · 每个 categories[].featured 若该分类有照片，则 featured.image_url 非空
  · hero_photos[0].is_featured 为 true（当 featured 有图时）
  · preview_words 是对象数组且含四个字段
  · 一条 passage 素材的 featured，target_expression 是单句而非整篇
```

---

## 第 4 刀 · 卡片视觉

```
读 docs/prd/Tab2_Hero卡_视觉与选取_v2.md 的 §3、§4、§6。
遵守 CLAUDE.md 的全部硬约束——特别注意：所有颜色字号间距必须走 AppTheme token，
不得出现字面量 Color(hex:) 或 .font(.system(size:))；产品 UI 文案一律目标语言。

前置：第 3 刀已发布。

任务：按规格重做 Hero 卡的视觉。本刀只做视图，不碰任何选取逻辑、不碰页面结构。

范围（只能动这四个文件）：
1. Mine/Components/Tab2HeroCard.swift
   · 图区 150 / 文字区自适应（§3.1），卡片总高 274–315，不要 frame 定死高度
   · 文字区 offset y: -14，照片卡与预设卡统一（§3.1 那段说明）
   · 三行结构与字号见 §3.4；主句 lineLimit(2)、母语 lineLimit(2)、meta 单行
   · meta 行抢位：scene_detail maxWidth 175 + lineLimit(1)；
     「· +N more moments」用 layoutPriority(1) 永不截断（§3.4）
   · 删除 §3.6 的三个元素：图上的 +N overlay、created_at、from your photo（连图标）
   · 模式 D 改为 3 行「词 · 词性 · 释义」，规格见 §4.3。
     明确不做该节列的五项（标题行 / 词数 / 底纹 / chips / 词墙）
   · passage 的取值由 RPC 已处理，视图侧不需要分支
2. Mine/Components/HeroCollageView.swift
   · 张数上限 5 → 3，只保留 c1 / c2 / c3 三种布局，删掉 c4 / c5 分支
   · 高度 178 → 150；底部 42% mask 渐隐（§3.2）
   · saturation 0.9 → 0.7；加两层色调（暖橙 multiply 20% + 暖纸 soft-light 45%）
   · HeroTopOverlay 不再渲染 moreCount
3. Mine/Components/CategoryPresetArtView.swift
   · 按 §6.3 完整重做，规格已定稿，视觉稿见 design/tab2_preset_b.html（方案 B1）
   · 关键：不要套底部渐隐 mask（那是照片专用），改成底色自身渐变
     linear-gradient(#FBF6F1 0% → #FCF8F5 62% → #FFFFFF 100%)。理由见 §6.2
   · 两团光晕（blur 36）、图标 96 描边 rgba(150,88,50,.19)、橙点 8pt，
     数值一律照 §6.3 的表，不要自行调整
   · 12 张只有图标 path 不同，其余逐字复用——实现成一个接收 Path 的视图，
     由 SceneCategory 提供各自图标，不要 12 份重复代码
   · 不再渲染 moreCount
4. Tab2HeroCard 里选择拼图还是预设图的判据：
   由 heroPhotos.isEmpty 改为 heroPhotos.isEmpty || featured?.imageUrl == nil（§5.2）
   —— 这是本刀最重要的一条，防图文错配。

另需：scene_detail 渲染前跑一次目标语言校验，不通过按 nil 处理（§8.4「三、前端兜底」）。
存量脏数据靠这层挡，不洗库。

不动：
- MineView.swift（下一刀）
- Tab2HomeViewModel.swift（下一刀）
- Topics in progress 相关的 CategoryProgressRow 及其一切
- 任何 SQL、任何 Edge Function

完成标准：
- 扩展 Tab2HeroCard.swift 现有的 #Preview，穷举以下组合并逐个目检：
  · 四模式 A / B / C / D
  · 拼图 1 / 2 / 3 张，以及 featured 无图走预设图
  · 主句长度：短（1 行）/ 中（2 行）/ 超长（2 行截断）
  · 母语长度：1 行 / 2 行 / 超长截断
  · scene_detail 超长 + 三位数 +N，确认「+999 more moments」完整未截
- 项目编译通过，无新增 AppTheme token 违规（按 CLAUDE.md 的检查方式自查）。
```

---

## 第 5 刀 · 页面结构与选取逻辑

```
读 docs/prd/Tab2_Hero卡_视觉与选取_v2.md 的 §2、§7。
遵守 CLAUDE.md 的全部硬约束。

前置：第 4 刀已完成。

任务：把已解锁区从横向轮播改成 hero 单卡，并重写 hero 的选取逻辑。

范围：
1. Mine/MineView.swift 的 contentSections
   · 已解锁区：横向 ScrollView + frame(width: 350) 改为 hero 单卡（§2）
   · 去掉 "Your topics" 分区标题
   · 一并清理为横滑而加的 IgnoredTabSwipeFrameKey / scrollClipDisabled 等
   · otherUnlocked 那批分类本刀先不渲染（More 列表下一轮设计），
     但不要删除计算它们的代码，留着并加 TODO
2. Mine/Tab2HomeViewModel.swift 的 heroCategory
   按 §7.3 重写：
   · 硬过滤：unlocked && featured != nil && 该分类还有没聊过的 moment
   · 分档：featured.createdAt 一周内的排前面
   · 档内：按「没聊过的 moment 数」降序
   · 平手：featured.createdAt 最新
   · 兜底 1：候选为空时忽略「聊过」重排一遍
   · 兜底 2：无任何 featured 时取 pops 最多的分类（出模式 D 卡）
   关键：绝对不要用 lastMaterialAt（被查词污染，见 §7.2）；
        绝对不要用 spoken_count 判断聊过没聊过（词条级，不可信，见 §7.4）
   「没聊过的 moment 数」= 该分类 subScenes 里 scene_detail 不在本地已聊集合中的个数
3. 新增：已聊 moment 的本地存储
   · UserDefaults 存一个 Set<String>，键是 scene_detail（moment 层，不是 material 层，见 §7.4）
   · 参照 Tab2HomeViewModel 里 tab2_unlocked 的写法，同一套风格
   · 写入点在对话结束回调；若对话页尚未接线，建好存储层并留 TODO——
     集合为空时 heroCategory 的硬过滤自然退化为「全部候选」，不阻塞
4. 新增：hero 稳定（§7.5）
   · 选中后把 material_id 存本地，只在「聊过了」或「有更新 moment 进来」时重算
   · 否则无论刷新几次、退出几次，回来仍是同一张卡

不动（重要）：
- contentSections 里 Topics in progress 那一整段：分区标题、CategoryProgressRow、
  手风琴展开、toggleExpand、进度条样式，一行都不要改。
  这一段和 hero 区在同一个函数里，注意不要顺手「优化」它。
- Tab2HeroCard / HeroCollageView / CategoryPresetArtView（上一刀已定稿）
- 任何 SQL、任何 Edge Function

完成标准：
- 新增 heroCategory 的单测，覆盖：
  · 正常：两个分类都有未聊 moment，一周内的胜出
  · 同档：两个都在一周内，未聊 moment 多的胜出
  · 兜底 1：全部聊过 → 仍返回一个分类，不返回 nil
  · 兜底 2：无任何 featured → 返回 pops 最多的分类
  · 反例：某分类 lastMaterialAt 很新但 featured.createdAt 很旧，不应因此胜出
- 真机：进入 Tab2 记下 hero 是哪张，退出重进、下拉刷新，仍是同一张。
- 项目编译通过，Topics in progress 区行为与改动前完全一致。
```

---

## 执行顺序与发布节奏

```
第 1 刀  ── 可随时发，越早越好（干净数据积累）
第 2 刀  ── 必须先于第 3 刀发布到线上
第 3 刀  ── 依赖第 2 刀已发布
第 4 刀  ── 依赖第 3 刀
第 5 刀  ── 依赖第 4 刀
```

第 1 刀与第 2 刀彼此无依赖，可并行。第 3–5 刀必须串行。
