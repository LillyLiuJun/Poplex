# 刀 6 实现提示词（v1）

刀 6 拆成两刀：**6a 结构与显隐**（本文件 §一）、**6b 胶囊视觉**（§二）。
6a 先做、先验收，6b 在 6a 之上做。两刀都不碰后端、不改返回字段。

---

## 一、刀 6a · 结构与显隐

### 背景（为什么要做）

Tab2 解锁页现在把**页面级标题**和**页脚宣言**写在了条件判断的外面，
而它下面的三块内容各自有 `if`。于是出现过一张真机截图：
`Talk about today` 孤零零挂在顶上、下面直接跳到 `Topics in progress`、
底部还有一句 `Poplex. English from your everyday life.`——
**首尾两个不该出现的东西同时出现了。**

根因不是漏了一个 `if`，是信息架构的假设错了。正确的模型是：

> **标题属于它的区块，不属于页面。**
> 三个区块（Talk about today / More to talk about / Topics in progress）是**平级的**，
> 每块自带标题，有内容就整块出现、没内容就整块消失。页面本身没有标题。

触发这一状态的路径是真实存在的，不是测试脏数据：
`tab2_permanently_unlocked` 记在**本机 UserDefaults**、是一次性单向开关，
而词数来自**服务器**。用户解锁后删掉素材、或换台设备登录，
就会走到"开关已开、但眼下没有任何类目达标"这一格。

### 要改什么

文件：`AIEnglishApp/Mine/MineView.swift`（`Tab2UnlockedView`）、
`AIEnglishApp/Theme/Theme.swift`

#### 规则 1 — 没有任何类目解锁

`Talk about today` 标题 + Hero 卡 + `More to talk about` 标题 + More 列表
**整体不渲染**（标题跟着走），页面只剩 `Topics in progress`。

#### 规则 2 — 只有 1 个类目解锁

渲染 `Talk about today` + Hero，然后 `Topics in progress`。
**`More to talk about` 整块不渲染**（标题一起）。

注意：现在的代码只判 `moreRows.isEmpty`，而"只有 1 个解锁类目"时
Hero 恰好占掉了唯一一个，More 自然为空——**这一条现在碰巧是对的，
但它是副作用不是规则**。请把它写成明写的条件并加注释：
More 的含义是"除了 Hero 还有别的"，只有一件事可聊时不存在"别的"。

#### 规则 3 — 三个标题同档

三个区块标题统一使用 `AppTheme.Font.sectionTitleSerif`
（`Theme.swift:509`，`charter(22, weight: .bold, relativeTo: .title2)`）。

`Talk about today` 和 `Topics in progress` 已经是它，不动。
`More to talk about` 现在是 `AppTheme.Font.tab2SectionEyebrow`
（Geist 12pt SemiBold 大写 + 字距），改回 `sectionTitleSerif`，
并**删掉** `.textCase(.uppercase)` 和 `.tracking(AppTheme.Typography.tab2SectionEyebrowTracking)`
两个修饰、以及 eyebrow 专用的 padding 调整。

这推翻了刀 6 §六① 把 More 降为眉题的决定。当时的理由是
"它们不是三个并列的页面标题"——按上面的信息架构模型，**它们就是**，
本来就该同档。原判作废。

改完后 `tab2SectionEyebrow` 与 `tab2SectionEyebrowTracking` 若无其他消费者，
**同一个提交里删掉**（CLAUDE.md 语义层 token 规则：本刀弄出的孤儿本刀清）。
删前按 CLAUDE.md 的方法确认：grep + 读代码确认，别只信 grep。

#### 规则 4 — 三块全空

三块都不渲染时，显示 `EmptyStateView()`
（`AIEnglishApp/Components/EmptyStateView.swift`，
文案 `Nothing here yet.` / `Start with a moment from your day.`）。

这个组件现在**只挂在锁定页上**，解锁页从未引用过它——
因为当初假设"能进这一页就一定有内容"。现在这条假设不成立了，需要新接。
组件不改、文案不改、样式不改，只是把现成的线接到之前没接的地方。

#### 规则 5 — 页脚宣言跟随 Hero 区块

`footerSignoff`（`MineView.swift:803`，即 `Poplex. / English from your everyday life.`）
现在在解锁页里是无条件渲染的，犯的是和 `Talk about today` 同一个错。

改为：**与 `Talk about today` 区块同进同出——Hero 出现它才出现。**

理由：这是一句收尾陈述（"这就是从你生活里长出来的英语"），
要成立，上面得真有用户的生活——Hero 卡上的照片和做过的事。
只剩 `Topics in progress` 的那一页上面只有进度条和词，
这句话是在替一个还没发生的事作总结。
佐证：锁定页从来没有这句宣言，而"只剩 Topics"这一页内容上几乎等同锁定页，
绑在 Hero 上能让两者的收尾保持一致。

### 状态矩阵（验收用）

| 解锁类目数 | Talk about today + Hero | More to talk about | Topics in progress | footerSignoff | EmptyStateView |
|---|---|---|---|---|---|
| 0，且有在攒的类目 | ✗ | ✗ | ✓ | ✗ | ✗ |
| 0，且什么都没有 | ✗ | ✗ | ✗ | ✗ | ✓ |
| 1 | ✓ | ✗ | 有则 ✓ | ✓ | ✗ |
| ≥2 | ✓ | ✓ | 有则 ✓ | ✓ | ✗ |

### 不要做

- 不要动 `tab2_permanently_unlocked` 这个开关的语义。
  有人会想"没达标就退回锁定页"——**不要**。用户点过那个解锁按钮，
  那是一次仪式，把门再关上在体验上是惩罚。开关不动，补空态。
- 不要给空态加任何解释性文案（"Nothing ready to talk about yet" 之类）。
  按新模型，没有内容就是没有，不需要留个标题再解释为什么空着。
- 不碰后端、RPC、返回字段。
- 不碰 Hero 选取与排序逻辑、不碰点击行为、
  `Start talking` 仍弹 Coming soon。

### 验收

1. 按状态矩阵四行逐格截图（可用 mock 数据或 DesignLab preview 构造）。
2. 单元测试：为四种状态各写一条，锁定区块显隐；
   `tab2SectionEyebrow` 删除后全项目编译通过。
3. 现有 UI 启动烟测必须仍然通过。
4. 报告用 xcresult 的数字，不要数日志行。

---

## 二、刀 6b · 胶囊视觉

（在 6a 验收通过后再做。设计稿：`docs/prd/Tab2_话题卡_刀6视觉稿_v12.html`）

### 核心改动

活动从"衬线文字流 + `·` 分隔 + 上标次数"改为**一活动一胶囊**，
Hero 与 More 用同一种形体、只差字号。**次数不再渲染。**

### 数据约定（后端零改动）

- `occurrence_count` 照常返回、照常用于**排序**，但**不渲染**
- 候选仍是每类最多 5 条，已按次数降序排好，客户端原序取用、不重排
- `+N more` = `activity_count` 减实际显示条数，`N = 0` 时不渲染

### 排布规则

- 胶囊组固定**两行高度**：只排下 1 个也占两行的高，卡高与行高恒定
- 两行排得下几个就显示几个（最多 5）
- 放不下就**少显示一个胶囊**，绝不截断活动名；少一个 `N` 自动加一
- `+N more` 作为最后一个**无底色胶囊**跟在末尾，与活动站同一条基线

### Hero 卡版式（按 v12.1）

自上而下：

1. **照片区**，左上角一行两个标签：类别名 chip + 理由胶囊
   - 理由胶囊在图上**不能用浅底**（照片深浅不可控，浅底会在深色照片上炸成白斑），
     沿用类别标签那套半透明深色底，暖橙只留给点和字色
   - 暖橙态：点 `#FF8A4C` / 字 `#FFE4D2`；久未态：点与字转中性白
2. **`Recent activities`** 小标题（sans，小号大写，textMuted）
   - 这个小标题**只在 Hero 有，More 行不加**
   - 活动数为 0 时，小标题与胶囊组**整块消失**，不留空标题
3. **活动胶囊组**（衬线字，浅底 `chipBg` 中性米，两行固定高）
4. **底行**：左 `47 words`，右 `Start talking →`（CTA 保持右对齐）

### 理由行文案（三档）

- `newMaterialCount >= 2` 且当日 → `Added N times today`
- `newMaterialCount == 1` 且当日 → `Added something today`
- 其余 → `Nothing new in X`（沿用 `Tab2CardLabels.reasonLine` 现有久未分支）

改的是 `Tab2CardLabels.swift` 里 `bits` 那两行。
`bits` 指代不明——胶囊上没有数字之后，用户会去卡片上找那个 N 对应什么；
`times` 的数字锚在"你动手的次数"上，页面上本来就没有可见的对应物。

### More 行版式

- 首行：左类别名（sans 小号 semibold）、右时间（最浅）
- 中：活动胶囊组，两行固定高，13px
- 末行：`N words`
- 预设缩略图保持浅底 + 类别线性图标，不与真实照片互相冒充

### 色彩规矩（不变）

暖橙只标记"今天有新东西"，整屏一处（仅 Hero 理由胶囊）。
`×N` 次数、词数、`+N more`、类别名、区块标题、箭头一律中性。

### 待办（本刀不做，记录在案）

- `primaryDeep #C2410C` 同时是"新内容"色和 Delete account 危险色，
  未来换成 `primary950 #FF7622`
- 让胶囊底色深浅跟随次数，使"重复"重新可见而不占宽度
- 后端 `new_material_count` 补 `AND lo.source_type = 'material'`
  （今天零影响，是对话上线的前置护栏）
