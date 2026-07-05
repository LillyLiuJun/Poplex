# Tab1 图片输入（方案B）设计文档 v4

> 整理于 2026-07-04
> v4 更新：新增 D7-D9（预览缩略图规格、上传宽高比校验、已发送图片气泡的响应式尺寸），新增第七节"对 Tab2 的影响"

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

> 注：Gemini 2.5 Flash 是当前已上线的实现，AI 服务商按 `CLAUDE.md` 仍是 TBD（需先测试不同方案成本再定），方案B不涉及换供应商。

### 2.3 现有 AIService 接口

```swift
func generate(text: String) async throws -> AIEnvelope
func generate(image: UIImage) async throws -> AIEnvelope
```

---

## 三、方案B 涉及的改动范围

### 3.1 后端 Edge Function

**现有问题：** 当请求中包含 `image_base64` 时，`text` 字段被完全忽略。

**D5 决策：分支逻辑改为三条路径**

```
Edge Function 收到 { text?, image_base64? }
  ↓
├─ 只有 text → 沿用现有逻辑，按语言×颗粒度分类进 s1/s2/s3/s4
├─ 只有 image（D3/D4）→ 固定走 s4，chinese_original 填 null，新增 ai_scene_guess 字段
└─ image + text 都有（D5）→ 分类逻辑跟"只有text"一样，图片只做生成时的上下文增强，
                              chinese_original 正常填用户文字，卡片schema不变
```

**关键澄清：图文混合不等于固定 s4，分类只看文字。** 举例（同一张咖啡杯照片）：「咖啡」→s3，「Coffee」→s1，英文句子→s2，中文长句→s4，不打字→s4（固定，D3/D4）。

**D3/D4 决策：** 纯图片输入时，`chinese_original` 保持 `null`，新增 `ai_scene_guess` 字段承载 AI 看图的场景猜测：

```json
{
  "chinese_original": null,
  "ai_scene_guess": "一杯咖啡放在办公桌上",
  "native_translation": "...",
  "key_phrase": "...",
  "scene_trigger": "..."
}
```

`messages` 表 `input_type` 混合态记录方案见 5.1（Plan A/B，开发时确认后端依赖再定）。

### 3.2 前端 AIService

```swift
generate(text: String?, image: UIImage?) async throws -> AIEnvelope
```

### 3.3 前端 TodayViewModel

- 新增图片状态；`send()` 支持携带图片参数
- 按 `CLAUDE.md`，状态管理用 `@Observable` 宏，不用 `@StateObject`/`@ObservedObject`

### 3.4 前端 InputBar

**D1 决策：** 拍照、相册、文字框、发送平铺在输入栏内，不做「+」收起。

**D7 决策（新增）：选图后的预览缩略图规格**

- 固定尺寸正方形缩略图（56×56pt），挂在输入框上方一行，配右上角半透明背景的 × 删除按钮
- 裁剪方式：`scaledToFill` + 裁成正方形（center crop）——预览只是"提示你选中了这张"，裁边无所谓
- **性能要求：不得直接用原图渲染。** 选图后立即生成一份独立的小尺寸缩略图（限制在 200×200px 内）专门用于此预览，与后续发送用的压缩版（3.6节，1600px/JPEG 0.75）是两条独立流水线；建议选图那一刻就在后台并行准备好压缩版并缓存，避免点发送时才现算
- 没有图片时这一行不出现，输入框恢复单行

**D8 决策（新增）：上传前的宽高比校验**

在选图回调处（与10MB校验、HEIC转码同一个检查点）新增宽高比校验：长边:短边超过阈值（初步建议 3:1，需用真实照片/截图样本测试后再定，不能拍脑袋）时直接拒绝挂载，弹出提示（英文，如 "This photo's proportions aren't supported. Try another one."）。

目的：把"极端宽高比"的复杂度挡在输入端，避免聊天气泡渲染层需要为panorama、拼接截图等极端情况单独写兜底逻辑。相机拍照因为比例固定（4:3/16:9/1:1），基本不会触发此校验，主要针对相册选图。

阈值需要偏宽松——用户可能会分享较长的截图（比如聊天记录截图），阈值定太紧会误伤正常使用场景。

### 3.5 前端 TimelineEntry（用户气泡）

**D2 决策：** 图片和文字分开两行展示，同属一条消息，不拆成两条 message 记录。

```swift
case userBubble(text: String?, image: UIImage?)
```

**D9 决策（新增）：已发送图片气泡的响应式尺寸规则**

与 D7 的预览缩略图逻辑相反——这张图是素材的原始记忆锚点，**不裁切，完整显示**：

- 缩放方式：`scaledToFit`（等比缩放，不裁边），在一个最大宽度 × 最大高度的边框内显示
- **最大宽度**：复用文字气泡现有的最大宽度基准（不新定一套比例），保证图片气泡和文字气泡的宽度观感一致
- **最大高度**：按屏幕高度的百分比设定（初步建议屏幕高度的25%-28%），不用固定pt值——固定pt在小屏（iPhone SE）上占比会偏大、在大屏（Pro Max）上偏小，用百分比才能让"一张图占多少屏幕"这个观感跨设备一致
- 圆角与其他气泡统一（沿用气泡的圆角token，不用直角）
- 上述比例值定义为 design token（如 `size-imageBubble-maxWidthRatio` / `size-imageBubble-maxHeightRatio`），集中管理，不写死在组件里（`CLAUDE.md` token规则）
- **展示图与全屏图分离**：气泡内展示用中等分辨率版本（建议约500px量级，独立生成，不直接渲染发送用的1600px压缩图），性能更好；需新增"点击图片进入全屏查看"交互，全屏时再加载更高分辨率版本（发送用的1600px版本即可，无需原图）
- **无障碍**：VoiceOver 读到图片时的 accessibility label，纯图片场景可直接复用 `ai_scene_guess` 字段的文字描述（如"一杯咖啡放在办公桌上"），不用额外写文案；图文混合场景暂无此字段，可用通用占位文案兜底（如 "Photo attached"）

> 因 D8 已在上传端拦截极端宽高比，此处渲染逻辑不需要为超宽/超窄图片单独设计兜底分支。

### 3.6 客户端图片压缩与格式转码

1. 统一转码为 JPEG（不论原图 HEIC/PNG/其他）
2. 主动压缩：长边 resize 至约 1600px，JPEG quality 约 0.75
3. 10MB 校验降级为兜底，正常路径不触发
4. Live Photo 仅取静态封面帧
5. 提示文案（如图片过大）必须为英文，例如 "This photo is too large. Try another one."

### 3.7 权限处理

**D6 决策：** 相册选图改用 `PHPickerViewController`，不再走传统相册权限申请（项目目标 iOS 17+，完全覆盖）。

| 权限 | 触发时机 | 拒绝后处理 |
|------|---------|-----------|
| 相机权限 | 首次点击拍照按钮 | 检测到 `.denied` 后弹英文提示 + "Open Settings" 按钮 |
| 相册权限 | 不需要（PHPicker） | 不适用 |

---

## 四、已决策事项

| 决策点 | 结论 |
|--------|------|
| D1 输入栏按钮布局 | 平铺，不做「+」收起 |
| D2 用户消息气泡样式 | 分开两行，同属一条 message |
| D3 纯图片输入的AI卡片行为 | 复用现有 s4 逻辑 |
| D4 纯图片场景 s4 字段调整 | 新增 `ai_scene_guess`，`chinese_original` 保持 null |
| D5 图文混合输入的分类与卡片结构 | 分类仍按文字走 s1-s4，图片只做上下文增强 |
| D6 相册选图技术方案 | 改用 `PHPickerViewController` |
| D7 预览缩略图规格 | 56×56pt 正方形裁切，独立生成小尺寸缩略图，不用原图渲染 |
| D8 上传宽高比校验 | 长边:短边超阈值（初定3:1）直接拒绝挂载 |
| D9 已发送图片气泡尺寸规则 | scaledToFit不裁切；宽度对齐文字气泡，高度按屏幕高度百分比；支持点击全屏；无障碍复用 `ai_scene_guess` |

---

## 五、待讨论事项（不阻塞主链路）

1. 单模块编辑颗粒度（只删图片保留文字）——归入切片4
2. `input_type` 混合态记录方案——归入切片3，见 5.1
3. 纯图片输入的追问 prompt 细节——归入切片4
4. 异常场景UI（上传失败/识别失败/内容审核拦截）——归入切片4
5. 发送中 loading 态——归入切片4
6. D8 的具体阈值需要用真实照片/截图样本测试后确定，当前 3:1 仅为初步建议

### 5.1 `input_type` 混合态记录方案（Plan A / Plan B）

**方案A：** 新增枚举值 `"image_text"`，需检查所有下游查询/报表是否要加这个分支。
**方案B：** 保留两个取值，混合态由 `text`/`image_url` 字段是否同时非空判断，需检查是否有代码只认 `input_type` 单字段。

两方案都要求开发时确认现有依赖，暂不选定。

---

## 六、开发切片建议

> 每个切片完成后写单元测试，测试通过后把结果书面汇报，等确认后再开始下一个切片。

### 切片1：纯图片输入
范围：D1、D6、D7（预览缩略图）、D8（宽高比校验）、3.6（压缩转码）、D3/D4、D2中的图片气泡渲染、D9（图片气泡尺寸规则）。

验收标准：
- 拍照/相册选图不触发相册权限弹窗；超阈值宽高比或HEIC等格式能正确处理
- 图片选中后预览为56×56pt裁切缩略图，发送按钮激活
- 发送后气泡内图片完整显示（不裁切），尺寸符合D9的响应式规则，可点击全屏查看
- AI卡片：`chinese_original`为null，`ai_scene_guess`有内容

### 切片2：图文混合输入
范围：D2文字气泡部分、D5、Edge Function prompt拼接修复。

验收标准：
- 图片+文字气泡分两行显示，同属一条消息
- 卡片按文字正确分类s1-s4，`chinese_original`为用户实际输入
- 人工抽查确认图片确实影响了生成内容

### 切片3：`input_type` 字段处理（可并行）
范围：5.1 Plan A/B落地。

### 切片4：体验打磨（后续迭代）
范围：异常场景UI、loading态、压缩参数微调、单模块编辑颗粒度、纯图片追问文案、D8阈值调优。

---

## 七、对 Tab2（Page2_PRD_v1.md）的影响

> 方案B涉及的图片能力会流转进Tab2，但 Page2_PRD_v1.md（v1.2，2026-07-01）写作时间早于本文档 D3-D5 的决策，两边目前是脱节的，需要同步修正。

**1. 核心冲突（需要优先对齐）：** 纯图片（无文字）产出的s4素材，`chinese_original`为null，意味着这不是用户真正说出口的内容，而Page2 PRD开篇即强调"AI生成的 ≠ 用户能说出来的，这是Tab2最重要的视觉分界线"。这类素材不应原样当作普通已完成场景卡片处理，具体怎么在Tab2呈现（打特殊状态 / 先归入类似"待处理"的轻量位置）需要与《Tab2_卡片状态与练习机制_v1.md》对齐，本文档无法单方面决定。

**2. 数据结构：** `materials`表的`raw_content`（s2/s4结构）建议新增可选字段记录关联图片（如`source_image_url`）。词汇类（s1/s3）不带图片，保持"词汇本不假装有场景"的原则不变。

**3. 展示位置（已讨论，待写入Page2 PRD）：**
- Mine列表卡片：左侧新增52×52pt缩略图（裁切显示），文字照旧在右侧；无配图素材不显示此位置
- 场景详情页（第九节）：在标签/日期行下方、英文正文上方插入图片（完整显示，圆角矩形），复用D9的展示规则

**4. 需要同步修正 Page2_PRD_v1.md 的地方：**
- 第四节（卡片设计）：补充有图片关联时的展示规则
- 第六节（数据衔接）：`raw_content`结构补充图片字段
- 第九节（场景详情页）：补充图片插入位置
- 第七节/断点确认：新增"纯图片素材的Tab2呈现方式"作为待确认问题

---

*方案C（圈选区域）已记录，决定推迟到 v2 之后*
