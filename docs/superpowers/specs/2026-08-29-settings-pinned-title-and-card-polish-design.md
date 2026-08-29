# Settings 区打磨：卡片亮度 + 顶部留白 + 固定居中标题

## 背景

PM 反馈 Settings 页面白色卡片太亮、顶部留白太大，并提出把页面标题改成固定在
顶部、居中、不随内容滚动（类似系统导航栏）。讨论过程中确认这个处理要推广到
Settings 所属的三个页面（Settings / About AI / Feedback，三页共用
`SettingsScreen` 外壳组件），并选定了具体字体、文案方向。这份文档落定最终方案。

## 决定

### 1. 固定居中标题

`SettingsScreen` 新增可选参数 `pinnedTitle: String?`。有值时，在外壳已有的顶部
固定带（`SheetTopScrim` 所在的那一条，非新写的滑动交互）里居中渲染这个标题文字，
不再需要重复占用一整个 `barHeight`；三个页面各自的入口把标题文案传进来：

| 页面 | `pinnedTitle` | 现有的滚动大标题 |
|---|---|---|
| Settings | `"Settings"` | 删除（原 `pageTitle` 计算属性整体移除） |
| About AI | `"Personal data"` | 删除 |
| Feedback | `"Feedback"` | 删除 |

原本各页 `content()` 里那段 `pageTitleSerif` 大标题文字整块删除——标题只在固定带
里出现一次，不再滚动内容里再重复一次。

**About AI 的标题拆成两份、不再是单一真源**：`AboutAIView.title`
（`"How AI uses your data"`）继续作为 Settings 列表里那一行的入口文案不变——
它是 App Store 5.1.2(i) 披露要求里"你的数据"这个所有格的落点，保留完整文案；
`pinnedTitle` 另传一个更短的 `"Personal data"`，专供页面顶部固定带展示，
两者各自硬编码在各自的调用点，不再共享一个 `static let`。

**为什么标题不再写进滚动内容**：三页一致——标题只出现在固定带这一处，
不在正文里重复。

**为什么不需要处理"标题过长换行"**：三个最终文案（Settings / Personal data /
Feedback）都很短，在导航条宽度下单行内绰绰有余，不需要为长标题设计截断或
换行规则。

**滚动交互**：固定带复用现有的 `SheetTopScrim`（同色渐隐遮罩）机制——内容向上
滑动时已经会在这条带子下方平滑淡出，这次只是把标题文字也放进这条已验证过的
带子里，不涉及新的滚动/遮罩逻辑。

### 2. 新字体 token

```swift
static let settingsPinnedTitleSerif =
    SwiftUI.Font.system(.title3, design: .serif, weight: .semibold)
```

衬线、`.title3` 文本样式基准（保证 Dynamic Type）、`.semibold`。最初定的是
`.body`（比肩系统导航栏字号），PM 看实机后要求更大一档，改成 `.title3`——
60pt 高的固定带还有余量，不会挤。保留品牌衬线识别度，不切系统无衬线字体
（该 App 全线用衬线做标题层级，切系统字体会让固定标题像是从别的 App 里
长出来的）。

### 3. 卡片背景变亮问题

现状：`SettingsCard`（及 `FeedbackView` 里三处 `cornerRadius: .large` 的卡片）
通过 `.surfaceCard()` 吃到 `SurfaceCardModifier` 硬编码的 `warmGlassSurface`
（`#FFFDF8`，100% 不透明）。这个 modifier 同时被 Tab2（`MineView`、
`CategoryProgressRow`）复用，**不能直接改 `warmGlassSurface` 本身**，否则 Tab2
的卡片会被这次改动波及——不在这次范围内。

做法：

- `SurfaceCardModifier` 和 `surfaceCard()` 都新增一个带默认值的 `fillColor`
  参数，默认值仍是现在的 `AppTheme.Color.warmGlassSurface`——**所有现有调用点
  行为不变，包括 Tab2**。
- 新增语义 token：
  ```swift
  static let settingsCardSurface = Primitive.warmWhite.opacity(0.85)
  ```
  复用已有的 `warmWhite` 原色，只是加了透明度，不新造颜色值。
- `SettingsCard` 与 `FeedbackView` 那三处卡片，显式传
  `fillColor: AppTheme.Color.settingsCardSurface`。

Tab2 的卡片（`MineView`、`CategoryProgressRow`）完全不动。

### 4. 顶部留白

`SettingsScreen.topPadding` 的默认值从 `AppTheme.Space.paddingPage`（20）
改为 `AppTheme.Space.paddingSection`（32）——固定带到第一块内容的间距，
和内容区块彼此之间的间距（`paddingSection`）保持同一节奏，而不是另开一个数字。
`SettingsView` 里原本覆盖成 `AppTheme.Space.paddingHero`（48，专为大标题的
呼吸感设的）的那行删掉，跟着走新默认值。三页因此共享同一个顶部留白，不必
各自调参。

`SettingsView` 里 `sectionToPageLevel`（原本用来给大标题和版本号单独加距离的
换算量）随着大标题删除，只保留给 `versionFooter` 页脚用；不再需要"标题专属
间距"这层概念。

## 影响范围

- `AIEnglishApp/Settings/Components/SettingsScreen.swift`——新增 `pinnedTitle`
  参数、渲染逻辑、`contentTopInset` 计算调整、`topPadding` 默认值改动。
- `AIEnglishApp/Settings/SettingsView.swift`——删除 `pageTitle`、传
  `pinnedTitle: "Settings"`、去掉 `topPadding` 覆盖。
- `AIEnglishApp/Settings/AboutAIView.swift`——删除滚动大标题、传
  `pinnedTitle: "Personal data"`。
- `AIEnglishApp/Settings/FeedbackView.swift`——删除滚动大标题、传
  `pinnedTitle: "Feedback"`、三处卡片加 `fillColor`。
- `AIEnglishApp/Settings/Components/SettingsRows.swift`——`SettingsCard` 加
  `fillColor`。
- `AIEnglishApp/Theme/Theme.swift`——新增 `settingsPinnedTitleSerif` 字体
  token、`settingsCardSurface` 颜色 token、`surfaceCard()`/
  `SurfaceCardModifier` 加 `fillColor` 参数。

不涉及 Tab1、Tab2 任何文件。

## 测试

纯视觉/token 改动，不涉及分支判断或状态机逻辑，不新增单元测试——跟这个仓库里
其他纯视觉调整（如 `WarmGlassBar` 的模糊参数）的验收方式一致：改完在模拟器/
真机里过一遍三个页面，人工确认。
