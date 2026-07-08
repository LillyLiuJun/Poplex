# Page 0（引导页 Onboarding）产品需求文档 v2.0

> 本文档基于 v1.0 重写，目的是让 PRD 与**实际上线的代码行为对齐**。v1.0 保留在同目录作为设计讨论历史，不删除。
>
> 写法约定：本文用三种标记区分状态，避免"文档写的"和"实际做的"再次错位——
> - **✅ 已实现**：当前代码里真实存在、可在真机复现的行为，是本版本的事实基线。
> - **🔜 计划中**：原设计想做、但当前代码尚未实现的功能。已确认仍要做，进第十一节 Roadmap，不是被删除。
> - **📝 变更**：相对 v1.0 的设计调整（含"以代码为准反过来改文档"的项），集中记录在第十二节。
>
> 一句话概括当前状态：**引导流程已跑通 3 屏静态 + 单次 AI 生成展示，但"把首条内容真正存进后端 / 音频 / 流式 / 自动跳转 / 埋点"这条完整链路尚未接上**，详见第十一节。

---

## 一、引导流程总览（当前实际形态）

```
App 启动：静默匿名登录（Supabase Anonymous Auth，无 UI）  ✅
   ↓
Screen 1：核心价值（Learn English from your own life）      ✅
   ↓
Screen 2：机制说明（拍照 / 说想法 / 打字 → 地道英文）        ✅
   ↓
Screen 3（英语水平自评）—— 推迟，不在本版本，见第三节        （保留空位）
   ↓
Capture 屏：选材 + 生成结果（原 v1 的 Screen4 + Screen5 合并为一屏）  ✅
   ├─ 阶段 A：选材（拍照/相册 + 4 张预存场景卡）
   └─ 阶段 B：选中后点 Continue → 原地切换为生成结果视图
   ↓
点 "Get Started" → 进入 Tab1，引导结束                       ✅
```

📝 **与 v1 的最大结构差异**：v1 把选材(Screen4)和生成态(Screen5)设计成两屏顺序推进；实际代码把它们**合并进同一个视图**（`OnboardingCaptureView`），通过内部状态原地切换——选材内容淡出、生成结果淡入，不换屏。`OnboardingScreen5View.swift` 已是空壳（注释：Merged into OnboardingCaptureView）。因此**实际引导只有 3 屏**（Screen1 / Screen2 / Capture），进度指示为 **3 个圆点**，而非 v1 设想的 "3/5"。

**设计原则（不变）**：先给结果，再解释；能让产品自己教的道理，不写成一屏文案。

**App 启动时机**：进入 Screen 1 之前静默创建/恢复 Supabase 匿名账号，不展示任何登录 UI ✅（`AIEnglishAppApp` 启动 `ensureSignedIn()`）。
🔜 **待实现**：检测 `users.onboarding_completed_at` 已有值时跳过引导——当前跳过判断只读**本地 UserDefaults**，未接 users 表，详见第十节与第十一节。

---

## 二、Screen 1-2：核心价值主张

### 2.1 当前上线文案 ✅

**Screen 1（身份）**
- 主标题（两行）："Learn English / from your own life."
- 副标题："Not textbooks. Not drills. Just what's happening around you, in English you can actually say."
- 底部："Continue" 主按钮；支持左滑前进。

**Screen 2（机制）**
- 主标题："Snap a photo, say what's on your mind, or type a few words."
- 副标题："We'll turn it into natural English you can actually say."
- 顶部返回 chevron；底部 "Continue" 主按钮；支持左右滑动前进/后退。

📝 **变更**：v1 的 Screen2 是**一句长主标题**（"…we'll turn it into English you can say out loud."）。实际代码**拆成主标题 + 副标题两行**，且副标题措辞改为 "natural English you can actually say"。理由：长句在标题字号下换行拥挤，拆行后"输入方式"和"产出承诺"各占一行，层级更清楚。以代码为准。

### 2.2 决策记录（沿用 v1，仍有效）

- 原方案为 3 屏（问题命名 → "翻译是起点不是终点" → 机制说明），收敛为 2 屏。
- **被删除的一屏**："翻译是起点，不是终点"的价值重述——这个道理交给 Tab2 卡片的视觉设计去教（未说出口前卡片模糊，说出来才完整），比引导页用一句话解释更有说服力。
- "Learn English from your own life" 作为核心一句话定位；Screen 1 副标题补一句把"说出来"这个结果带出来，避免被误读成"素材更个性化的背单词 App"。

---

## 三、Screen 3：英语水平自评（维持推迟）

**本版本仍不做这一屏。** `english_level` 计划用默认值 `B1`。候选文案（简化 4 档 + 深度"差距类型"方案）完整记录在 v1.0 附录 A，留作后续版本直接取用。

🔜 **注意**：当前客户端代码里**没有任何 `english_level` 相关逻辑**，该字段的数据库默认值需在后端建表时保证，属第十一节待验证项。

> ⚠️ 与 PRD.md 主文档"引导页只询问 English Level"的决策仍不一致，待后续同步。

---

## 四、Capture 屏 · 阶段 A：选材

### 4.1 四张预存场景卡（终版，已上线）✅

| 场景卡 title | 卡片 id | 对应文字 prompt（送进生成链路） |
|------|------|------|
| Morning coffee | `morning_coffee` | "I'm on my second cup of coffee and still not fully awake." |
| Packed commute | `packed_commute` | "The subway was so crowded I could barely move this morning." |
| Afternoon slump | `afternoon_slump` | "It's 3 pm and my brain has completely stopped working." |
| Hangry | `hangry` | "I'm so hungry I can't decide what to eat and it's making me irritable." |

四张全部是"感受/瞬间"而非"地点/身份"，不预设学生还是职场人群。选卡标准（Aha 时刻设计原则）见 v1.0 第 4.2 节，不变。

### 4.2 页面布局（当前实际形态）✅

从上到下：
1. **返回 chevron**（左上角）。
2. **标题**（固定，两行）："What's happening / around you right now?"——选材阶段和生成阶段共用同一标题。
3. **拍照 / 相册入口**（并排两个按钮）："Take a photo"（相机）/ "Choose photo"（相册）。
4. **过渡文案**："Nothing in mind? Try one of these."
5. **2×2 场景卡网格**：四张全部可见，不折叠、不横滑。
6. **已选态反馈**：选中的卡片/照片加 3px 描边高亮 + 缩放 1.03 + 右上角 checkmark。
7. **"Continue" 主按钮**：仅在已选中素材后从底部滑入出现（见 4.3）。

📝 **变更 · 拍照入口视觉权重**：v1 第 4.3.2 节要求拍照/相册入口"给足视觉权重、是主路径，四张卡只是辅助"。实际代码把拍照/相册做成**两个较小的卡片按钮**（subheadline 字号 + 浅底色），视觉权重反而**低于**下方四张大图卡片。这与 v1 意图相反。
→ **本版本以代码现状为准记录**，但标记为**待评估的视觉问题**（第十一节 Roadmap "体验优化"）：若后续认为"从你自己的生活取材"这一承诺需要更强的入口，再单独评审调整。

### 4.3 二次确认交互（当前实际形态）✅ 📝

**当前行为**：点选卡片或选好照片后**不立即生成**，而是先进入"已选中"待确认态（高亮 + checkmark），底部滑入 "Continue" 按钮；用户**再点 Continue** 才真正进入生成态。即两步：**选中 → Continue → 生成**。

📝 **变更（重要，以代码为准反改文档）**：v1 第 4.3.5 节明确写"**点选/拍照后不设二次确认，选中即直接进入生成态**"。实际实现与之相反，采用了二次确认。经确认**以代码为准**：保留二次确认这一步。

理由记录（供后续复盘）：二次确认给了用户一个"反悔/换一张"的缓冲——尤其拍照路径下，用户可能想先看清选的是不是想要的那张照片，再决定是否消耗唯一一次生成机会；这与"引导页只有一次生成机会"（见第七节失败处理）的谨慎取向一致。摩擦增加一步，但换来选择确定性。

🔜 **仍保留的 v1 决策**：不设文字说明输入框（引导页刻意不给"要不要配文字"的决策），图片/卡片单独提交即可 ✅（当前代码未提供配文字入口，符合）。

### 4.4 视觉风格（默认方案，不变）

引导页视觉/图标风格与产品整体"克制"规范一致（禁止有色/填充/Emoji 图标、无庆祝式 UI），不做引导页专属的更热闹风格。理由见 v1.0 第 4.4 节。

---

## 五、Capture 屏 · 阶段 B：AI 生成与确认

### 5.1 页面主焦点（不变）✅

这一屏是整个引导流程唯一的"验证时刻"。页面只有一个主角：**生成出来的英文内容本身**（`primaryEnglish`，大号加粗）。缩略图、场景追问、确认文案都是配角。

### 5.2 交互流程（当前实际形态）

1. ✅ 用户点 Continue 后进入生成视图（原地切换，选材内容淡出、结果淡入）。
2. ✅ **保留选中的照片/场景卡缩略图**（64×64 小图）作为视觉锚点，让"这张图"和"这句英文"有看得见的因果关系。
3. ✅ 生成中显示 **skeleton loading**（3 行占位条），复用产品克制的加载视觉语言。
4. ✅ 生成成功后展示：`primaryEnglish`（主角）+ `sceneTrigger`（场景追问，次要）+ 确认文案。
5. ✅ **不单独展示"内容已生成"的系统提示**——内容本身出现即是提示。
6. ✅ **不设庆祝式 UI**（无彩带/徽章/"Nice!"弹窗），理由见 v1.0 第 5.4 节。
7. ✅ 底部提供 **"Get Started"** 主按钮，点击进入 Tab1。

🔜 **计划中（当前未实现）**：
- **流式输出**（v1 5.2.4）：当前是 skeleton 结束后**一次性**显示完整内容，尚无逐字流式效果。仍计划做。
- **音频播放按钮**（v1 5.2.6，"第一次兑现口语承诺"的高优先级按钮）：**当前生成结果视图里完全没有音频按钮**。仍计划做，是本版本与原设计差距最大的一处体验缺失。
- **自动跳转**（v1 5.5）：当前**没有**自动跳转计时，改由用户手动点 "Get Started"。自动跳转（未播放 3s / 播放完 +1s / 8s 上限）仍计划做——但它依赖音频按钮先落地。

📝 **变更 · 手动按钮 vs 自动跳转**：在音频与自动跳转链路补齐前，当前用一个明确的 "Get Started" 手动按钮承接跳转，是**过渡方案**而非最终设计。自动跳转仍是目标形态（第十一节）。

### 5.3 确认文案（已上线，不变）✅

**文案**："That's a moment from your life — now it's yours in English."

呼应 Screen 1 核心主张，完成从承诺到兑现的叙事闭环。视觉上极小极轻（footnote 字号，次要色），出现在英文内容之后，不与主内容抢视觉重量。

### 5.4 为什么不做庆祝式 UI（不变）

产品数据模型区分两种状态："AI 生成了但用户还说不出来" vs "用户真正开口说出来了"。这一屏只完成前者，用彩带/徽章装饰会把两种状态混为一谈，削弱"说出来才算数"的核心逻辑。5.3 确认文案是"告诉用户发生了什么"（功能性反馈），不是"替用户鼓掌"（庆祝），因此不算庆祝式 UI。

### 5.5 与 Tab1 Variant A 的承接

进入 Tab1 后即为"变体 A：新用户首屏状态"（AI 欢迎气泡 + 快捷回复胶囊），具体规格见 Tab1 PRD。

⚠️ **一致性风险（当前）**：Tab1 变体 A 计划有一句气泡"我已经把第一张场景卡存进你的 Notebook (Tab2)"。但**当前引导页的生成结果并未写入后端**（见第六节），这句话目前会与事实不符。**必须在第十一节"首条内容落库"完成前，避免让该气泡上线，或临时调整其文案**——否则是明显的"货不对板"。

---

## 六、与后端数据模型对接（当前状态：仅生成、未落库）

### 6.1 当前实际链路 ✅ / 缺口 🔜

✅ **已接通的部分**：Capture 屏提交后，客户端通过 `LiveAIService.generate()` 调用 Supabase Edge Function `generate-content`（预存卡走纯文字 prompt，拍照/相册走图片），拿到 `AIEnvelope` 并在界面展示。符合"客户端不直连 AI、只走 Edge Function"的架构硬约束。

🔜 **尚未接通的部分（本版本核心缺口）**：
| v1 设计的写入时机 | 当前状态 |
|------|------|
| 创建 `conversations` 记录 | ❌ 未创建 |
| 写入 `messages` user 行（含 `input_type` / `preset_card_id`） | ❌ 未写入 |
| 写入 `messages` assistant 行 + 触发 `extract-materials` | ❌ 未写入、未触发 |
| `materials` 表出现首条记录 | ❌ 无 |
| `users.onboarding_completed_at` 写入 | ❌ 仅写本地 UserDefaults（见第十节） |
| `users.session_count` 0→1 | ❌ 未处理 |
| `users.english_level` 默认 B1 | ❌ 客户端无逻辑，后端默认值待验证 |

**影响**：引导页生成的"第一条真实内容"目前**是一次性展示、离开即消失**，不进 Notebook。这使 Tab1 变体 A 的"已存进 Notebook"承诺暂时无法兑现（见 5.5 风险）。**这是第十一节 Roadmap 的最高优先级项。**

### 6.2 落库补齐后的目标设计（仍取 v1 结论）🔜

补齐时应完全复用 Tab1 的生成链路（同一 `generate-content`、同一套 `messages`/`materials` 表），不给引导页单开"假数据"逻辑。需新增：`messages.input_type` 枚举值 `'preset_card'`（区别于 `camera`/`album`）+ `preset_card_id` 字段，用于分析四张卡各自转化率。预存卡走纯文字 prompt、不依赖图片解析（Slice 1 级别即可）。

---

## 七、异常与边界情况处理

### 7.1 权限相关（Capture 屏选材阶段）

✅ **已实现**：拍照走系统 `CameraPickerView`、相册走系统 `photosPicker`，触发标准系统权限弹窗。四张预存场景卡不依赖任何权限，天然是权限被拒时的兜底路径。

🔜 **待实现（v1 第 7.1 节的自定义态）**：相机/相册权限被拒后的**自定义引导态**（"需要相机权限" + 跳转设置按钮）当前未做，目前依赖系统默认行为。补齐属体验完善项。

### 7.2 生成失败（Capture 屏生成阶段）✅

| 场景 | 当前实际处理 |
|------|------|
| 生成出错（首次/第 1 次重试） | 显示 "Something went wrong. Want to try again?" + "Try again" 按钮（`retryCount < 2`） |
| 连续失败 2 次（`retryCount >= 2`） | 显示 "No worries — you can explore inside the app."，底部按钮变为 "Let's dive in."，点击直接进 Tab1，避免卡死 |

📝 **变更 · 失败文案**：v1 第 7.4 节退出文案定为 "No worries — let's dive in."（一句）。实际代码拆成**正文** "No worries — you can explore inside the app." + **按钮** "Let's dive in." 两处。语气一致，以代码为准。

🔜 **仍取 v1 结论但需确认是否已生效**：引导页不做"显示部分内容"的降级（半成品比明确失败更伤新用户信任），直接判失败重试。当前代码逻辑符合（失败即进 error 态，不展示部分内容）。

### 7.3 中途退出与恢复

📝 **当前实际（简化版）**：跳过引导与否**只依据本地 UserDefaults 的 `onboarding_completed_at`**。已走完引导 = 直接进 Tab1；未走完 = 从 Screen 1 重新开始。**没有** v1 第 7.3 节设计的"回到 Capture 屏断点续传""检测 messages 已有记录则补写完成字段"等精细恢复逻辑。

🔜 **待实现**：v1 的断点恢复逻辑依赖后端落库（第六节）与 users 表状态（第十节），需在那两项补齐后一并实现。

---

## 八、开发切片进度对照

> 复用既有 Supabase 项目。以下为**当前真实进度**，非计划表。

| 切片 | 内容 | 状态 |
|------|------|------|
| Slice 0 | Screen 1-2 静态前端 | ✅ 已完成 |
| Slice 1 | Capture 屏选材 UI（四卡 + 拍照/相册入口 + 二次确认） | ✅ 已完成 |
| Slice 2 | 提交 → 调 `generate-content` → 展示生成结果（skeleton + 一次性出全文） | ✅ 已完成（**但不落库**，见第六节） |
| Slice 2.5 | 首条内容写入 `conversations`/`messages`/`materials` + `input_type='preset_card'` | 🔜 未开始（**最高优先级**） |
| Slice 3 | 音频（AVSpeechSynthesizer）+ 自动跳转计时 | 🔜 未开始 |
| Slice 3.1 | 流式输出 | 🔜 未开始 |
| Slice 4 | 异常态全覆盖（权限拒绝自定义态 + 断点恢复） | 🟡 部分（生成失败重试已做；权限自定义态、断点恢复未做） |
| Slice 5 | 埋点接入（第九节 7 个事件） | 🔜 未开始 |
| Slice 6 | 与 Tab1 变体 A 联调（`onboarding_completed_at` 写 users 表、24h 窗口、`session_count`） | 🔜 未开始 |

---

## 九、引导流程埋点事件（🔜 全部待接入）

**当前状态**：Onboarding 目录下**没有任何埋点调用**，以下事件均未上线。埋点基础设施（`Analytics.track` → `log-event` Edge Function）已存在，接入时复用即可。

| 事件名 | 触发时机 | 附加属性 |
|--------|----------|----------|
| `onboarding_screen_viewed` | 进入引导任一屏 | `{ screen: 1\|2\|'capture' }` |
| `onboarding_capture_method_selected` | Capture 屏提交（点 Continue） | `{ method: 'camera'\|'album'\|'preset_card', preset_card_id? }` |
| `onboarding_generation_succeeded` | 生成成功 | `{ latency_ms, card_type }` |
| `onboarding_generation_failed` | 生成失败 | `{ retry_count, error_type }` |
| `onboarding_audio_played` | 点击音频播放（依赖音频按钮先落地） | `{}` |
| `onboarding_skipped` | 走连续失败退出路径 | `{ last_screen }` |
| `onboarding_completed` | 完整走完进入 Tab1 | `{ total_duration_ms }` |

**价值不变**：`onboarding_screen_viewed` 序列可算每屏流失率；`onboarding_capture_method_selected` 分布可验证"拍照/相册是否被更多使用"及四张卡各自转化率。

---

## 十、账号与身份策略

### 10.1 核心决策（不变）✅

打开 App 通过 **Supabase Anonymous Auth** 静默创建账号，用户无感、无登录页 ✅（已实现）。后续积累内容后再邀请绑定 Sign in with Apple（触发时机留后续版本）。不用自建 device ID 方案的理由见 v1.0 第 10 节。

### 10.2 完成状态存储（📝 当前降级 / 🔜 待补齐）

📝 **当前实际**：`onboarding_completed_at` 仅写入**本地 UserDefaults**（`RootView` 用 `@AppStorage` 读取决定进 Tab1 还是引导），**未写入 Supabase users 表**。

🔜 **待实现（已确认要做）**：应把 `onboarding_completed_at` 写入 `users` 表，作为唯一权威来源。当前本地方案是**临时降级**，其局限是：
- 换设备 / 卸载重装且未绑定账号时，本地 flag 丢失 → 已完成引导的用户会被要求**重走一遍**。
- "已绑定账号的老用户登录后跳过引导"（凭 users 表字段判断）暂时无法实现。

补齐后，Tab1 变体 A 的 24 小时退出窗口才能以 `onboarding_completed_at`（而非注册时间）为计时起点。

### 10.3 卸载重装 / 换设备后的状态（目标，取 v1 结论）

- 未绑定账号 + 同设备卸载重装：不保证（取决于 Keychain 是否保留匿名会话）。
- 未绑定账号 + 换设备：必然丢失，重走引导。
- 已绑定账号（Sign in with Apple 等）：登录后完整恢复，跳过引导。

> 结论不变：**"绑定账号"是唯一被产品保证的数据保留方式**，不能把 Keychain 的"重装可能不丢"写进用户可见文案。

---

## 十一、Roadmap：仍计划实现的功能（本版本缺口汇总）

> 以下均为**原设计想做、当前代码未做、且已确认仍要做**的项，按优先级排列。这是本文档相对"当前上线行为"的差值。

| 优先级 | 功能 | 缺口说明 | 关联切片 |
|------|------|------|------|
| P0 | **首条内容落库** | 引导页生成内容当前不写 `conversations`/`messages`/`materials`，导致"存进 Notebook"承诺无法兑现（见第六节、5.5 风险） | Slice 2.5 |
| P0 | **`onboarding_completed_at` 写入 users 表** | 当前仅本地 UserDefaults，换设备/重装会丢（见第十节） | Slice 6 |
| P1 | **生成页音频播放按钮** | 当前完全缺失，是"口语承诺"第一次兑现的关键控件（v1 5.2.6） | Slice 3 |
| P1 | **自动跳转计时** | 当前手动 "Get Started"；目标：未播 3s / 播完 +1s / 8s 上限（依赖音频先落地）（v1 5.5） | Slice 3 |
| P2 | **流式输出** | 当前 skeleton 后一次性出全文，无逐字流式（v1 5.2.4） | Slice 3.1 |
| P2 | **引导埋点 7 事件** | Onboarding 目录无任何埋点（第九节） | Slice 5 |
| P2 | **权限被拒的自定义态** | 相机/相册被拒目前依赖系统默认，无自定义引导（v1 7.1） | Slice 4 |
| P3 | **断点续传恢复** | 当前中途退出从头再来，无回到 Capture 屏的续传（v1 7.3，依赖 P0 落库） | Slice 4 |
| P3 | **拍照入口视觉权重评估** | 当前拍照/相册入口视觉权重低于场景卡，与 v1 意图相反，待评审（第 4.2 节） | 体验优化 |
| 推迟 | **Screen 3 英语水平自评** | 维持 v1 推迟结论，`english_level` 用默认 B1（第三节） | 后续版本 |

---

## 十二、相对 v1.0 的变更记录（速查）

| # | 变更点 | v1.0 设计 | v2.0 实际 / 结论 | 处理方式 |
|---|------|------|------|------|
| 1 | 流程屏数 | Screen 4 + Screen 5 两屏 | 合并为 Capture 一屏（原地切换），实际共 3 屏、3 圆点 | 以代码为准 |
| 2 | Screen 2 文案 | 一句长主标题 | 拆为主标题 + 副标题两行，措辞微调 | 以代码为准 |
| 3 | **二次确认** | 选中即生成，不设二次确认 | **保留二次确认**：选中 → Continue → 生成 | **以代码为准，反改文档** |
| 4 | 自动跳转 | 3s/8s 自动跳转 | 过渡为手动 "Get Started" 按钮 | 自动跳转仍计划做（P1） |
| 5 | 音频按钮 | 高优先级必备 | 当前缺失 | 仍计划做（P1） |
| 6 | 流式输出 | 有 | 当前一次性出全文 | 仍计划做（P2） |
| 7 | 首条内容落库 | 写 messages/materials | 当前仅展示、不落库 | 仍计划做（P0） |
| 8 | 完成状态存储 | 写 users 表 | 当前仅本地 UserDefaults | 仍计划做（P0） |
| 9 | 失败文案 | 一句 "No worries — let's dive in." | 拆为正文 + 按钮两处 | 以代码为准 |
| 10 | 拍照入口权重 | 主路径、权重最高 | 实际权重低于场景卡 | 记为待评估（P3） |
| 11 | 埋点 | 7 事件 | 当前 0 事件 | 仍计划做（P2） |
| 12 | 权限自定义态 | 有 | 当前依赖系统默认 | 仍计划做（P2） |

---

*文档版本：v2.0 | 基于：v1.0（保留为历史）+ 实际代码 `AIEnglishApp/Onboarding/*` 走查 | 更新日期：2026-07-05 | 变更主旨：让 PRD 与已上线代码对齐，用 ✅已实现 / 🔜计划中 / 📝变更 三态标记区分事实基线与待办缺口 | 下一步：按第十一节 Roadmap 排期，优先 P0 两项（首条内容落库 + 完成状态写 users 表）*
