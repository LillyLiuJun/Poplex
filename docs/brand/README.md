# Poplex 品牌资产

> 本目录是品牌视觉的**唯一入口**。找 logo、图标、字标、开屏，先看这里。
> 色彩 / 字体系统不在这里，在 `../design-system/`。

---

## 一、代码才是真源

品牌资产在这个项目里是**活的**——logo 不是一张图，是一段矢量路径 + 一组比例常量。
所以**改品牌视觉要改代码，不是改图**：

| 资产 | 真源 | 说明 |
|---|---|---|
| **P 字形** | `AIEnglishApp/Components/SplashScreenView.swift` → `PoplexPShape` | 贝塞尔路径 + 定稿变换。图标、字标、水印、开屏共用这一份 |
| **字标度量** | `AIEnglishApp/Components/PoplexWordmark.swift` → `PoplexWordmarkMetrics` | 字距 / 墨点 / 安全边距的全部比例 |
| **字标组件** | 同上 → `PoplexWordmark` | App 内直接用它，不要自己拼 |
| **开屏动画** | `AIEnglishApp/Components/SplashScreenView.swift` | 时间表在 `AppTheme.Motion.Splash` |
| **色值** | `AIEnglishApp/Theme/Theme.swift` | `Primitive.iconGround` / `iconInk`、`Color.splashBg` / `splashDot` |
| **App 图标切图** | `AIEnglishApp/Assets.xcassets/AppIcon.appiconset/` | 母版 `poplex_icon_master*.svg`，PNG 由它生成 |

本目录的 `assets/*.svg` 是**导出物**，给设计工具和外部用。
改了代码记得回来同步导出，反过来改 SVG 不会影响 App。

---

## 二、目录

```
brand/
├── README.md          ← 你在这里
├── 字标规格.html       ← 横版全称字标：比例、安全边距、尺寸下限、配色、禁用项
├── 图标规格.html       ← App 图标：墨点定位 B 档、各尺寸、切图参数
├── 开屏动画.html       ← 开屏方案 S2「弹入 + 居中滑移」可播放预览
├── 设计需求提示词.md    ← 丢给任何 AI 重做 logo 时用的完整 brief
├── assets/            ← 导出的矢量文件
└── archive/           ← 探索过程，全部作废，只作历史参考
```

---

## 三、定稿状态

| 项 | 状态 |
|---|---|
| 产品名 | **Poplex**（首字母大写） |
| 字标 | `Poplex` + 句末墨点。P 是矢量字形，`oplex` 是 New York Bold Italic |
| App 图标 | 大写 **P** + 墨点，纸底橙字。墨点坐在基线上（B 档） |
| 品牌橙 | `#FF7622` —— **不许改**。不调亮、不调暗、不降饱和、不加渐变 |
| 图标底 | `#FBF8F5`（= App 卡片底，打开时不跳变） |
| 墨色 | `#2A2320` |
| 开屏 | 方案 S2，总长 1.16s。P 在正中弹入 → 左滑 → `oplex` 逐字 → 墨点落位 |

**唯一输入量是 P 的字高 H**，其余尺寸全部由它推出（见 `字标规格.html`）。

---

## 四、用哪个

| 场合 | 用什么 |
|---|---|
| App 内任何位置的字标 | `PoplexWordmark(capHeight:style:)` |
| App 图标 / favicon / 头像 | 方版 P，**不要**把字标塞进方框 |
| 背景水印 | `PoplexPShape` + `AppTheme.Color.brandWatermark` |
| 官网 / 商店截图 | `assets/poplex-wordmark.svg`（**先转曲**） |
| 印刷 / 合作方 | `assets/poplex-P-ink.svg` 或转曲后的字标，单色 |
| 深色背景 / 照片上 | `assets/poplex-P-paper.svg`，或 `.mono(.white)` |

---

## 五、三条硬规则

1. **橙色和墨色不能同时消失。** 主版里橙是字、墨是点；单色版里两者合一。
   不存在「橙字 + 橙点」——点必须和字拉开，否则句号读不出来。
2. **H < 18pt 去掉墨点。** 再小它会退化成一个脏点，不如没有。极小尺寸只用 P。
3. **`oplex` 对外交付前必须转曲。** 它是活字，对方机器没有 New York 就会掉字体。

完整禁用项见 `字标规格.html` §05。

---

## 六、还没定

- 字标是否需要一个**全小写** / **全大写**变体（目前只有首字母大写一种）
- 深色模式的 App 图标变体（母版 `poplex_icon_master_dark.svg` 已备好，
  但 `Contents.json` 还是旧版结构，挂变体需要改成 Xcode 15 的 appearances 写法）
- 品牌字体是否从系统 New York 换成打包字体（换了要重算 `capPerEm`，
  `PoplexWordmarkMetrics` 已经是向 UIFont 实测，换字体会自动跟上）

---

## 七、archive/ 里有什么

14 份探索稿，全部作废。留着只为回答「这个方向试过没有」：

- 早期方向：`poplex-logo-explorations` / `poplex-marks` / `poplex-p-drawn` /
  `poplex-icon-p-onestroke`（一笔画螺旋，方向理解错了）
- 图标演进：`poplex-app-icon-p` → `poplex-icon-p-dot-refined` →
  `poplex-icon-final-FF7622` → `poplex-icon-P-bg` → `poplex-icon-P-italic`
- 作废结论：`poplex-icon-ground`（提出把品牌色提亮成 `#F9AA76` 做图标底，
  **已否决**，品牌色不换）
- 开屏演进：`poplex-splash-animation`（A/B/C 三方案）→ `poplex-splash-tuning-diff`（调参记录）
- `poplex-wordmark-length`（字标长度论证）
