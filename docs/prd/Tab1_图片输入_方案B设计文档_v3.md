# Tab1 图片输入（方案B）设计文档 v3

> 整理于 2026-07-04
> v3 更新：对照项目 `CLAUDE.md` 校正技术细节（iOS版本、英文UI文案、`@Observable`），并按"纵向切片"重新组织开发顺序

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

> 注：这里的 Gemini 2.5 Flash 是**当前已上线的实现**，不代表 AI 服务商已最终锁定——项目 `CLAUDE.md` 里明确写了"AI content generation provider: TBD，需先测试不同方案成本再定"。方案B的改动不涉及换供应商，按现状（Gemini）设计即可，供应商决策是另一条独立的待办。

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
└─ image 和 text 都有（D5）
     → 分类逻辑跟"只有text"完全一样：按用户打的这段文字的语言×颗粒度分类进 s1/s2/s3/s4
     → 图片只作为额外上下文传给AI，让 native_translation/scene_trigger 等字段生成得更贴合实际场景
     → chinese_original 正常填用户打的字（不是 null）
     → 卡片 schema 不变，复用 s1-s4 已有字段，不新增字段
```

**关键澄清：图文混合不等于固定 s4。** 分类只看用户打的文字，跟有没有配图无关。只有"纯图片、完全不打字"才固定归 s4。举例（同一张咖啡杯照片）：

| 用户打的文字 | 分类 | 说明 |
|---|---|---|
| 「咖啡」 | s3 | 中文单词 → 地道翻译 |
| 「Coffee」 | s1 | 英文单词 → 查词 |
| 一句英文句子 | s2 | 语法润色纠错 |
| 一句中文长句/吐槽 | s4 | 场景手帐 |
| （不打字，仅发图） | s4（固定） | D3/D4：无文字可判断，默认场景手帐 |

**D3/D4 决策落地：** 仅发图片、无文字时，沿用 s4 分类，`chinese_original` 保持 `null`（不得把AI看图猜测填进这个字段——它代表"用户自己说出口的原话"，混入AI猜测会破坏主PRD"AI生成的 ≠ 用户说出来的"这条核心原则）。新增 `ai_scene_guess` 字段承载AI的场景猜测：

```json
{
  "chinese_original": null,
  "ai_scene_guess": "一杯咖啡放在办公桌上",
  "native_translation": "...",
  "key_phrase": "...",
  "scene_trigger": "..."
}
```

`messages` 表 `input_type` 字段的混合态记录方案见 5.1（Plan A/B，开发时确认后端依赖再定，不阻塞主链路）。

### 3.2 前端 AIService

当前是两个独立方法，需要合并为一个支持混合输入的接口：
```swift
generate(text: String?, image: UIImage?) async throws -> AIEnvelope
```

### 3.3 前端 TodayViewModel

- 新增图片状态（当前 ViewModel 里没有 image 相关状态）
- `send()` 方法需要支持携带图片参数
- **按 `CLAUDE.md` 硬性规定，状态管理用 `@Observable` 宏（iOS 17+），不使用 `@StateObject`/`@ObservedObject`**

### 3.4 前端 InputBar

**D1 决策落地：** 拍照、相册按钮与文字框、发送（以及后续语音）**平铺**在输入栏内，不做「+」收起。

- 新增拍照按钮和相册按钮，与文字框、发送按钮平铺同一行
- 用户选图后，输入框区域显示图片缩略图 + 删除（×）按钮
- 图片挂载后发送按钮激活（不需要填文字也可发送）
- 按钮的颜色/间距/圆角等视觉属性引用现有 design tokens，不在组件里硬编码数值（`CLAUDE.md` 要求）

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

两个视觉模块共享同一个 entry id，删除/长按等操作作用于整条消息。气泡背景色/圆角同样走 design tokens。

> 待细化：若未来要支持"只删图片保留文字"这类单模块编辑，可在图片卡片上加独立删除角标，暂不需要现在拆数据结构（见 5.1）。

### 3.6 客户端图片压缩与格式转码

**改动为：**
1. **统一转码**：不论原图是 HEIC / PNG / 其他格式，选图后一律转成 JPEG 再上传
2. **主动压缩**：长边 resize 到约 1600px，JPEG quality 约 0.75（具体数值待结合AI识别效果与卡片视觉需求微调）
3. **10MB 校验降级为兜底**：仅用于压缩流程异常等极端情况，正常路径下不会触发提示
4. **Live Photo**：仅取静态封面帧，不处理动态部分

> 产品UI文案提醒：图片过大时的提示文案属于产品UI copy，按 `CLAUDE.md` 规定必须是英文，例如 "This photo is too large. Try another one."——不能用中文（中文只能出现在AI生成的学习内容里，比如卡片的中译）。

### 3.7 权限处理

**D6 决策落地：相册选图改用 `PHPickerViewController`，不再走传统相册权限申请。**

理由：`PHPickerViewController`（iOS 14+，项目目标是 iOS 17+，完全覆盖）运行在系统沙盒中，用户选完图片后系统只把被选中的那张传给 App，因此不需要相册权限弹窗。

| 权限 | 触发时机 | 拒绝后处理 |
|------|---------|-----------|
| 相机权限 | 首次点击拍照按钮 | 客户端检测到 `.denied` 状态后，弹提示 + "Open Settings" 按钮，跳转 `UIApplication.openSettingsURLString`（提示文案同样需为英文） |
| 相册权限 | 不需要（改用 PHPicker） | 不适用 |

Onboarding 流程中已有相机权限相关代码（`CameraPickerView.swift`），Tab1 可复用。

---

## 四、已决策事项

| 决策点 | 结论 | 理由摘要 |
|--------|------|----------|
| D1 输入栏按钮布局 | 平铺，不做「+」收起 | 与主PRD既有UI稿一致；拍照/相册是并列主入口，不应降级为次要操作 |
| D2 用户消息气泡样式 | 分开两行，但同属一条 message | 匹配主流AI产品/IM的视觉习惯；数据模型仍是"一次发送=一条消息" |
| D3 纯图片输入的AI卡片行为 | 复用现有 s4（场景手帐）逻辑 | MVP 从简；AI 仍先给答案再追问引导用户补文字 |
| D4 纯图片场景 s4 字段调整 | 新增 `ai_scene_guess` 字段，`chinese_original` 保持 null | 避免AI猜测冒充"用户说出来的话" |
| D5 图文混合输入的分类与卡片结构 | 分类仍按文字的语言×颗粒度走 s1/s2/s3/s4，图片只做生成时的上下文增强 | 复用现有分类逻辑，改动收敛在 prompt 组装上 |
| D6 相册选图技术方案 | 改用 `PHPickerViewController`，不申请相册权限 | 系统沙盒隔离，用户体验更好；iOS 17+目标下无兼容顾虑 |

---

## 五、待讨论事项（不阻塞主链路，分别归入下面对应切片）

1. **单模块编辑颗粒度**（归入切片4）：图片+文字分两行展示后，是否需要支持"只删图片保留文字"或反之。
2. **`input_type` 混合态记录方案**（归入切片3，见 5.1）
3. **纯图片输入的追问 prompt 细节**（归入切片4）：s4 逻辑复用后，追问文案是否需要专门针对"无用户文字"的情况做区分。
4. **异常场景UI**（归入切片4）：图片上传失败、AI识别失败、内容审核拦截时的界面表现。
5. **发送中 loading 态**（归入切片4）：图片上传/AI处理期间的等待态设计。

### 5.1 `input_type` 混合态记录方案（Plan A / Plan B）

**背景**：`messages` 表目前 `input_type` 只有 `"text"` / `"image"` 两个取值，图文混合需要一个说法，否则依赖该字段筛选的下游逻辑（报表、训练数据脚本等）可能漏掉或误判这批消息。未接触实际后端代码，无法确认下游依赖方式，给两个方案，开发时对照代码库选定：

**方案A：新增枚举值 `"image_text"`**——三态，最直观，但需检查所有下游查询是否要加上这个新分支，若字段有 enum 约束还需要一次 migration。

**方案B：`input_type` 保留两值不变，混合态由 `text`/`image_url` 字段是否同时非空判断**——不引入新枚举值，但需检查是否有代码"只认 input_type 一个字段"而未必去看实际字段是否为空。

两方案都要求开发时确认现有依赖，暂不选定。

---

## 六、开发切片建议（按 `CLAUDE.md` 的"纵向切片优先"方法拆分）

> 每个切片完成后：先写单元测试锁定已验证的行为（不要在逻辑还没稳定时急着写测试），测试通过后把结果（通过/失败、具体报错）书面汇报给你，**等你确认后再开始下一个切片**，不擅自连续往下做。

### 切片1：纯图片输入（拍照 / 相册 → 发送 → AI卡片）

**范围：** D1（按钮平铺）、D6（PHPicker + 相机权限拒绝引导）、3.6（压缩转码）、D3/D4（纯图片走 s4 + `ai_scene_guess` 字段）、D2 中的图片气泡渲染部分。

**验收标准（草案）：**
- 点击相机/相册按钮能正常拍照/选图，选图流程不触发相册权限弹窗
- 图片选中后发送按钮激活，不填文字也可直接发送
- 发送后用户气泡显示图片（右对齐），不出现文字气泡
- AI 卡片正常返回：`chinese_original` 为 null，`ai_scene_guess` 有内容
- 相机权限被拒绝后再次点击拍照按钮，弹出英文提示 + "Open Settings" 引导

### 切片2：图文混合输入

**范围：** D2 中的文字气泡部分（叠加在切片1的图片气泡下方）、D5（分类逻辑不变+图片上下文增强）、Edge Function 的 prompt 拼接修复（现有"图片存在时文字被忽略"的 bug）。

**验收标准（草案）：**
- 图片+文字一起发送，气泡分两行显示（图上文下，同一条消息，删除/长按对整条消息生效）
- 卡片按文字内容正确分类到 s1/s2/s3/s4，`chinese_original` 为用户实际输入（不是 null）
- 人工抽查确认AI确实"看到"了图片信息（而非纯靠文字生成），比如场景细节与照片吻合

### 切片3：`input_type` 字段处理（数据层，可与切片1/2并行或稍后）

**范围：** 5.1 中 Plan A/B 落地，开发接触实际 `messages` 表和下游依赖后二选一。不阻塞切片1/2上线。

### 切片4：体验打磨（后续迭代）

**范围：** 异常场景UI（上传失败/识别失败/内容审核拦截）、发送中loading态、压缩参数微调、单模块编辑颗粒度、纯图片场景追问文案细化。

---

*方案C（圈选区域）已记录，决定推迟到 v2 之后*
