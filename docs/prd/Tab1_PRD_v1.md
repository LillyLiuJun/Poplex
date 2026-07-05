# Page 1（Tab1）产品需求文档 v1.0

> 本文档基于六层框架推进到 Layer 5（系统交互），包含 Supabase 数据库设计与 Claude Code 开发切片计划。
> **当前需要用户确认的断点**：Layer 3（功能结构）和 Layer 5（系统交互）完成标准，确认后再进入 Layer 6（视觉感知）。

---

## 一、框架定位：我们现在在哪一层

```
第一层  需求建构    ✅ 稳定 — "有话想说但说不出来，这个产品帮你说出来"
第二层  场景与边界  ✅ 稳定 — Tab1/Tab2 分工、MVP 范围、AI 主导原则
第三层  功能结构    ⬇ 本文档完成
第四层  信息流转    ⬇ 本文档完成
第五层  系统交互    ⬇ 本文档完成
第六层  用户感知    🔜 下一步：进入视觉设计工具
```

**已确认的产品原则（上两层遗留，作为本文档所有决策的依据）：**
- AI 自动决策 + 轻量纠正（不给用户选风格、不强迫分类确认）
- 先给答案，再追问（信息不足也先生成，不阻塞流程）
- 素材生成即可见，分类是后续动作（Tab2 异步）
- 新用户态与老用户态有明确区分

---

## 二、Layer 3：功能结构

### 2.1 Page 1 的页面定位

**Page 1 解决且仅解决一个问题：用户有话想说，但没有足够的英文能力把它说出来。**

Page 1 不负责练习，不负责分类，不负责复习。它只负责：捕捉用户的处境 → 生成地道英文表达 → 把内容流转给 Tab2。

---

### 2.2 模块拆解（系统视角）

```
Page 1
├── 模块A：消息流区（Message Stream）
│   ├── A1. 新用户引导层（仅前 3 次会话触发）
│   ├── A2. 历史消息列表（用户消息 + AI 回复卡片）
│   └── A3. 天分隔线（按日期组织）
│
├── 模块B：AI 回复卡片（AI Response Card）
│   ├── B1. 英文主内容（native 版本，默认展示）
│   ├── B2. 翻译区（折叠，点击展开/收起）
│   ├── B3. 音频播放按钮（TTS 播放）
│   ├── B4. AI 追问（自然对话，嵌在卡片底部）
│   └── B5. "开始练习"入口（有可用素材时出现）
│
└── 模块C：输入区（Input Zone，固定在底部）
    ├── C1. 文本输入框
    ├── C2. 语音按钮（单击/长按触发 STT）
    ├── C3. 拍照按钮（调起系统相机）
    ├── C4. 相册按钮（调起系统相册）
    └── C5. 发送按钮
```

---

### 2.3 状态穷举（每个模块的所有状态）

#### 模块A：消息流区

| 状态名 | 触发条件 | 显示内容 |
|--------|----------|----------|
| 新用户空态 | 首次进入 App（0 条历史消息，前3次会话） | 欢迎文案 + 1-2 个可点击快捷示例 + 输入框 |
| 老用户空态 | 当天无消息，但已有历史记录 | 仅输入框，无快捷示例 |
| 有历史记录态 | 有过往消息 | 消息列表（向上滚动查看历史）+ 输入框在底部 |
| 生成中态 | 用户已发送，AI 未返回 | 用户消息气泡可见 + AI 回复卡片位置显示 loading skeleton |

> **关于"天分隔线"**：日期标签（如"今天 · 6月24日"）以淡色小文字显示在每天第一条消息上方，MVP 不做"高价值天特殊反馈"，留后续版本。

#### 模块B：AI 回复卡片

| 状态名 | 触发条件 | 显示内容 |
|--------|----------|----------|
| 生成中 | AI 请求发出，未返回 | Skeleton loading（骨架屏，占位动画） |
| 生成完成（基础） | AI 返回内容 | 英文主内容 + 播放按钮 + 翻译按钮（折叠）+ AI 追问 |
| 翻译展开 | 用户点击翻译按钮 | 英文主内容 + 中文翻译（并列或下方）+ 播放按钮 + AI 追问 |
| 翻译收起 | 用户再次点击翻译按钮 | 恢复基础态 |
| 音频加载中 | 用户点击播放，TTS 请求发出 | 播放按钮变为 loading 状态 |
| 音频播放中 | TTS 音频返回并开始播放 | 播放按钮变为暂停图标 + 进度指示 |
| 有可练习素材 | AI 已成功生成至少词汇层内容 | 卡片底部出现"开始练习"按钮 |
| 生成失败 | AI 请求超时或报错 | 错误提示文案 + 重试按钮（保留原始用户输入） |
| TTS 失败 | 音频加载失败 | 播放按钮恢复可点击态 + toast 提示"播放失败，点击重试" |

#### 模块C：输入区

| 状态名 | 触发条件 | 显示内容 |
|--------|----------|----------|
| 空闲态 | 无输入内容 | 占位灰字 + 语音/拍照/相册按钮可见，发送按钮灰色（不可点击） |
| 文字输入中 | 用户在输入框内打字 | 文字内容 + 发送按钮激活（蓝色/主题色） |
| 图片挂载态 | 用户选择图片后 | 输入框上方显示图片缩略图（带 X 删除按钮）+ 文字框可选填 + 发送按钮激活 |
| 语音录制中 | 用户长按麦克风 | 麦克风按钮变为录制中状态（动画） + 录音时长计时 + 松手发送/上划取消 |
| STT 处理中 | 用户松开麦克风，语音上传识别中 | 输入框显示"识别中…" |
| STT 完成 | 语音识别返回文字 | 文字填入输入框，用户可编辑，发送按钮激活 |
| 发送中 | 用户点击发送 | 输入区禁用（防止重复点击），内容清空 |
| STT 失败 | 语音识别失败 | Toast 提示"语音识别失败，请重试或直接输入文字"，输入框恢复空态 |

---

### 2.4 用户路径（用户视角）

#### 主路径：文字输入
```
进入 Tab1
  ↓
[新用户] 看到快捷示例 → 点击示例（自动填入输入框）→ 跳到"点击发送"
[老用户] 直接看到输入框
  ↓
在输入框打字（中文/英文/中英混）
  ↓
点击发送
  ↓
AI 生成中（skeleton loading）
  ↓
AI 回复卡片出现（英文内容 + 播放按钮 + 翻译按钮折叠 + AI 追问）
  ↓
用户可选择以下任意操作（不强制任何一步）：
  ├── 点击翻译按钮 → 中文翻译展开
  ├── 点击播放按钮 → 听 TTS 音频
  ├── 回复 AI 追问（继续输入）→ 进入下一轮对话
  └── 点击"开始练习" → 跳转 Tab2
```

#### 分支路径 1：语音输入
```
长按输入区麦克风按钮
  ↓
录音中（有录制动画反馈）
  ↓
松手 → STT 处理中 → 文字填入输入框
  ↓
用户可微调文字 → 点击发送 → 进入主路径
```

#### 分支路径 2：拍照输入
```
点击拍照按钮 → 系统相机打开
  ↓
拍摄照片 → 返回 App
  ↓
图片缩略图显示在输入框上方
  ↓
用户可选填文字（如"我在这里工作"）或直接发送
  ↓
点击发送 → 进入主路径（AI 同时解析图片+文字）
```

#### 分支路径 3：相册输入
```
点击相册按钮 → 系统相册打开（单选）
  ↓
选择图片 → 返回 App
  ↓
与拍照路径相同 → 进入主路径
```

---

## 三、Layer 4：信息流转

### 3.1 AI 卡片类型分类（产品核心逻辑）

这是 AI Prompt 的设计依据，也是数据结构的设计依据。详细卡片规范见《AI回复卡片需求设计_v1.md》。

**两层分类判断：语言 × 粒度**

| card_type | 语言判断 | 粒度判断 | 卡片名称 | 核心输出 |
|-----------|----------|----------|----------|----------|
| `s1` | 英文 | 单词/短语（不含谓语，不能独立成句） | 轻词典 | 音标 + 词性释义 + 双语例句 + scene_trigger |
| `s2` | 英文 | 句子/段落（含谓语，可独立成句） | 句子分析 | 中文译文 + 语法说明（有错误必出）+ 润色版（有错误必出）+ scene_trigger |
| `s3` | 中文 | 单词/短语（不含谓语） | 地道翻译 | 英文翻译 + 音标 + 双语例句 + scene_trigger |
| `s4` | 中文 | 句子/段落（含谓语） | 场景手帐 | 地道英译（主体）+ 中文原文（淡灰默认显示）+ 核心词组 + scene_trigger |
| `chat` | 任意 | 不属于以上（语法提问、开放提问等） | Chat 回复 | 纯文字对话气泡，无卡片结构，可附 scene 延伸 |

**粒度判断规则：** 能独立成句（有谓语）→ 句子级；否则 → 词/短语级。由 AI System Prompt 判断，不依赖词数阈值。

**语言判断规则：** 按用户表达意图判断，而非字符比例。"overtime是什么意思" → 意图是查 overtime → 英文 → s1。

**自指提取（预处理）：** "X怎么说" / "X是什么意思" → AI 提取 X 后再分类，X 存入 `extracted_concept` 字段。

**规则补充：**
- AI 始终先生成，不因信息不足而拒绝
- 追问（scene_trigger）是每种卡片的标配字段，引导用户联系自身场景
- 用户回复追问后，进入多轮对话模式，携带上一条消息上下文（见 5.2 多轮对话设计）

### 3.2 数据流向图

```
用户输入（文字/语音/图片）
  ↓
[Client: SwiftUI]
  把输入内容 + user_id + conversation_id 打包
  ↓
[Supabase Edge Function: generate-content]
  1. 验证用户 session
  2. 判断输入类型（文字/图片/混合）
  3. 拼装 Prompt（包含用户 Level、历史上下文摘要）
  4. 调用 AI Provider（GPT-4o / Claude / 待定）
  5. 接收流式返回（streaming）
  6. 把消息写入 Supabase DB（messages 表）
  7. 触发异步任务：materials 提取（不阻塞主流程）
  ↓
[Client: SwiftUI]
  接收流式内容，实时渲染 AI 回复卡片
  ↓
[异步，用户无感知]
  Supabase 后台任务从 message 中提取素材，写入 materials 表
  materials 表变更 → Tab2 实时更新（Supabase Realtime）
```

### 3.3 TTS 音频流向

**采用 iOS 系统 TTS（AVSpeechSynthesizer），免费、离线、无需 Edge Function。**

```
用户点击播放
  ↓
[Client] 从 card_content 中读取要播放的英文文本
  s1 → word + examples[0].en
  s2 → native_polish（有润色版则读润色版，否则读用户原句）
  s3 → example.en
  s4 → native_translation
  ↓
[AVSpeechSynthesizer] iOS 系统 TTS
  utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
  utterance.rate = 0.45（略慢于正常语速，便于学习）
  直接在设备端合成播放，无网络请求
  ↓
播放完毕。无音频存储，无 Storage 开销。
```

> **为什么不用云端 TTS：** 系统 TTS 对学习场景（慢速、清晰）足够好；云端 TTS 自然度更高但有延迟和成本，留作 v2 升级选项。

---

## 四、Layer 5：系统交互

### 4.1 主流程交互规范

#### 发送消息
| 动作 | 系统响应 | 状态变化 | 异常处理 |
|------|----------|----------|----------|
| 点击发送（有内容） | 立即：消息气泡出现 + 输入区清空禁用 + skeleton loading 出现 | 输入区→发送中；消息流→生成中态 | — |
| AI 内容流式返回 | 实时：文字逐渐填充 AI 回复卡片 | 消息流→有历史记录态 | — |
| AI 内容完整返回 | 卡片完整显示：英文内容 + 翻译按钮 + 播放按钮 + AI 追问 + "开始练习" | 输入区→空闲态（重新可用） | — |
| 点击发送（空输入框） | 无响应（发送按钮为灰色不可点） | 无变化 | — |
| 网络断开时发送 | Toast 提示"网络连接失败，内容已保存，请稍后重试"；用户消息气泡显示失败标记 | 消息状态→发送失败 | 失败气泡旁显示重试按钮 |
| AI 请求超时（>15s） | Toast 提示"AI 生成超时" + skeleton 消失 + 显示错误卡片 | 消息流→错误态 | 错误卡片内有"重试"按钮，点击重新调用，保留原始输入 |

#### 翻译功能
| 动作 | 系统响应 | 状态变化 |
|------|----------|----------|
| 点击翻译按钮（首次） | 如已缓存→直接展开；未缓存→短暂 loading（<1s）→展开 | 翻译按钮文案变为"收起翻译"，中文内容显示 |
| 点击翻译按钮（收起） | 中文内容折叠 | 翻译按钮文案恢复 |

> **注**：翻译在 AI 生成阶段一并返回，存入 DB，不需要二次调用。点击"展开"只是 UI 状态变化，不触发网络请求。

#### 语音输入
| 动作 | 系统响应 | 状态变化 | 异常处理 |
|------|----------|----------|----------|
| 长按麦克风 | 麦克风按钮动画 + 录音计时开始 | 输入区→语音录制中 | 首次使用：系统弹出麦克风权限请求 |
| 松开麦克风 | "识别中…"填入输入框 + STT 请求发出 | 输入区→STT 处理中 | — |
| STT 成功返回 | 文字填入输入框，"识别中…"替换，光标置末尾 | 输入区→文字输入中（可编辑） | — |
| STT 失败 | Toast "语音识别失败，请重试" + 输入框清空 | 输入区→空闲态 | — |
| 上划取消（录制中） | 录音终止，不发送 | 输入区→空闲态 | — |
| 未授权麦克风 | Alert 提示"需要麦克风权限"+ 跳转系统设置按钮 | — | — |

#### 图片输入（拍照/相册）
| 动作 | 系统响应 | 状态变化 | 异常处理 |
|------|----------|----------|----------|
| 点击拍照按钮 | 系统相机打开 | — | 未授权相机：Alert + 跳转设置 |
| 拍照完成/取消 | 完成→图片缩略图出现在输入框上方；取消→无变化 | 完成→输入区→图片挂载态 | — |
| 点击相册按钮 | 系统相册打开（单选） | — | 未授权相册：Alert + 跳转设置 |
| 图片 X 按钮 | 图片缩略图消失，输入区恢复 | 输入区→文字输入中（或空闲态） | — |
| 图片过大（>10MB） | Toast "图片过大，请选择较小的图片" | 图片不挂载 | — |
| 发送图片（无文字） | 可直接发送，AI 仅根据图片生成内容 | 同正常发送流程 | — |

#### 音频播放
| 动作 | 系统响应 | 状态变化 | 异常处理 |
|------|----------|----------|----------|
| 点击播放（无缓存音频） | 播放按钮 loading → TTS 生成 → 开始播放 | 按钮→播放中（暂停图标） | TTS 失败：Toast "播放失败" + 按钮恢复可点击 |
| 点击播放（有缓存音频） | 立即播放 | 按钮→播放中 | — |
| 点击暂停 | 暂停播放 | 按钮→可点击播放图标 | — |
| 播放完毕 | 自动停止 | 按钮→恢复初始播放图标 | — |
| 点击另一条消息的播放 | 当前音频暂停，新音频开始播放 | 同上 | — |

#### 快捷示例（新用户）
| 动作 | 系统响应 | 状态变化 |
|------|----------|----------|
| 点击快捷示例 | 示例文字填入输入框（不自动发送，用户可修改） | 输入区→文字输入中，发送按钮激活 |
| 前 3 次会话后 | 快捷示例不再显示 | 进入老用户态 |

### 4.2 错误与边界处理总览

| 场景 | 响应策略 | 原则 |
|------|----------|------|
| 网络断开 | 保留输入内容，提示重试，不丢数据 | 用户内容永远不丢 |
| AI 生成超时 | 保留原始输入，显示错误卡片+重试 | 给出路，不死路 |
| AI 内容不完整返回 | 显示已返回的部分，标注"生成不完整" + 重试 | 有多少显多少 |
| 图片解析失败 | Toast 提示，保留用户文字输入 | 降级处理，不全盘失败 |
| STT 失败 | Toast 提示，输入框清空，用户自行输入 | 降级到文字输入 |
| TTS 失败 | Toast 提示，文字内容不受影响 | 音频是增强，非必须 |
| 麦克风/相机未授权 | 系统 Alert + "去设置"按钮 | 标准 iOS 权限引导 |
| 首次进入 App 无网络 | 显示空态 + "无网络连接"提示，功能暂不可用 | 清晰说明，不假装正常 |

---

## 五、Supabase 数据库设计

> Supabase 是什么：把 PostgreSQL 数据库 + 用户认证 + 文件存储 + 后端函数打包在一起的服务，类似"后端全家桶"。你只需要在 Supabase 控制台点几下就能建表，Claude Code 负责写查询代码。

### 5.1 表结构设计

#### 表1：`users`（用户信息）

| 字段名 | 类型 | 说明 | 示例值 |
|--------|------|------|--------|
| `id` | uuid | 主键，用户唯一标识（Supabase Auth 自动生成） | `a1b2c3...` |
| `english_level` | text | CEFR 级别，引导页用户选择 | `'B1'` |
| `reply_style` | text | AI 风格，MVP 固定 `native_buddy` | `'native_buddy'` |
| `onboarding_completed_at` | timestamp | 引导页完成时间（null = 未完成） | `2026-06-24 10:00:00` |
| `session_count` | integer | 累计会话数，用于控制新用户态显示 | `3` |
| `created_at` | timestamp | 注册时间，自动填充 | `2026-06-24 09:00:00` |

**预留字段（MVP 不启用，但建表时就加上）：**

| 字段名 | 类型 | 预留用途 |
|--------|------|----------|
| `learning_goal` | text | 学习目标（business_networking 等） |
| `interest_tags` | text[] | 兴趣标签数组（["coding", "coffee"]） |
| `native_language` | text | 母语（zh_CN），用于中式英语纠错 |

---

#### 表2：`conversations`（会话）

每一天的聊天是一个 conversation，或每次打开 App 为新 conversation（待定，MVP 按天分）。

| 字段名 | 类型 | 说明 | 示例值 |
|--------|------|------|--------|
| `id` | uuid | 主键 | — |
| `user_id` | uuid | 关联 users 表 | — |
| `session_date` | date | 会话日期（用于 Tab1 的按天分组） | `2026-06-24` |
| `created_at` | timestamp | 自动填充 | — |

---

#### 表3：`messages`（消息，核心表）

| 字段名 | 类型 | 说明 | 示例值 |
|--------|------|------|--------|
| `id` | uuid | 主键 | — |
| `conversation_id` | uuid | 关联 conversations 表 | — |
| `user_id` | uuid | 关联 users 表（方便直接查询） | — |
| `role` | text | 消息来源：`'user'` 或 `'assistant'` | `'assistant'` |
| `input_type` | text | 用户输入类型：`'text'` / `'voice'` / `'camera'` / `'album'`（role=user 时有值） | `'text'` |
| `user_content` | text | 用户输入的原始文字或 STT 转写结果（role=user 时有值） | `'overtime'` |
| `extracted_concept` | text | AI 预处理提取的核心概念（自指消除结果，如"摸鱼英文怎么说" → `'摸鱼'`） | `'overtime'` |
| `card_type` | text | 卡片类型：`'s1'`/`'s2'`/`'s3'`/`'s4'`/`'chat'`（role=user 时为 null） | `'s1'` |
| `card_content` | jsonb | 卡片数据，结构因 card_type 不同而不同（role=user 时为 null，见下方 schema） | `{ "word": "overtime", ... }` |
| `parent_message_id` | uuid | 追问时指向上一条 AI 消息 ID；null 表示全新话题 | — |
| `status` | text | 消息状态：`'sending'` / `'delivered'` / `'failed'` | `'delivered'` |
| `created_at` | timestamp | 自动填充 | — |

**字段设计说明：**
- `user` 行：`user_content` 有值，`card_type` 和 `card_content` 为 null
- `assistant` 行：`card_type` + `card_content` 有值，`user_content` 为 null
- `card_type` 是钥匙，告诉前端用哪个 SwiftUI View；`card_content` 是数据，填入对应 View 的字段

---

**`card_content` 各卡片类型的 JSON Schema：**

**s1（轻词典）：**
```json
{
  "word": "overtime",
  "phonetic": "/ˈoʊvərtaɪm/",
  "pos": "n.",
  "definition": "加班",
  "examples": [
    { "en": "I have to work overtime tonight.", "zh": "我今晚又要加班了。" }
  ],
  "scene_trigger": "You mentioned staying late — sounds familiar. When does overtime usually hit you?"
}
```

**s2（句子分析）：**
```json
{
  "chinese_translation": "我今晚又要加班了。",
  "grammar_analysis": "注意 'have to' 表示外力强迫，比 'must' 更口语。",
  "native_polish": "I'm stuck at the office again tonight.",
  "key_phrase": { "phrase": "stuck at the office", "note": "比 'work overtime' 更地道的口语说法" },
  "scene_trigger": "Late nights at the office — is this a one-time thing or a pattern?"
}
```
> `grammar_analysis`：有错误必出；无错误但有值得讲的可出；简单正确则 null。  
> `native_polish`：仅在有语法错误时出现；原句已地道则 null。  
> `key_phrase`：可选。

**s3（地道翻译）：**
```json
{
  "chinese_concept": "摸鱼",
  "english_translation": "slack off",
  "phonetic": "/slæk ɔːf/",
  "pos": "v.",
  "example": {
    "en": "I've been slacking off all afternoon and now I'm behind.",
    "zh": "我摸了一下午鱼，现在进度落后了。"
  },
  "scene_trigger": "We all have those days. What were you supposed to be doing instead?"
}
```

**s4（场景手帐）：**
```json
{
  "chinese_original": "今天地铁挤死了。",
  "native_translation": "The subway was absolutely packed this morning.",
  "key_phrase": { "phrase": "absolutely packed", "note": "比 'very crowded' 更有力的表达" },
  "scene_trigger": "Packed commutes are the worst. Do you deal with this every day?"
}
```

**chat（对话气泡）：**
```json
{
  "text": "Great question! 'Would' and 'could' are both modal verbs, but...",
  "scene_connection": "By the way, if you ever want to use this in a real sentence, just tell me the situation!"
}
```
> `scene_connection` 可选，用于把 chat 回复引回用户场景。

---

#### 表4：`materials`（学习素材，Tab1→Tab2 的桥梁）

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `id` | uuid | 主键 |
| `user_id` | uuid | 关联 users 表 |
| `source_message_id` | uuid | 从哪条 AI 消息提取（关联 messages 表）|
| `material_type` | text | `'scene'`（有场景上下文）/ `'vocabulary'`（仅词汇层）|
| `status` | text | `'pending'`（刚提取）/ `'categorized'`（已分类进 Tab2）|
| `scene_category` | text | Tab2 场景分类（AI 在固定选项内分配），`material_type='scene'` 时有值 |
| `raw_content` | jsonb | 提取出的素材内容（结构化 JSON，包含词汇/句子/段落）|
| `related_material_ids` | uuid[] | **预留关联字段**：关联的其他素材 ID（MVP 存但不展示）|
| `created_at` | timestamp | 自动填充 |

**`raw_content` 的 JSON 结构示例（sentence 深度）：**
```json
{
  "english": "Two coffees in and I'm still not human.",
  "translation": "喝了两杯咖啡了还是不在状态。",
  "vocab_highlights": [
    { "word": "Two coffees in", "note": "口语表达，表示'已经喝了两杯'" }
  ],
  "pronunciation_tip": "注意 'human' 的重音在第一个音节"
}
```

---

### 5.2 Edge Functions 设计（后端函数）

> Edge Function 是运行在 Supabase 服务器上的代码，相当于你的"后端 API"。手机 App 不直接调 AI，而是调 Edge Function，Edge Function 再去调 AI，这样 AI 的密钥永远不会暴露在手机里。

#### Function 1：`generate-content`

**触发**：用户点击发送  
**输入**：`{ user_id, conversation_id, user_content, input_type, parent_message_id? }`  
**执行步骤**：
1. 验证用户 session
2. 读取用户 `english_level`（决定措辞难度）
3. **多轮上下文注入**：若 `parent_message_id` 不为 null，从 DB 读取那一行（只读 1 条），提取 `card_type + card_content + extracted_concept`，构建上下文摘要注入 System Prompt（见下方多轮对话设计）
4. 拼装完整 Prompt（AI 人设 + 卡片分类规则 + 上下文摘要 + 当前输入）
5. 调用 AI Provider（streaming 模式）
6. 流式返回给 Client
7. 完整内容返回后，解析 AI 输出 → 确定 `card_type` 和 `card_content` JSON → 写入 `messages` 表（同时写 `extracted_concept`）
8. 触发异步素材提取（不阻塞主流程）

**输出（流式）**：`{ card_type, card_content（流式填充）}`

---

#### ~~Function 2：`get-tts`~~（已移除）

> TTS 改用 iOS 系统 AVSpeechSynthesizer，完全在客户端完成，无需 Edge Function。见 3.3。

---

#### Function 2（原 Function 3）：`extract-materials`（异步）

**触发**：`generate-content` 完成后自动触发（用户无感知）  
**输入**：`{ message_id }`  
**执行步骤**：
1. 读取消息的 `card_type` 和 `card_content`
2. 根据 `card_type` 决定提取策略：
   - `s1`：提取词汇条目（word + phonetic + examples）
   - `s2`：提取句子分析（native_polish 或原句 + grammar_analysis）
   - `s3`：提取词汇条目（english_translation + example）
   - `s4`：提取场景句子（native_translation + key_phrase）
   - `chat`：不提取（无结构化素材）
3. 调用 AI（轻量模型）做 Tab2 场景分类（固定选项内）
4. 写入 `materials` 表（`status = 'pending'`，Tab2 实时可见）

---

#### 多轮对话设计（Function 1 的核心逻辑）

**何时触发多轮：** iOS 端用户点击卡片内"追问"按钮时，携带该卡片的 `message_id` 作为 `parent_message_id` 发送。直接在底部输入框打字则 `parent_message_id = null`（新话题）。

**上下文注入策略（只带最近 1 条）：**

```
if parent_message_id is not null:
    parent = SELECT card_type, card_content, extracted_concept
             FROM messages WHERE id = parent_message_id

    context_summary = 根据 card_type 拼装：
      s1 → "上一轮：用户查询了英文单词 {extracted_concept}，
             卡片内容：{word} {phonetic} {definition}，例句：{examples[0].en}"
      s2 → "上一轮：用户输入了英文句子，润色版：{native_polish}"
      s3 → "上一轮：用户查询了中文词 {extracted_concept}，
             英文翻译：{english_translation}，例句：{example.en}"
      s4 → "上一轮：用户输入了中文句子，英文翻译：{native_translation}"
      chat → "上一轮：{text 前 100 字}"

    注入位置：System Prompt 末尾，格式：
    "[Previous context]\n{context_summary}\n\nIf the user's input
    is a follow-up to the above, use this context. Otherwise, treat
    it as a new topic."
```

**为什么只带 1 条：** 绝大多数追问是"就这个词/句再说一点"，1 条已够。完整多轮历史留 v2。

---

### 5.3 埋点事件设计（数据分析）

> 埋点是"记录用户做了什么"的机制。每次用户触发特定行为，App 就往后台发一条记录。MVP 推荐直接用 Supabase 的 `analytics_events` 表自建轻量埋点，无需额外引入第三方（省成本）。

#### 埋点表：`analytics_events`

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `id` | uuid | 主键 |
| `user_id` | uuid | 关联 users |
| `event_name` | text | 事件名（见下方清单）|
| `properties` | jsonb | 事件附加属性（每个事件不同）|
| `created_at` | timestamp | 事件发生时间 |

#### Tab1 核心埋点事件清单

| 事件名 | 触发时机 | 附加属性 |
|--------|----------|----------|
| `session_started` | 每次打开 Tab1 | `{ is_new_user: bool, session_count: int }` |
| `input_submitted` | 用户点击发送 | `{ input_type: 'text'|'voice'|'camera'|'album', has_text: bool, has_image: bool, text_length: int }` |
| `ai_response_received` | AI 内容完整返回 | `{ message_id, card_type: 's1'|'s2'|'s3'|'s4'|'chat', latency_ms: int }` |
| `translation_tapped` | 用户点击展开翻译 | `{ message_id, card_type }` |
| `audio_played` | 用户点击播放 | `{ message_id }` |
| `audio_play_failed` | TTS 失败 | `{ message_id, error_type }` |
| `followup_submitted` | 用户回复 AI 追问 | `{ parent_message_id, card_type }` |
| `practice_button_tapped` | 用户点击"开始练习" | `{ message_id, card_type }` |
| `quick_example_tapped` | 新用户点击快捷示例 | `{ example_index: 0|1 }` |
| `generation_failed` | AI 生成失败 | `{ error_type, input_type }` |
| `retry_tapped` | 用户点击重试 | `{ message_id, retry_reason }` |
| `onboarding_completed` | 引导页完成 | `{ english_level }` |

**这些数据能告诉你什么：**
- `audio_played / ai_response_received` 的比率 → 用户是否重视发音练习
- `followup_submitted / ai_response_received` 的比率 → 追问机制是否在发挥作用
- `practice_button_tapped / ai_response_received` 的比率 → 从 Tab1 进入练习的转化
- `card_type` 分布 → 用户最常输入的类型（s1/s2/s3/s4/chat 各占比，指导 Prompt 优化方向）
- `latency_ms` → AI 响应速度，定位性能问题

---

## 六、给 Claude Code 的垂直切片开发计划

> **垂直切片原则**：每个切片都是"前端 + 后端都跑通"的完整链路，不是只建 UI 骨架或只写 DB 表。每个切片完成后都能在真机上看到效果、测试行为。

### Slice 0（准备）：Supabase 项目初始化

```
任务：
1. 在 Supabase 控制台创建项目
2. 创建 users / conversations / messages / materials / analytics_events 这 5 张表（按上方字段完整建表）
3. 设置 Row Level Security（RLS）：每个用户只能读写自己的数据
4. 生成 Supabase URL 和 anon key，写入 Xcode 的 .xcconfig 文件（不硬编码在代码里）

验收标准：
- Supabase 控制台可以看到 5 张表
- 从 Xcode 可以连接到 Supabase（用 SDK 读取 users 表不报错）
```

### Slice 1（核心主链路）：文字输入 → AI 生成 → 显示英文内容

```
任务：
前端：
- Tab1 基础页面框架（NavigationStack + TabView）
- 底部输入框（仅文字，暂不做语音/图片）
- 发送按钮（有内容时激活）
- 消息气泡（用户消息 + AI 回复卡片）
- Skeleton loading 动画

后端：
- Edge Function: generate-content（支持文字输入，暂不做图片）
- AI Prompt：native buddy 人设 + 5种卡片分类规则（s1/s2/s3/s4/chat）
- messages 表写入（card_type + card_content）

验收标准：
- 在真机上打字并发送，能看到对应类型的 AI 回复卡片
- 消息存入 Supabase messages 表，card_type 和 card_content 字段有值
- AI 密钥不出现在 Swift 代码中任何地方
```

### Slice 2：翻译功能

```
任务：
前端：
- AI 回复卡片增加翻译按钮（折叠/展开状态）
- 展开动画（smooth expand）

后端：
- generate-content Edge Function 增加 ai_translation 字段的返回
- 翻译内容写入 messages 表

验收标准：
- 默认折叠，点击"显示翻译"展开，再点收起
- 翻译内容来自 messages 表，不额外调用 AI
```

### Slice 3：TTS 音频播放（iOS 系统 TTS）

```
任务：
前端：
- AI 回复卡片增加播放按钮
- 播放中 / 暂停 / 完毕 状态切换
- 集成 AVSpeechSynthesizer：
    let utterance = AVSpeechUtterance(string: textToSpeak)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = 0.45
    AVSpeechSynthesizer().speak(utterance)
- 根据 card_type 决定朗读哪段文字：
    s1 → word
    s2 → native_polish（无则读原句）
    s3 → example.en
    s4 → native_translation

后端：无（纯客户端方案，无 Edge Function，无 Storage）

验收标准：
- 点击播放能听到对应英文内容的朗读（系统英文女声/男声）
- 播放中点击暂停，暂停后可继续播放
- 无网络时播放仍正常（离线可用）
```

### Slice 4：语音输入（STT）

```
任务：
前端：
- 麦克风按钮（长按录音 / 松手停止）
- 录制中动画
- STT 结果填入输入框

后端：
- Edge Function 或直接调用 Whisper API（通过 Edge Function 代理）

验收标准：
- 长按麦克风说中文，松手后文字出现在输入框，可发送
```

### Slice 5：图片输入（拍照 + 相册）

```
任务：
前端：
- 拍照按钮 + 相册按钮
- 图片缩略图显示 + X 删除
- 图片 + 文字一起发送

后端：
- generate-content Edge Function 支持图片（上传到 Storage + 传给 AI 多模态接口）

验收标准：
- 拍一张图，发送，AI 能根据图片内容生成英文场景描述
```

### Slice 6：新用户态 / 老用户态切换

```
任务：
前端：
- 判断 session_count <= 3 → 显示快捷示例
- 快捷示例点击 → 填入输入框
- session_count > 3 → 快捷示例不显示

后端：
- 每次创建 conversation 时，users 表 session_count +1

验收标准：
- 前 3 次打开 Tab1 看到快捷示例
- 第 4 次开始不显示
```

### Slice 7：历史消息 + Tab1→Tab2 素材流转

```
任务：
前端：
- 向上滚动可查看历史消息
- 日期分隔线（"今天 · 6月24日"）

后端：
- extract-materials Edge Function
- materials 表写入
- Supabase Realtime 推送变更到 Tab2（为 Tab2 开发做准备）

验收标准：
- 重新打开 App，Tab1 能看到昨天的消息记录
- 发送一条消息后，materials 表有新记录（Supabase 控制台可验证）
```

---

## 七、断点确认（需要你来拍板）

在进入 Layer 6（视觉设计）和动手开发之前，需要你确认以下几点：

**功能结构确认：**
- [ ] 4 个输入入口（文字/语音/拍照/相册）的优先级和 UI 排布是否有倾向？（比如语音是否比拍照更重要，决定按钮位置）
- [ ] AI 追问是嵌在 AI 回复卡片里（视觉上是卡片的一部分），还是作为独立消息气泡出现？
- [ ] "开始练习"按钮是每条 AI 回复都有，还是只在"完整素材包"深度时出现？

**AI 生成确认：**
- [ ] 生成深度的 3 个级别（词汇/句子/完整素材包），是否需要给用户任何视觉区分？还是用户无需感知，直接看内容即可？

**数据库确认：**
- [ ] `session_count` 控制新用户态的阈值，目前设为 3（前3次会话显示快捷示例），是否合适？

---

*文档版本：v1.1 | 更新日期：2026-07-01 | 主要变更：卡片类型分类（s1/s2/s3/s4/chat）替换生成深度、messages 表重构（card_content JSONB）、TTS 改为 iOS 系统方案、新增多轮对话设计 | 下一步：Layer 6 视觉设计（需设计工具支撑）*
