# App Store 产品页截图要求（Apple 官方核对）

> 核对日期：2026-08-27  
> 范围：iOS App Store 产品页截图；App Preview 仅作关联说明。  
> 来源原则：仅采用 Apple Developer / App Store Connect 官方文档。Apple 会更新支持设备与尺寸，最终导出前应再次打开链接核对。

## 一页结论

- 每个截图集合可上传 **1–10 张**；格式为 `.jpeg`、`.jpg` 或 `.png`，且图片**不能包含 Alpha 通道或透明度**。[Apple：Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- 对当前 iPhone-only 产品，最省制作量的做法是只交一套 Apple 当前列为最高分辨率组的 **6.9 英寸截图**，App Store Connect 会自动缩放到较小设备。6.9 英寸组接受三种竖图尺寸：`1260×2736`、`1290×2796`、`1320×2868`（横图则宽高互换）。[Apple：Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- 若不提交 6.9 英寸组，则运行于 iPhone 的 App 必须提供 6.5 英寸组；其接受 `1284×2778` 或 `1242×2688` 竖图（横图宽高互换）。Apple 会在缺少对应尺寸时按文档的继承链缩放。[Apple：Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- 若 App 也运行于 iPad，**13 英寸 iPad 截图另行必需**，接受 `2064×2752` 或 `2048×2732` 竖图（横图宽高互换）；不能仅凭 iPhone 图覆盖 iPad 产品页。[Apple：Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- 截图必须准确反映 App 的核心实际体验、保持随版本更新；应展示 App 正在使用，而不能整套只放标题图、登录页或启动页。Apple 允许截图加入文字和图像叠层来解释交互。[Apple：App Review Guidelines 2.3](https://developer.apple.com/app-store/review/guidelines/)
- **App Preview 是可选视频，不是截图。** 每种支持的设备尺寸、每种语言最多 3 条；它在产品页上会排在截图之前，所以若制作视频，第一静态卖点图不再是用户最先看到的媒体。[Apple：Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)

## 1. 数量、格式与透明度

| 项目 | Apple 当前要求 |
|---|---|
| 数量 | 最少 1 张，最多 10 张 |
| 静态文件格式 | `.jpeg`、`.jpg`、`.png` |
| 透明度 | 不允许 Alpha 通道或透明背景 |

来源：[Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)、[Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)。

## 2. iPhone 必需设备组与尺寸

### 推荐交付：6.9 英寸一套

Apple 当前把 6.9 英寸列为 iPhone 的最高分辨率截图组。允许尺寸如下，任一尺寸即可：

| 方向 | 接受尺寸（px） |
|---|---|
| 竖版 | `1260×2736`、`1290×2796`、`1320×2868` |
| 横版 | `2736×1260`、`2796×1290`、`2868×1320` |

这些尺寸当前对应 iPhone Air、iPhone 17 Pro Max、iPhone 16 Pro Max / Plus、iPhone 15 Pro Max / Plus、iPhone 14 Pro Max 等机型。设备名单会随 Apple 更新，不应写死进长期生产规范。[Screenshot specifications — iPhone 6.9-inch](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)

### 6.5 英寸何时必需

若 App 运行于 iPhone 且没有提供 6.9 英寸截图，6.5 英寸截图必需；接受：

- 竖版：`1284×2778` 或 `1242×2688`
- 横版：`2778×1284` 或 `2688×1242`

若已提供符合要求的 6.9 英寸图，Apple 说明可自动缩放到较小设备；因此没有必要为每一种 iPhone 尺寸重复制作，除非团队希望针对不同设备或语言做定制构图。[Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)、[Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)

### 其他 iPhone 组（仅在需要定制时）

- 6.3 英寸：`1179×2556` 或 `1206×2622` 竖版；缺失时使用从 6.5 英寸缩放的版本。
- 6.1 英寸：`1170×2532`、`1125×2436` 或 `1080×2340` 竖版；缺失时使用从 6.5 英寸缩放的版本。
- 5.5 英寸：`1242×2208` 竖版；缺失时使用从 6.1 英寸缩放的版本。
- 4.7 英寸：`750×1334` 竖版；缺失时使用从 5.5 英寸缩放的版本。
- 更早的 4 英寸、3.5 英寸设备也仍列有接受尺寸及缩放链，通常不必为本项目单独生产。

全部横版均按 Apple 表格所列的宽高互换规格交付；详情见 [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)。

## 3. iPad 是否需要

如果构建配置使 App 运行于 iPad，13 英寸组截图必需：

| 方向 | 接受尺寸（px） |
|---|---|
| 竖版 | `2064×2752` 或 `2048×2732` |
| 横版 | `2752×2064` 或 `2732×2048` |

其余 iPad 尺寸可由 13 英寸组自动缩放；也可在 Media Manager 中为具体设备尺寸和本地化上传自定义版本。[Screenshot specifications — iPad](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)、[Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)

## 4. 上传、缩放与本地化规则

- 当多个设备尺寸和本地化的 UI 相同时，只提供所需的最高分辨率截图即可，App Store Connect 会自动缩小到较小设备。[Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- 若不希望使用自动缩放版本，可进入 **Media Manager → View All Sizes**，为指定设备尺寸和语言上传自定义图；也能在那里查看被缩放出来的高分辨率图。[Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- 截图是可本地化的版本元数据。上传时在 App 版本的 iPhone / iPad 对应区域拖入素材；切换顶部语言后，可为该本地化单独编辑。[Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- Apple 列出的可编辑状态为 Prepare for Submission、Invalid Binary、Rejected、Metadata Rejected、Developer Rejected。版本提交审核并获批后，要更新截图必须创建新的 App 版本。[Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)

## 5. 内容与营销限制

以下是会直接影响商店图创作的审核规则：

1. **真实、最新、不误导。** 截图与预览必须准确反映 App 核心体验并随版本更新；不能宣传 App 实际没有的功能、服务或虚假价格。[App Review Guidelines 2.3、2.3.1](https://developer.apple.com/app-store/review/guidelines/)
2. **展示 App 正在使用。** 截图不能只由标题画面、登录页或启动页构成；可以加文字和图形叠层解释输入方式或交互。[App Review Guidelines 2.3.3](https://developer.apple.com/app-store/review/guidelines/)
3. **付费内容要说清楚。** 若画面展示的内容、功能、等级或订阅需要额外购买，描述、截图和预览必须明确指出。[App Review Guidelines 2.3.2](https://developer.apple.com/app-store/review/guidelines/)
4. **不要塞价格或无关营销词。** 截图、预览等元数据不得加入价格、与元数据类型无关的条款或描述；也不要利用商标词、热门 App 名等操纵发现机制，避免不可验证的产品主张。[App Review Guidelines 2.3.7](https://developer.apple.com/app-store/review/guidelines/)
5. **素材按 4+ 年龄适宜标准。** 即使 App 的年龄评级更高，图标、截图和预览仍应适合所有受众，并遵守 4+ 元数据尺度。[App Review Guidelines 2.3.8](https://developer.apple.com/app-store/review/guidelines/)
6. **权利和隐私。** 团队必须拥有截图与预览中所有素材的使用权；账户、姓名、头像、学习记录等应使用虚构数据，不展示真实个人信息。[App Review Guidelines 2.3.9](https://developer.apple.com/app-store/review/guidelines/)
7. **只聚焦所支持的 Apple 平台。** 不放其他移动平台或替代 App 市场的名称、图标或图像，也不要放与 App 体验无关的信息。[App Review Guidelines 2.3.10](https://developer.apple.com/app-store/review/guidelines/)
8. **提交前去掉临时内容。** 元数据不得保留占位文字或不完整内容。[App Review Guidelines 2.1](https://developer.apple.com/app-store/review/guidelines/)

## 6. App Preview：相关但不要与截图混淆

App Preview 是产品页视频资产：

- 可选；每个支持的设备尺寸、每种语言最多 3 条，并且在 iPhone、iPad、Mac、Apple TV 的媒体序列中总是排在截图之前。[Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- 时长 15–30 秒，最大 500 MB，最高 30 fps；H.264 支持 `.mov` / `.m4v` / `.mp4`，ProRes 422 HQ 仅支持 `.mov`。[App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)
- iOS 可竖版或横版；6.9 / 6.5 / 6.3 / 6.1 英寸 iPhone 当前接受 `886×1920` 竖版或 `1920×886` 横版预览视频。视频规格与静态截图像素尺寸不同。[App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)
- 内容只能使用 App 自身的视频屏幕录制；可加旁白、文字或视频叠层解释不够直观的部分。[App Review Guidelines 2.3.4](https://developer.apple.com/app-store/review/guidelines/)
- 可设置 poster frame；上传后处理最长可能需 24 小时。[Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)

## 对 AIEnglishApp 商店图生产的直接建议（基于规则的推论）

这是制作建议，不是 Apple 的硬性规定：

- 若当前发布目标是 iPhone-only，建立一套 **6.9 英寸竖版主文件**即可，建议选 `1320×2868`，并在 App Store Connect 中预览自动缩放结果。这个选择减少重复劳动，也符合 Apple 的最高分辨率自动缩放流程。
- 不要用透明 PNG 作为最终文件；即使设计稿里用透明图层，导出时也应扁平化到不透明背景。
- 每张图的核心应是真实 App UI，营销标题作为叠层；不要做成只有一句口号和品牌背景的海报。
- 若 Xcode target 同时支持 iPad，需把 13 英寸 iPad 图纳入上线清单；在确定构建配置前，不应假设 iPhone 图足够。
- 首版可以先不制作 App Preview：它是可选资产，而且一旦上传会抢占截图之前的首位展示。应等真实关键流程稳定、能用 15–30 秒屏幕录制清晰讲完后再制作。

## 官方来源清单

- [Apple — Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Apple — Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)
- [Apple — App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple — App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications/)
