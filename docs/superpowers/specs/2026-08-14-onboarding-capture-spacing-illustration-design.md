# Onboarding 第三屏 · 拍照采集页虚线卡区域「间距 + 插画」优化设计

- **日期**：2026-08-14
- **分支**：`feat/onboarding-view3-optimize`
- **范围**：`OnboardingCaptureView` 空态（选照片前）的虚线动作卡区域：卡内间距、插画。
  页面其余部分（标题、返回按钮、样例图条、Continue、进度点）与全部交互逻辑**不动**。
- **依据**：PM 2026-08-14 书面批评 5 点 + 多轮渲染稿确认。最终视觉以
  `design/onboarding-final-v4.html`（右帧 = 定稿）为准。

## 一、背景：为什么要改

PM 对现网虚线卡区域的五点批评（原文归纳）：

1. **视觉重心失衡**：纸雕是不规则软形，与页面规整圆角极简语言冲突；右上橙色
   小圆点悬空在图形外、像未完成的提示红点；卡内上下留白节奏忽松忽紧。
2. **虚线容器缺陷**：虚线框只有描边没有弱底色，模块边界存在感弱、无悬浮感。
3. **按钮细节**：图标与文字间距偏小、按钮显扁平、按钮间无呼吸。
4. **文字层级**：「Add your photo」粗体权重接近页面大标题，层级被打乱。
5. **整体构图**：卡内内容垂直居中、上下留白均等，呆板。

方向性结论（PM 在过程中明确）：**间距借鉴 2026-08-14 早些时候「返回按钮方案」
那批整页稿（`design/onboarding-back-button-options.html`，主 checkout）的节奏；
视觉设计保留我们自己的**（纸雕、虚线框、描边胶囊、颜色、字重均保留）。
插画最终由 PM 逐轮挑选定为「⑦a-s1 温和分散 + 0.7 缩放」。

## 二、最终规格（v6 定稿 · 2026-08-15 修订：仅动虚线框内部）

### 2.1 卡内间距（v6 定稿）

虚线卡：`x=20, y=286, w=362, h=293.2`（内容自适应），rx=28，描边 `border` #E3DFD9
1.5pt、dash 6/6 —— 与现网相同（无底色填充，维持现网样式）。

| 段 | 值 | 对应 token |
|---|---|---|
| 卡顶边距 | **32** | `paddingSection` |
| 插画（名义框 104×72，内容缩放 **0.9**） | — | `onboardingUploadIllustrationWidth/Height` |
| 插画 → 「Add your photo」 | **16** | `paddingCard` |
| 标题：**衬线 17 半粗**（复用 `cardSentence`，= 时刻卡英文主句字） | 行高 21.15 | `Font.cardSentence` |
| 标题 → Camera | **24** | `titleToContent`（按钮组额外 `.padding(.top, paddingS)` 实现 16+8=24） |
| Camera（44 高胶囊，保持现网） | — | `Size.barControl` |
| 按钮间 | **8** | `paddingS` |
| Gallery | 44 高 | 同 Camera |
| 卡底边距 | **32** | `paddingSection` |

上下边距对称 32/32。按钮内部图标-文字间距保持 8，按钮宽保持 176。

### 2.2 页面段落间距（**本轮不动**，保持已实现值）

以下为 Task 1 已落地、继续保留的值，v6 不再改动：

| 段 | 值 |
|---|---|
| 标题 → 副标题 | 12（`paddingM`） |
| 副标题 → 虚线卡 | 20（`paddingPage`）→ 卡顶 y=286 |
| 虚线卡 → 「Or try a sample」 | 16（`paddingCard`） |
| 样例标题 → 图条 | 8（`paddingS`） |
| 样例图间距 | 8（`paddingS`） |

卡高增加后，「Or try a sample」与样例图条随内容流自然下移（图条底
≈735，与 Continue 顶 731.7 近乎齐平、轻微压入 3.5pt，可滑动，PM 已确认接受）。

### 2.3 插画（v6：上轮定稿 + 0.9 缩放）

三层纸卡 + 风景窗结构、颜色、坐标与上轮定稿完全一致；仅把整体缩放
从 0.7 改为 **0.9**（名义框 104×72 不变，`OnboardingCaptureIllustration`
的 `.scaleEffect(0.7)` → `.scaleEffect(0.9)`，其余一行不动）。

### 2.4 明确不变（防回退清单）

- 虚线框样式（1.5 / 6-6 / rx28 / 无填充）
- Camera/Gallery 胶囊：44 高、rx22、cardBg 底 + border 1.5、图标 14、文字 13 semibold、图标-文字 8
- 标题字重最终改为**衬线 17 半粗**（`cardSentence`，复用现有 token，不新增）
- 全部颜色/字体 token、框外全部段落间距、页面其余元素、交互与状态逻辑不动
- **底部光晕与 Continue 的层叠关系：PM 2026-08-15 决定暂挂，待间距落地后另行微调**（方向：光晕中心上移至 Continue 背后避免横切感，未定稿）

三层纸卡（全部带 `paperShadow`：`Shadow.paperLayer*`，即 neutral900 5%、
radius 4、y 4）：

| 层 | 矩形（104×72 坐标内） | 圆角 | 旋转 | 填充 |
|---|---|---|---|---|
| 后层 | (0, 4) 86×64 | rx16 | -12°（绕 43,36） | `brandTint` #FFEADE |
| 中层 | (12, 12) 76×56 | rx16 | +9°（绕 50,40） | `neutralFaint` #C7C3BD @50% |
| 前层 | (24, 18) 60×46 | rx14 | 0° | `cardBg` #FFFDF8 |

前卡风景窗（50×36 @ (29,23)，rx11，clip 于窗内）：

- 天空：线性渐变 `primary50` #FFF8F4 → `primary100` #FFF3EB（上→下）
- 太阳：圆 r5.04 @ (65, 33.8)，`brandStrong` #FF7622（≈直径 10pt，符合
  「饱和橙仅 ≤30pt 小面积」规则）
- 山 1（远）：`M29,59 L48,41.7 L63,59 Z`，`neutral100` #EBE8E3
- 山 2（近）：`M44,59 L60,44.1 L80,59 Z`，`neutral200` #E3DFD9

已移除：相机字形（原 `camera` SF Symbol 24pt）、悬空橙色小圆点。

## 三、实现注意点（v6 已实现，留档）

1. **本轮（v6）改动**（2026-08-15 已实现，commit 见 git log）：
   - actionCard 空输入态：外层 VStack `spacing: paddingM`→`paddingCard`；
     标题字体 `ctaLabel`→`cardSentence`（衬线 17 半粗）；按钮组追加
     `.padding(.top, paddingS)`（16+8=24）；卡上下边距 `paddingPage`→`paddingSection`。
   - `OnboardingCaptureIllustration`：`.scaleEffect(0.7)`→`.scaleEffect(0.9)`。
   - **框外零改动**：标题/副标题/样例区间距与图间距保持 Task 1 已实现值
     （12/20/16/8/8），仅随卡高自然下移。
2. **卡片几何变化**：卡顶保持 y=286（副标题→卡 20），卡高由内容自适应为
   293.2（卡底 ≈579.2）。「Or try a sample」标签基线 ≈614.5，图条 y≈631.2、
   图间距 8。图条底 ≈735，轻微压入 Continue（顶 731.7）3.5pt，可滑动，PM 已确认。
3. **间距值全部落既有 token**，**不新增 token**；标题字体复用既有
   `cardSentence` token（不新增字体 token）。
4. **不动的逻辑**：`applyStagedImage`、aspect 校验、`registerNewSelection`、
   `scrollSelectedPhotoIfNeeded`、`carouselFrame` 屏蔽区、结果态/兜底态全部不碰。
5. **验证方法**：模拟器截图 + 元素 frame 实测 + 与 `design/onboarding-final-v5.html`
   右侧「v6 定稿 · 仅框内」帧的像素对比（卡区逐行均值差 <15、插画区 <10）。
6. **交付文件**：最终视觉稿 `design/onboarding-final-v5.html`（右帧 = v6 定稿）；
   像素级基线 `design/onboarding-capture-page.svg`（现网）与
   `design/onboarding-capture-page-paste.svg`（Figma 可粘贴版）。
   其余 `onboarding-*options*.html` 为过程稿，存档不进入实现。
7. **待办（挂起）**：底部光晕与 Continue 的层叠调整（光晕中心上移至 Continue
   背后，避免「光晕被按钮横切」观感），PM 决定间距落地后另行微调。

## 四、验收标准（v6）

- 虚线卡内实测间距 = 32/16/24/32（±1pt；上下边距 32，插画→标题 16，
  标题→Camera 24）
- 框外段落间距与图间距 = 12/20/16/8/8（与 v6 改动前一致，实测不变）
- 「Add your photo」= 衬线 17 半粗（cardSentence）
- 插画与 2.3 规格一致（三层纸、风景窗、橙太阳、0.9 缩放、无相机无悬空点）
- 卡片圆角/描边/胶囊按钮与现网一致（仅框内间距、标题字体与插画缩放变化）
- 选照片、校验、自动滚动、翻页手势等交互行为与现网一致；单测全绿
