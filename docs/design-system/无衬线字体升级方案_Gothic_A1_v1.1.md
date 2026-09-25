# 无衬线字体升级方案：Geist → Gothic A1 替换实施规范

> **文档性质**：设计系统升级与工程落地执行方案（Design System & Engineering RFC）
> **文档版本**：v1.1（修订 v1.0，修订依据见 §0）
> **关联基线**：`AIEnglishApp/Theme/Theme.swift` · `AppTheme.Font` · `AIEnglishApp/Theme/FontLoader.swift`
> **实施目标**：把 Poplex 的 UI 无衬线字体从 **Geist** 全量换成 **Gothic A1**（字体已拍板），做到：包体不膨胀、版面不跳动、测试不崩、可一步回滚。

---

## 0. v1.1 修订记录（给执行方看：v1.0 里哪些不要照做）

以下结论均为 2026-09-24 实测（Gothic A1 v2.50 / Google Fonts v18 的字形数据 + 仓库内的 Geist 文件 + 代码 grep），数据见附录。

| # | v1.0 的说法 | 实测事实 | v1.1 的处理 |
|---|---|---|---|
| 1 | Gothic A1 字面比 Geist **宽 10–12%**，要缩胶囊内边距、加 -0.15pt 字距 | Gothic A1 **反而窄 2–5%** | **删除**所有「宽度补偿」（pillHPad 9→8.5、间距 5→4.5、tracking -0.15 全部不做） |
| 2 | 未提及 | 两款字体的**纵向度量（行框上下沿 + 行距）结构完全不同**，会让文字在胶囊/按钮里上下偏移、单行高度变化 | **新增控制点 2**：在字体文件里一次性校正纵向度量 |
| 3 | 硬编码只有 `Tab2ActivityDisplay.swift` 一处 | 共 **10 处**：生产 1 + DesignLab 5 + 单元测试 4（测试是 `!` 强制解包，字体缺失直接崩） | **新增控制点 4**：字体名单一来源 + 全部清理 |
| 4 | 映射 6 个语义 Token | `geist()` 工厂下约 **40 个** Token，改工厂 = 全部换 | 明确「全量」，并列出需 PM 拍板的 3 个高曝光 Token（§2.2） |
| 5 | 新建 `GothicA1Weight` 枚举 | 用字体品牌名给枚举命名，下次换字体又要全局改名，违反「Token 按用途命名」 | 改为中性名 `SansWeight` + `sans()` 工厂 |
| 6 | 「若需回退仅改一处，5 秒切回」 | 只有 Geist 文件仍在包内且仍被注册时才成立 | 过渡期**保留 Geist 文件与注册**，稳定一个版本后单独一刀删除 |
| 7 | 走查「Gothic A1 词性/音标」 | 音标 `phonetic` 用的是系统等宽字体，与本次无关 | 走查清单中去掉音标 |
| 8 | 54 项单元测试 | 约 469 个测试 | 以 `scripts/ci/test-ios.sh` 全绿为准，不写具体数字 |
| 9 | 3 档总增量 ≤ 180KB | 实测子集约 64KB/档，合计约 190KB（仍小于现 Geist 三档 ~247KB） | 指标改为「单档 ≤ 80KB、三档合计小于现 Geist」 |
| 10 | 每阶段「约 5 分钟」 | — | 删除时间估计，改为每刀结束停下汇报、等 PM 确认（CLAUDE.md Working Method） |

---

## 一、需求背景与目标

### 1.1 为什么换
Poplex 字体体系为「Charter（英文衬线）+ Geist（英文无衬线）+ 冬青黑（中文）」。随着品牌从「通用工具」走向 **Warm Minimalism**，Geist 的工业冷硬感偏重。Gothic A1 曲线更圆润、中宫开阔，用来柔化界面控件、标签、说明文字的棱角。

### 1.2 本次范围
- **只换**英文无衬线（UI Sans）。Charter、冬青黑、系统等宽（音标）**一律不动**。
- 所有经 `geist()` 工厂产出的 Token 全部切换（约 40 个），不做逐个挑选。

---

## 二、字体分工

### 2.1 替换后的分工

| 角色 | 字体 | 实际承载（以代码为准） |
|---|---|---|
| 内容衬线 | **Charter**（Regular / Bold） | 词条大标题、卡片主句、页面/分区衬线标题、Onboarding 封面大标题（`onboardingHeroSerif`） |
| 界面无衬线 | **Gothic A1**（Regular / Medium / SemiBold）*本次替换* | `englishBody`、按钮、胶囊、标签、状态提示、日期、Tab 名、Tab2 卡面辅助字等 |
| 中文 | **冬青黑**（W3 / W6） | 中文翻译、中文弱化 |
| 音标 | 系统等宽 | `phonetic`（不变） |

> v1.0 表格写「页面 Hero 标题 = Charter」与代码不符：`AppTheme.Font.hero`（Geist 34）目前**零引用**，实际的 Onboarding 封面标题是 `onboardingHeroSerif`（Charter）。`hero` 属于既有孤儿 Token，本次不顺手删除（按 CLAUDE.md，留给 token hygiene 巡检）。

### 2.2 高曝光 Token（✅ PM 已确认：随工厂一起切换）
以下 3 个 Token 现在都是 Geist 无衬线（`tabLabel` 于 2026-09-01 由衬线改为无衬线），**本次一起换成 Gothic A1**，属于「无衬线换无衬线」，不改变字体性质。

| Token | 用途 | 生产引用数 |
|---|---|---|
| `screenTitle`（22 / SemiBold） | 功能页大标题（Onboarding 实操页等） | 5 |
| `ctaLabel`（17 / SemiBold） | 主按钮文字（Continue / Get Started） | 8 |
| `tabLabel`（15 / Medium） | 顶部 Tab 名称 | 1 |

### 2.3 字重与无衬线分配检查（2026-09-24 代码实查）

**A. 分配现状**：`geist()` 工厂下共 32 个 Token，26 个有生产引用，6 个零引用（`keyPhrase`、`growthStatus`、`actionNote`、`hero`、`tab2HeroMeta`、`tab2HeroWordPartOfSpeech`，留给 token hygiene，本次不动）。有引用的 26 个按字重分三层，逻辑清楚：

| 字重 | 角色 | Token（字号） |
|---|---|---|
| Regular 400 | 要**读**的：正文、说明、状态、计数、元信息 | `englishBody` 17 · `feedbackChipLabel` 15 · `statusNote` 13 · `tab2HeroFootrowWords` 13 · `tab2EmptyStateLine` 13 · `tab2HeroCapsuleMore` 12 · `tab2MoreRowMeta` 12 · `tab2MoreRowTimeline` 11.5 · `tab2MoreRowCapsuleMore` 11 · `pos` 11 · `metaNote` 11 |
| Medium 500 | 要**点**的或导航：次级按钮、标签、Tab 名 | `buddy` 14.5 · `compactActionLabel` 15 · `tabLabel` 15 · `tab2TopicLabel` 13.5 · `tab2ProgressCount` 12 · `tab2ReasonPill` 11.5 |
| SemiBold 600 | 标题、主按钮、小标签 | `screenTitle` 22 · `ctaLabel` 17 · `tab2HeroCTA` 15 · `inlineActionLabel` 13 · `tab2MoreRowCategory` 12 · `tab2HeroChipCategory` 11.5 · `sectionLabel` 11 · `date` 11 · `tab2HeroActivitySectionLabel` 11 |

**B. 发现的问题**

1. **【本次必须修】`CardTypeChip.swift:11` 绕过了字重枚举**：`pos`（Regular）后面又叠了 `.fontWeight(.bold)`，请求的是没打包的 Bold 700。iOS 会自行挑最近的字重或合成假粗体，结果不可控，这正是 §3.4a 强类型枚举要防的事。修法：新增 `cardTypeChipLabel = sans(11, weight: .semibold, relativeTo: .caption2)`，删掉 `.fontWeight(.bold)`。
2. **【建议本次一起修】Tab2 手风琴词条绕过 Token**：`CategoryProgressRow.swift:443` 单词用的是系统 New York 衬线（不是 Charter），`:448` 中文释义用的是系统 SF `.caption`（不是冬青黑）。这不属于无衬线替换，但同在 Tab2 核心区，字体分配与全局规则不一致。修法：新增词条专用 Token（Charter 15 Bold、冬青黑 W3），字号沿用现状，执行方先报方案再改。
3. **【只改注释】语义漂移**：`englishBody` 注释写「英文例句」，实际用于设置行、输入框、空态提示、用户气泡等界面正文；`buddy` 注释写「场景追问」，实际用于 9 个文件里的次级按钮与说明（Not now、Try saying it、话题 chip、对话顶栏话题名等）。本次只把注释改成真实用途，拆分 Token 留给 hygiene。
4. **【已知，不算退化】用户输入里的中文**：`englishBody` 用在用户气泡、输入框、对话用户句（`MessageRow:100`、`TodayView:456`、`InputBar`、`DialogueLineRow:41`）。用户输入中文时，Gothic A1 子集里没有汉字，会回退到系统苹方，不是冬青黑。现在的 Geist 也一样。
5. **【忽略】废弃组件**：`SceneCardRow`、`VocabCardRow`、`ContextFilterBar`、`UndoToast` 用的是系统字体，但生产代码零引用，本次不动。

**C. 字重的视觉分量（PM 已选方案 A，见 §3.7）**

同一档字重，Gothic A1 的字面灰度（墨量）比 Geist **轻约 10%**：

| | Geist | Gothic A1 同档 | Gothic A1 视觉上约等于 Geist 的 |
|---|---|---|---|
| Regular 400 | 0.396 | 0.356（−10%） | 比 Geist Regular 还轻 |
| Medium 500 | 0.455 | 0.416（−9%） | Geist Regular 与 Medium 之间 |
| SemiBold 600 | 0.521 | 0.468（−10%） | Geist Medium |
| Bold 700 | — | 0.519 | Geist SemiBold |

即：按同档映射替换后，全 App 无衬线整体**轻了约半档**。

---

## 三、关键控制点

### 3.1 控制点 1 · 资产瘦身（西文子集）
- **来源**：只用 Google Fonts 官方仓库 `google/fonts/ofl/gothica1/` 的 `GothicA1-Regular.ttf`、`GothicA1-Medium.ttf`、`GothicA1-SemiBold.ttf`（静态 TTF）。不要用 Fontsource 等二次分发的 woff 切片。
- **为什么必须裁**：原包含 1.1 万余个韩文字形，仅 Regular 一档的 woff2 压缩后就有约 1.26MB，TTF 更大。
- **保留字符集**（`pyftsubset --unicodes=`）：
  - `U+0020-007E` Basic Latin
  - `U+00A0-00FF` Latin-1 Supplement
  - `U+0100-017F` Latin Extended-A
  - `U+0250-02AF` IPA Extensions、`U+02B0-02FF` Spacing Modifiers（ˈ ˌ ː 等；音标目前不用本字体，但保留成本极低，防将来挪用时缺字）
  - `U+03B8` 希腊字母 θ（英语 IPA 的 theta 借用希腊字母，不在 IPA Extensions 区块内；只加这一个，不引入整个希腊区块）。*第 1 刀执行时发现的遗漏，2026-09-24 补入*
  - `U+2000-206F` 常用标点（’ “ ” … – — • 等）、`U+20AC` €、`U+2122` ™、`U+2190-2193` 箭头、`U+00D7` × `U+00F7` ÷
- **保留 OpenType 特性**：`--layout-features='*'`（保住字距对 kern、连字等），`--name-IDs='*'`，**不要**改 PostScript 名。
- **已核实**：上述 IPA / Latin Ext-A / 弯引号 / 破折号字形 Gothic A1 均有；字体里**没有汉字**，不会抢冬青黑。`▾`（U+25BE）Gothic A1 没有，Geist 也没有，`MineView.swift:1228` 的 `"3 words ▾"` 仍由系统补字，**不算退化**，无需处理。
- **指标**：单档 ≤ 80KB（实测约 64KB），三档合计小于现 Geist 三档（~247KB）。
- **许可**：Gothic A1 为 SIL OFL 1.1，版权声明中**没有 Reserved Font Name**，因此裁剪和改度量后可以保留原字体名。把 `OFL.txt` 一并放进 `AIEnglishApp/Resources/Fonts/`（OFL 要求随字体分发许可文本）。
- **可复现**：裁剪 + 度量校正写成脚本 `scripts/fonts/build-gothic-a1.sh`（或 `.py`）入库，而不是只提交产物。以后要加字符或换版本时能一键重跑。

### 3.2 控制点 2 · 纵向度量校正（v1.1 新增，本次最大风险）
**问题**：两款字体「文字盒子」的结构不同（单位：em）：

| | 上沿 ascender | 下沿 descender | 行距 lineGap | 大写字母高 |
|---|---|---|---|---|
| Geist Regular / SemiBold（仓库内 v1.002） | 0.920 | 0.220 | 0.100 | 0.710 |
| Geist Medium（仓库内 v1.800，版本与另两档不一致） | 1.005 | 0.295 | 0 | 0.710 |
| Gothic A1（原始） | 0.798 | 0.202 | 0.250 | 0.731 |

**后果**：不校正的话，同样字号下单行高度和字形在盒子里的上下位置都会变，胶囊/按钮里的文字会**上下偏移**（大概率偏上）。Tab2 卡片是固定两行高（Hero 57 / More 50），`Tab2ActivityDisplay.swift:80` 又直接用 `lineHeight` 算高度差，都会受影响。

**做法（在字体文件里一次改好，不要在各组件里零散加 `baselineOffset`）**：子集化后用 fontTools 统一改三档的纵向度量（三档**用同一组值**，保证同族不同字重上下对齐）：
- `hhea.lineGap = 0`、`OS/2.sTypoLineGap = 0`
- 以 Geist Regular 的单行总高 **1.24em** 为目标（ascender + |descender| = 1.24em，行距并入上下沿），并让大写字母高的中线落在盒子正中。按 Gothic A1 Regular 的大写字母高 0.731em 计算，**起始值**：
  - `hhea.ascender = OS/2.sTypoAscender = 1010`（UPM 1024）
  - `hhea.descender = OS/2.sTypoDescender = -260`
- `OS/2.usWinAscent / usWinDescent` **保持 ≥ 字形实际最高/最低点**（SemiBold 最高 1174、最低 -348），不要缩小，否则带重音的大写字母可能被裁切。
- `fsSelection` 的 USE_TYPO_METRICS 位保持开启（原字体已开）。

**验收**：起始值只是计算值，最终以真机截图为准：拿「N words」胶囊、Hero 理由胶囊（`Tab2CardLabels.reasonLine` 算出的文案，如「Added something today」）、主按钮三处，替换前后同位置截图对比，文字视觉上下居中、单行高度与替换前一致（±0.5pt）。若有偏差，只调上面两个数字，重新跑脚本。
> 2026-09-25 第 3 刀执行记录更正：`In progress` / `Mastered` 系 v1 遗留的错误描述，代码里不存在这两处文案（`grep` 全项目零命中），验收改按上述真实元素走查。

> 附带说明：仓库里 Geist Medium 与另两档版本不一致（盒子高度 1.30 vs 1.24em），所以当前所有 Medium 字重的文字（`buddy`、`tab2TopicLabel`、`tab2ProgressCount`、`tabLabel`、`tab2ReasonPill` 等）本来就和另两档对不齐。统一度量后，**Medium 字重处的位移会比其他地方明显**，走查时重点看。

### 3.3 控制点 3 · 字宽：不做补偿，只做观察
- 实测 Gothic A1 比 Geist 窄 2–5%，**不会**出现溢出或意外折行，因此**不改任何内边距、间距、字距**。
- 顶部 Tab 行宽测试（`AIEnglishAppTests.swift:628` 附近）实测的是真实字体宽度，字变窄只会更宽松。
- 走查时要看的是反方向的问题：文字变窄后，胶囊是否显得「空」、与图标的比例是否失衡。有问题**先报告截图，由 PM 决定**，执行方不自行调参。
- `tab2TopicLabel` 维持 13.5pt 不变。

### 3.4 控制点 4 · 字体名单一来源 + 硬编码清理（v1.1 新增）
**4a. 中性命名的强类型字重（替代 v1.0 的 `GothicA1Weight`）**

```swift
// Theme.swift · AppTheme.Font
enum SansWeight {
    case regular, medium, semibold

    /// UI 无衬线字体的 PostScript 名——全 App（含测试、测量代码）唯一来源。
    /// 换字体只改这里。
    var postScriptName: String {
        switch self {
        case .regular:  "GothicA1-Regular"
        case .medium:   "GothicA1-Medium"
        case .semibold: "GothicA1-SemiBold"
        }
    }
}

private static func sans(_ size: CGFloat, weight: SansWeight = .regular,
                         relativeTo style: SwiftUI.Font.TextStyle = .body) -> SwiftUI.Font {
    FontLoader.registerCustomFonts()
    return SwiftUI.Font.custom(weight.postScriptName, size: size, relativeTo: style)
}
```

- `GeistWeight` → `SansWeight`，`geist(...)` → `sans(...)`，约 40 个 Token 调用点机械替换，**字号、字重、`relativeTo` 一律不动**。
- 为什么用中性名：Token 按用途命名（CLAUDE.md Design Token Rules #1）。用品牌名命名，下次换字体又要全局改名。
- 已核实 PostScript 名：`GothicA1-Regular` / `GothicA1-Medium` / `GothicA1-SemiBold`。

**4b. 硬编码清单（全部改为读 `SansWeight.xxx.postScriptName`）**

| 文件 | 行 | 现状 |
|---|---|---|
| `AIEnglishApp/Mine/Components/Tab2ActivityDisplay.swift` | 98 | `UIFont(name: "Geist-Regular", …)!` **生产代码** |
| `AIEnglishAppTests/AIEnglishAppTests.swift` | 628 | `UIFont(name: "Geist-Medium", …)`（tabLabel 行宽测试） |
| `AIEnglishAppTests/AIEnglishAppTests.swift` | 5921、6332、6343 | `UIFont(name: "Geist-Regular", …)!` |
| `AIEnglishApp/DesignLab/…/Tab2CapsuleRefinementPreview.swift` | 714、729、754、769 | UIFont + `Font.custom("Geist-Regular")` |
| `AIEnglishApp/DesignLab/…/Tab2OptionARefinementPreview.swift` | 445 | `Font.custom("Geist-Medium")` |
| `AIEnglishApp/DesignLab/…/Tab2TopicsRefinementPreview.swift` | 388 | `Font.custom("Geist-Medium")` |

- 为什么测试也要改：它们用 `!` 强制解包。将来删掉 Geist 文件时，测试会**直接崩溃**，而不是给出可读的失败信息。
- 同步更新注释里提到 Geist 的地方：`Theme.swift:463`、`:595–597`，`FontLoader.swift:7`，测试 `:589`、`:615–622`、`:5914`。
- 验收：`grep -rn "Geist" AIEnglishApp AIEnglishAppTests --include=*.swift` 只剩过渡期的 FontLoader 注册列表（见 3.6）。

### 3.5 控制点 5 · Dynamic Type 保真
- `sans()` 工厂保留 `relativeTo:`，所有 Token 的 `relativeTo` 原样继承。
- `Tab2ActivityDisplay` 的测量侧继续用 `UIFontMetrics(forTextStyle:).scaledFont(for:)` 复刻缩放，只换字体名。
- 走查时额外用一档无障碍大字号（Accessibility L 以上）看 Tab2 卡片和主按钮。

### 3.6 控制点 6 · 过渡与回滚
- **本次**：`FontLoader` 注册列表 = Gothic A1 三档 + Geist 三档（共 6 个文件）。Geist 文件**保留在包内**。
- **回滚方式**：把 `SansWeight.postScriptName` 的三个字符串改回 `Geist-*`，重新构建。**但注意**：纵向度量不同，回滚后同样要按 3.2 的方法复查一遍截图。
- **清理**：Gothic A1 上线稳定一个版本后，单独一刀删除 Geist 文件并从注册列表移除，并在同一刀确认 `grep "Geist"` 为零。

### 3.7 控制点 7 · 字重映射（✅ PM 已确认：方案 A 同档，2026-09-24）
依据 §2.3-C：

| 方案 | 映射 | 效果 | 代价 |
|---|---|---|---|
| **A · 同档**（✅ 采用） | 400→400 / 500→500 / 600→600 | 整体轻约半档，更「温润、松弛」，贴合换字体的初衷 | 11pt Regular 小字（`pos`、`metaNote`、`tab2MoreRowCapsuleMore`）和 11pt SemiBold 小标签会变细变弱，需第 3 刀重点看 |
| B · 等灰度 | 400→400 / 500→600 / 600→700 | 保持现在的视觉分量，层级对比不变 | 需多打包 Bold 700（约 +64KB），Medium 500 不再使用 |

- 无论选哪个，改的都只是 `SansWeight.postScriptName` 里的映射（B 还要多加一个字体文件），Token 和组件不动。
- **执行 A**：400→400 / 500→500 / 600→600，只打包 Regular / Medium / SemiBold 三档。
- 第 3 刀对比截图重点看 11pt SemiBold 小标签（`sectionLabel`、`date`、`tab2HeroActivitySectionLabel`）和主按钮 `ctaLabel`。若显弱，**只报告截图，由 PM 决定是否切 B**，执行方不自行切换。
- 对照页：`docs/design-system/font_mapping_comparison.html`。

---

## 四、执行步骤（每刀结束停下汇报，等 PM 确认再进下一刀）

### 第 1 刀 · 字体资产
1. 下载官方三档 TTF + `OFL.txt`，记录来源 commit / 版本号（应为 Version 2.50）。
2. 写并运行 `scripts/fonts/build-gothic-a1.sh`：子集化（3.1）+ 纵向度量校正（3.2 起始值）。
3. 产物放入 `AIEnglishApp/Resources/Fonts/`，确认已打进 App Bundle。
4. **汇报**：三档文件大小、PostScript 名、改后的 ascender/descender/lineGap、子集 codepoint 数量。

### 第 2 刀 · Token 底座 + 硬编码
1. `FontLoader` 注册列表加入 Gothic A1 三档（Geist 保留）。
2. `Theme.swift`：`SansWeight` + `sans()`，全部 Token 切换（3.4a）。
3. 清理 3.4b 全部 10 处硬编码 + 注释。
3b. 修 §2.3-B 第 1 条（`CardTypeChip` 的 `.fontWeight(.bold)`）；更新 `englishBody`、`buddy` 注释为真实用途（第 3 条）；第 2 条（手风琴词条）先报方案，PM 确认后再改。
4. 为 FontLoader 补单测：断言 3 个 Gothic A1 PostScript 名在注册后都能 `UIFont(name:)` 取到（用 `#require`，不用 `!`）。
5. 跑 `bash scripts/ci/test-ios.sh`。
6. **汇报**：测试结果（通过/失败 + 具体报错），`grep "Geist"` 剩余结果。

### 第 3 刀 · 真机走查与度量微调
按下表截图（替换前 / 替换后，同设备、同状态、同 Dynamic Type 档位）：

| 页面 | 重点看 |
|---|---|
| Tab2 Topics 列表 | 手风琴展开、`N words ▾` 胶囊文字上下居中、类别名与图标对齐 |
| Tab2 卡面 | Hero 57 / More 50 固定高度内胶囊组不溢出、`Added N times today` 等理由胶囊文字居中、`+N more` 对齐 |
| Tab1 学习卡 | Charter 单词标题与 Gothic A1 词性、`englishBody` 例句的主次与行距 |
| screenTitle + 主按钮 | screenTitle/ctaLabel 实际生产落点是 `MicPermissionView`（"Voice access needed" + "Open Settings"），不在 Onboarding 流程内；文字居中、无异常折行 |
| 顶部 Tab 栏 | `tabLabel` 与毛玻璃胶囊的位置 |
| 设置页 | 行文字与图标对齐 |

- 有偏移时只调 3.2 的 ascender / descender 两个数，重跑脚本。**不在组件层打补丁。**
- **汇报**：每组截图 + 逐张文字描述画面实际内容（CLAUDE.md「视觉产物自查」：先描述画面，再下结论）。宽度相关的观感问题（3.3）只报告，不自行改参数。

### 第 4 刀 · 收尾
1. 再跑一次 `bash scripts/ci/test-ios.sh`，全绿。
2. 更新 `docs/design-system/字体排印系统规范-多语言学习产品.md` 中的字体分工描述。
3. 本地 Git commit。提 PR 按 CLAUDE.md 的 Ship 三阶段流程，只有 PM 明确说「提 PR」才执行。

---

## 五、风险与应对

| 风险 | 严重度 | 应对 |
|---|---|---|
| 纵向度量导致文字上下偏移、卡片高度变化 | **中** | 3.2 在字体文件层统一校正 + 第 3 刀截图对照 |
| 测试因硬编码字体名崩溃 | 中 | 3.4b 全部改为单一来源 + `#require` |
| Medium 字重处位移比其他地方明显 | 中 | 3.2 附带说明，第 3 刀重点看 |
| 文字变窄导致胶囊显「空」 | 低 | 只报告截图，PM 决定是否调 |
| 字体加载失败回退到系统字体 | 低 | FontLoader 新增单测断言三档可取 |
| 视觉不达预期需回退 | 低 | Geist 过渡期保留，改 `postScriptName` 即可切回（需复查截图） |

---

## 附录 · 实测数据（2026-09-24）

**字宽**（整串字符宽度，单位 em，Regular 档）：

| 文本 | Geist | Gothic A1 | 差 |
|---|---|---|---|
| `14 words` | 4.135 | 4.063 | −1.7% |
| `In progress` | 5.222 | 5.059 | −3.1% |
| `Mastered` | 4.436 | 4.321 | −2.6% |
| `Continue` | 4.210 | 4.062 | −3.5% |
| `The quick brown fox jumps over the lazy dog` | 20.808 | 19.840 | −4.7% |

**字重可用性**：Gothic A1 100–900 九档齐全，本次只打包 400 / 500 / 600。

**子集体积**（Latin + Latin-ext 转 TTF）：400 ≈ 64KB，500 ≈ 63KB，600 ≈ 64KB。

**大写字母高 / 字形上下极值**（UPM 1024）：Regular 749 / 1137 / −329；Medium 763 / 1155 / −339；SemiBold 777 / 1174 / −348。

**仓库内 Geist 文件**：Regular、SemiBold 为 Version 1.002（ascender 920 / descender −220 / lineGap 100）；Medium 为 Version 1.800（1005 / −295 / 0）。两个版本并存。

---

## 执行记录（2026-09-24 ~ 2026-09-25，分支 `design/typography-optimization`）

### 第 1 刀 · 字体资产 — commit `9e4b7e9`
- 来源：`google/fonts` 仓库 `ofl/gothica1/`，固定 commit `3ab2d94b`，版本 Version 2.50。
- 子集化（含第 1 刀验收时补入的 `U+03B8` 希腊字母 θ，IPA theta 借用）+ 去 TrueType hinting + 纵向度量统一校正。
- 产物体积：Regular 58.5KB / Medium 38.1KB / SemiBold 59.4KB，合计 ≈156KB（Geist 三档合计 ≈241KB）。
- 度量起始值：`ascender 1010` / `descender -260` / `lineGap 0`（UPM 1024）——第 3 刀真机走查未发现需要调整的偏移，**全程未改过这三个数**。
- 子集含 543 个码点，含 IPA 相关字符与 θ。
- 构建脚本：`scripts/fonts/build-gothic-a1.py`（可重复运行，内置固定 commit 下载 + 子集化 + 度量校正）。

### 第 2 刀 · Token 底座 + 硬编码清理 — commit `c200653`
- `Theme.swift`：`GeistWeight` → `SansWeight`（新增 `postScriptName` 计算属性，全 App 唯一 PostScript 名来源），`geist()` → `sans()`，约 40 个 Token 机械切换（含 `screenTitle`/`ctaLabel`/`tabLabel`）。
- 清理全部 10 处硬编码 Geist 字体名（生产 `Tab2ActivityDisplay.swift` + DesignLab 3 个文件 + 测试 4 处），改读 `SansWeight.xxx.postScriptName`。
- 新增 `CardTypeChip` 专用 Token `cardTypeChipLabel`（sans 11 SemiBold），修掉原来 `pos + .fontWeight(.bold)` 请求未打包字重的问题。
- 补 `FontLoaderTests`（3 条，断言三档 Gothic A1 均可通过 `UIFont(name:)` 取到）。
- `test-ios.sh`：480 个测试，476 passed + 4 skipped（既有、无关）+ 0 failed，Passed。

### 第 3 刀 · 真机走查与度量微调 — commit `f1fe669`（手风琴换装）+ `3ae4456`（MicPermissionView 修复）
- **手风琴词条换装**（`CategoryProgressRow.WordEntryRow`）：新增独立 Token `tab2WordEntryTitle`（Charter 15 Bold）+ `tab2WordEntryMeaning`（冬青黑 W3 12pt），不复用 `tab2HeroWord`/`tab2HeroWordMeaning`——避免 Hero 卡与词条列表被同一 Token 耦合。真机替换前后对照截图确认字形确实换成了 Gothic A1（非未生效），位置/行高无回归。
- **验收清单更正**：v1.1 §3.2、第 3 刀截图表格里的「14 words」是示例数值，「`In progress`/`Mastered`」是 v1 遗留的错误描述——代码里不存在这两处文案（`grep` 全项目零命中），已按实际元素（`N words` 胶囊、`Tab2CardLabels.reasonLine` 算出的理由胶囊文案）修正验收标准（见上方表格与 §3.2）。
- **screenTitle + 主按钮的真实落点**：不在 Onboarding 流程内（Onboarding 各屏用的是 `pageTitleSerif`/`onboardingLeadSerif`），实际生产使用处是 `MicPermissionView`（"Voice access needed" + "Open Settings"）。
- **发现并修复一处 Bug**：`MicPermissionView` 的标题 `Text` 没有横向 `padding`，Accessibility XL 档下 Gothic A1 单行宽度恰好卡进屏幕宽度，标题从两行变一行、贴到左右屏幕边缘。补 `AppTheme.Space.paddingPage`（现有页面边距 Token）修复，两档截图验证换行与留白恢复正常。
- **发现并登记一处既有布局缺陷（不在本次修复范围）**：Accessibility XL 档下，Tab2 Hero 区块的 `VStack`（`MineView.swift:839`）本身就会超出父级给的宽度——这个缺陷在换字体之前就存在（Geist 时超 14.33pt，Gothic A1 时超 4.33pt，字面更窄让超出量变小），不是本次换字体引入的回归，已登记为 `优化需求全量清单_v1.md` **B17**，附完整分层宽度实测数据。
- `test-ios.sh`：480 个测试，476 passed + 4 skipped（既有、无关）+ 0 failed，Passed（手风琴换装与 MicPermissionView 修复分别验证）。

### 第 4 刀 · 收尾 — commit（本次）
- 登记 B17（见上）。
- 补本节执行记录 + 更正 §3.2、第 3 刀表格的验收标准。
- 最终 `test-ios.sh` 全绿 + `grep "Geist"` 只剩 `FontLoader` 过渡期注册列表 + `git status` 干净，见对应 commit。
