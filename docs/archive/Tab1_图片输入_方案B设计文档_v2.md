# Tab1 图片输入（方案B）设计文档 v2

> 整理于 2026-07-04，v2 更新：D1/D2/D3 决策已定

---

## 一、方案B 是什么

用户可以通过拍照或相册选图的方式向 Tab1 发送内容。图片发送时，用户可以同时填写文字说明，也可以不填（仅发图片）。AI 同时接收图片和文字（如有），生成对应的英文学习卡片。

---

## 二、现有输入链路（文字输入，已上线）

### 2.1 前端链路

```
用户在 InputBar 打字
  ↓
文字非空 → 发送按钮激活
  ↓
点击发送 → TodayViewModel.send(_ text: String)
  ↓
消息流追加一条用户气泡（文字，右对齐）
  ↓
调用 LiveAIService.generate(text: String)
  → POST /functions/v1/generate  body: { "text": "用户输入" }
  ↓
等待返回 → 消息流追加一条 AI 卡片
```

**涉及文件：**

| 文件 | 职责 |
|------|------|
| `Today/Components/InputBar.swift` | 文字输入框 + 发送按钮 |
| `Today/TodayViewModel.swift` | 消息列表状态管理 + 调用 AIService |
| `Services/AIService.swift` | HTTP 请求封装（目前有两个独立方法：text / image） |
| `Models/Message.swift` | TimelineEntry 数据结构（userBubble / aiCard / aiError） |

### 2.2 AI 生成链路（后端 Edge Function）

```
Edge Function (generate/index.ts) 收到请求
  ↓
解析 body：{ text?, image_base64?, mime_type? }
  ↓
构建发给 Gemini 的内容：
  有 image_base64 → 图片 + 固定描述 prompt（用户文字被忽略）
  只有 text      → 用户原始文字
  ↓
调用 Gemini 2.5 Flash（带 SYSTEM_PROMPT）
  SYSTEM_PROMPT 定义了 5 种卡片分类规则（s1/s2/s3/s4/chat）
  ↓
解析 AI 返回的 JSON → { card_type, card_content, extracted_concept }
  ↓
并行写 DB：
  messages 表写两行（user + assistant）
  saveMaterial() → 提取素材写入 materials 表
  ↓
返回 { card_type, card_content, extracted_concept } 给 App
```

### 2.3 现有 AIService 接口

```swift
// 两个独立方法，互不关联

func generate(text: String) async throws -> AIEnvelope
// → body: { "text": "..." }

func generate(image: UIImage) async throws -> AIEnvelope
// → body: { "image_base64": "...", "mime_type": "image/jpeg" }
// 没有文字参数
```

---

## 三、方案B 涉及的改动范围

### 3.1 后端 Edge Function

**现有问题：** 当请求中包含 `image_base64` 时，`text` 字段被完全忽略，AI 收到的是硬编码的固定 prompt，而不是用户的文字说明。需要修改为：当图片和文字同时存在时，两者都传给 AI。

**需要改动的逻辑：**
- 图片 + 文字同时存在时的 prompt 拼接方式
- `messages` 表 `input_type` 字段：当前只有 `"text"` / `"image"`，混合发送时建议新增 `"image_text"`（待确认，见文末「待讨论」）

**D5 决策落地：分支逻辑改为三条路径，而不是两条**

```
Edge Function 收到 { text?, image_base64? }
  ↓
判断：
├─ 只有 text，没有 image
│    → 沿用现有逻辑：按文字的语言(中/英)×颗粒度(词/句)分类进 s1/s2/s3/s4
│
├─ 只有 image，没有 text（D3/D4）
│    → 固定走 s4，chinese_original 填 null，新增 ai_scene_guess 字段承载AI看图的场景猜测
│
└─ image 和 text 都有（D5，新定）
     → 分类逻辑跟"只有text"完全一样：按用户打的这段文字的语言×颗粒度分类进 s1/s2/s3/s4
     → 图片只作为额外上下文传给AI，让 native_translation/scene_trigger 等字段生成得更贴合实际场景
     → chinese_original 正常填用户打的字（不是 null）
     → 卡片 schema 不变，复用 s1-s4 已有字段，不新增字段
```

**关键澄清：图文混合不等于固定 s4。** 分类只看用户打的文字，跟有没有配图无关。只有"纯图片、完全不打字"才固定归 s4（因为没有文字可判断语言和颗粒度）。举例（同一张咖啡杯照片）：

| 用户打的文字 | 分类 | 说明 |
|---|---|---|
| 「咖啡」 | s3 | 中文单词 → 地道翻译 |
| 「Coffee」 | s1 | 英文单词 → 查词 |
| 一句英文句子 | s2 | 语法润色纠错 |
| 一句中文长句/吐槽 | s4 | 场景手帐 |
| （不打字，仅发图） | s4（固定） | D3/D4：无文字可判断，默认场景手帐 |

图片的作用始终是"让生成内容更准"，不改变分类结果。

**D3 决策落地：** 仅发图片、无文字时，沿用现有 s4（场景手帐）分类逻辑，不新增专门的 prompt 分支。Prompt 层面需确保：没有用户文字时，AI 仍先给出对图片场景的描述 + 死党式追问，引导用户后续补一句话（符合主PRD"先给答案，再追问"原则）。

**D4 决策落地：** 纯图片输入时，s4 卡片的 `chinese_original` 字段必须保持 `null`，不得把 AI 对图片的场景猜测填进这个字段——`chinese_original` 语义上代表"用户自己说出口的原话"，混入 AI 猜测会破坏主PRD"AI生成的 ≠ 用户说出来的"这条核心原则，影响后续 Tab2 素材可信度判断。

新增字段 `ai_scene_guess`：专门承载 AI 看图猜测的场景描述，与 `chinese_original` 语义上明确区分开。

```json
{
  "chinese_original": null,
  "ai_scene_guess": "一杯咖啡放在办公桌上",
  "native_translation": "...",
  "key_phrase": "...",
  "scene_trigger": "..."
}
```

### 3.2 前端 AIService

当前是两个独立方法，需要合并为一个支持混合输入的接口：
```swift
generate(text: String?, image: UIImage?) async throws -> AIEnvelope
```

### 3.3 前端 TodayViewModel

- 新增图片状态（当前 ViewModel 里没有 image 相关状态）
- `send()` 方法需要支持携带图片参数

### 3.4 前端 InputBar

**D1 决策落地：** 拍照、相册按钮与文字框、发送（以及后续语音）**平铺**在输入栏内，不做「+」收起。理由：拍照/相册是与文字并列的输入入口，主PRD的 Page1 UI 稿也是平铺样式；MVP 阶段按钮数量不多，折叠反而多一次点击。

- 新增拍照按钮和相册按钮，与文字框、发送按钮平铺同一行
- 用户选图后，输入框区域显示图片缩略图 + 删除（×）按钮
- 图片挂载后发送按钮激活（不需要填文字也可发送）

### 3.5 前端 TimelineEntry（用户气泡）

**D2 决策落地：** 图片和文字**分开两行**展示，但仍属于同一条消息（同一个 TimelineEntry / 同一次 `send()` 调用），不拆成两条独立的 message 记录。

```swift
// 原：
case userBubble(text: String)

// 改为：
case userBubble(text: String?, image: UIImage?)
```

渲染层用一个右对齐的 VStack：
- `image` 非空 → 先渲染图片卡片（独立圆角背景）
- `text` 非空 → 下方再渲染文字气泡（独立圆角背景），二者留出间距

两个视觉模块共享同一个 entry id，删除/长按等操作作用于整条消息，不会出现图片和文字状态不同步的问题。

> 待细化：若未来要支持"只删图片保留文字"这类单模块编辑，可在图片卡片上加独立删除角标，暂不需要现在拆数据结构（见文末「待讨论」第1条）。

### 3.6 客户端图片压缩与格式转码

**现有问题：** 原文档只有"超过10MB拒绝"的被动校验，没有主动压缩；且未处理 HEIC 等非 JPEG 格式，与后端 `mime_type: "image/jpeg"` 的假设不符。

**改动为：**
1. **统一转码**：不论原图是 HEIC / PNG / 其他格式，选图后一律转成 JPEG 再上传。
2. **主动压缩**：长边 resize 到约 1600px，JPEG quality 约 0.75（具体数值待结合AI识别效果与卡片视觉需求微调）。压缩后基本不会再超过10MB。
3. **10MB 校验降级为兜底**：仅用于压缩流程异常等极端情况，正常路径下不会触发 Toast。
4. **Live Photo**：仅取静态封面帧，不处理动态部分。

> 补充说明：多模态模型（Gemini）内部也会对输入图片做 resize，传原图分辨率除了浪费带宽，也会增加图片 token 消耗、拉高调用成本，压缩参数同时是个成本控制点。

### 3.7 权限处理

**D6 决策落地：相册选图改用 `PHPickerViewController`（iOS 14+），不再走传统相册权限申请。**

理由：`PHPickerViewController` 运行在系统沙盒中，用户选完图片后系统只把被选中的那张传给 App，App 全程不接触相册库的其他内容，因此不需要 `NSPhotoLibraryUsageDescription` 权限弹窗。开发时间是2026年，iOS 14已发布6年，实际在架设备里低于iOS 14的占比可忽略不计，无需为老系统写兼容分支。

| 权限 | 触发时机 | 拒绝后处理 |
|------|---------|-----------|
| 相机权限 | 首次点击拍照按钮 | 客户端检测到 `.denied` 状态后，弹自定义提示 + "去设置"按钮，跳转 `UIApplication.openSettingsURLString` |
| 相册权限 | 不需要（改用 PHPicker，见上） | 不适用 |

Onboarding 流程中已有相机权限相关代码（`CameraPickerView.swift`），Tab1 可复用（拒绝后的引导提示逻辑也可一并复用）。

---

## 四、已决策事项

| 决策点 | 结论 | 理由摘要 |
|--------|------|----------|
| D1 输入栏按钮布局 | 平铺，不做「+」收起 | 与主PRD既有UI稿一致；拍照/相册是并列主入口，不应降级为次要操作 |
| D2 用户消息气泡样式 | 分开两行，但同属一条 message | 匹配主流AI产品/IM的视觉习惯；数据模型仍是"一次发送=一条消息"，避免图文状态不同步 |
| D3 纯图片输入的AI卡片行为 | 复用现有 s4（场景手帐）逻辑 | MVP 从简，开发量最小；AI 仍先给答案再追问引导用户补文字 |
| D4 纯图片场景 s4 字段调整 | 新增 `ai_scene_guess` 字段，`chinese_original` 保持 null | 避免AI猜测冒充"用户说出来的话"，守住素材可信度判断的根基原则 |
| D5 图文混合输入的分类与卡片结构 | 分类仍按文字的语言×颗粒度走 s1/s2/s3/s4，图片只做生成时的上下文增强，不新增卡片类型/字段 | 复用现有分类逻辑，改动范围收敛在 Edge Function 的 prompt 组装上，不影响输出 schema |
| D6 相册选图技术方案 | 改用 `PHPickerViewController`（iOS 14+），不申请相册权限 | 系统沙盒隔离，用户体验更好；2026年开发，老系统占比可忽略，无兼容顾虑 |

---

## 五、待讨论事项（不阻塞开发，后续细化）

1. **单模块编辑颗粒度**：图片+文字分两行展示后，是否需要支持"只删图片保留文字"或反之。暂不做，先记录。

2. **`input_type` 混合态记录方案（开发时二选一，见下）**

3. **纯图片输入的追问 prompt 细节**：s4 逻辑复用后，追问文案是否需要专门针对"无用户文字"的情况做区分（比如更明确地引导用户补一句话），待写 prompt 时细化。

---

### 5.1 `input_type` 混合态记录方案（Plan A / Plan B）

**背景**：`messages` 表目前 `input_type` 只有 `"text"` / `"image"` 两个取值。方案B之后一条消息可能同时带图片和文字，这个混合态需要在数据库里有个说法——否则任何依赖 `input_type` 做筛选的下游逻辑（统计报表、AI 训练数据抽取脚本等）都可能漏掉这批新消息，或把它们误判成纯文字/纯图片。

本文档写作时未接触实际后端/数据管道代码，无法确认现有下游逻辑对这个字段的具体依赖方式，因此给出两个方案，开发时对照实际代码库选定：

**方案A：新增枚举值 `"image_text"`**
- `input_type` 变成三态：`text` / `image` / `image_text`
- 优点：最直观，查这一个字段就能看出消息形态
- 需要检查：所有 `WHERE input_type = 'image'` / `= 'text'` 的下游查询、报表、训练数据脚本，是否要同步加上 `image_text` 分支（否则混合消息会被两边都漏掉）
- 若数据库层对该字段做了 enum 约束，新增值需要一次 migration

**方案B：`input_type` 保留两个取值不变，混合态由字段组合判断**
- 不新增枚举值；是否图文混合，直接看 `text` 字段和 `image_url` 字段是否同时非空
- `input_type` 可继续按"主要形态"打标（比如有图就填 `image`），或逐步废弃该字段，全部改成判断字段是否为空
- 优点：不引入新枚举值，不用担心某处遍历枚举分支时遗漏新值
- 需要检查：是否有下游代码"只认 input_type 这一个字段"做判断、而不去看实际字段是否为空——如果有，仍需改动

两个方案都要求开发时确认现有下游依赖，因此暂不选定，留到接触实际 `messages` 表结构和下游脚本时再定。

---

*方案C（圈选区域）已记录，决定推迟到 v2 之后*
