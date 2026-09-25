# Tab2 视觉断层分析与温暖基线回归方案评估报告

> **文档性质**：设计评审与技术实施评估方案  
> **文档版本**：v2.0（基于代码事实与 main 基线原生 Token 校准）  
> **评审目标**：供产品、设计与工程负责人评估 Tab2 视觉体验回归方案，确保业务资产零丢失、视觉品质全治愈。  
> **对应基线**：`main` 生产基线原生代码 vs 当前开发分支（基于“刀 6/6b”重构）

---

## 一、 需求背景与核心问题定位

在对当前开发分支进行真机视觉走查与代码比对时，发现界面整体质感出现了严重的**视觉断层**：

* **`main` 生产基线**：通透、温润、呼吸感强，有明确的高级出版物纸质质感（Warm Minimalism），卡片留白自然，顶部带有标志性的晨曦双光晕环境光；
* **当前分支（刀 6/6b）**：暗沉、发灰、发硬，大面积充斥着工业冷灰泥色块，无图与异常状态冰冷死板，原本的品牌温暖通透感被完全破坏。

### 1.1 关键事实排查（代码与色彩事实溯源）

通过对代码仓库与色彩令牌（Design Tokens）的严格审计，确认了以下关键事实：

1. **大底色代码并未篡改**：
   页面最底层背景依然是 `AppTheme.Color.pageBg`（十六进制 `#FCF8F3`），渲染像素完全一致，证明整体基底并没有坏。
2. **环境漫射光源被一刀切拔除**：
   在“刀 6”切片中，为了统合图标资源，一刀切删除了 Hero 卡无实拍图时的**晨曦双光晕（Primary 400 + Secondary 柔雾）与三段暖白渐变基底**，换成了单调死板的**平底冷灰 `#F3EDE6`**；列表行缩略图的双色暖粉杏渐变（`#FFF3EB` → `#FFDFCC`）也被砍除。
3. **新增业务组件带来了大面积“工业灰泥色”堆叠**：
   * **代码事实澄清**：在 `main` 基线代码中，**Tab2 Hero 卡原本根本没有“两行活动胶囊（Activity Chips）”**，只有单句或 3 行词汇的极简展示；
   * “两行活动胶囊”是近期为了承载“分类下聚合多个活动”而**新加入的业务功能**；
   * 刀 6b 引入活动胶囊时，随手定义了一个未纳管的冷灰泥色 `tab2ActivityChipBg`（`#F4EFE8`）。每张卡片塞入 2 行灰泥色胶囊，吃掉了卡片 60% 以上的视觉面积，导致整个卡面直接被染灰染脏。
4. **Hero 卡偶发异常直接暴露报错图标（破相）**：
   当网络抖动或临时链接过期导致图片下载失败时，前端直接在卡片顶端暴露灰色的感叹号占位块（`ImageLoadFailedPlaceholder`），给用户带来粗糙的“软件崩了”的心理感受。
5. **调色稳健性原则**：
   手机截图因 Display P3 广色域转换、iOS 系统渲染合成与图片压缩，吸色必然存在偏差。**最稳健的方式是严禁截图吸色，100% 溯源 `main` 分支既有的 Design Token 代码体系进行色彩对齐。**

---

## 二、 核心改造原则

针对上述问题，既不能退回到没有活动胶囊的旧版，也不能放任视觉继续恶化。改造确立的核心原则是：

> **「业务结构 100% 继承刀 6b，色彩材质 100% 回归 main 基线」**

1. **业务资产零丢失**：
   100% 保留刀 6b 的全部信息架构与业务逻辑——包括活动胶囊两行槽机制、让位折叠算法（`Tab2CapsuleFit`）、小标题、理由胶囊、Words 词数体系。
2. **色彩材质 100% 原生回归**：
   拔除所有散落的工业冷灰泥色，所有组件材质直接在 `main` 基线原生的 `Theme.swift` 令牌体系中寻找同源解，恢复品牌核心的「Warm Minimalism（温暖极简）」。
3. **消费级容错体验（Graceful Degradation）**：
   消除任何粗暴的工程化报错图标暴露，极端弱网与异常场景下静默平滑降级，确保首屏永远自洽、优雅。

---

## 三、 四大模块详细修改方案

### 模块 1：预设图全面恢复 main 基线晨曦漫射光感
* **涉及文件**：
  * [`CategoryPresetArtView.swift`](file://<repo>-typography-optimization/AIEnglishApp/Mine/Components/CategoryPresetArtView.swift)
  * [`RowPresetThumb.swift`](file://<repo>-typography-optimization/AIEnglishApp/Mine/Components/RowPresetThumb.swift)
  * [`Theme.swift`](file://<repo>-typography-optimization/AIEnglishApp/Theme/Theme.swift)
* **具体改动**：
  1. **Hero 预设图**：完全废弃刀 6 的平底冷灰 `#F3EDE6`，100% 复原 `main` 基线原生代码：
     * **渐变基底**：三段式暖杏漫射渐变（`#FCF8F3` @ 0% → `#FCF8F5` @ 62% → `#FFFFFF` @ 100%）；
     * **晨曦主光晕**：`primaryBloom`，采用 `primary400`（`#FFD3B8` @ 55% 透明度，36pt 柔雾模糊）；
     * **晨曦副光晕**：`secondaryBloom`，采用 `tab2HeroPresetBloomSecondary`（`#FFEEE2` @ 90% 透明度）；
     * **品牌点缀印记**：保留 `brandStrong`（`#FF7622` @ 92%）纯正暖橙小圆点；
     * **手绘细线图标**：恢复 12 分类专属矢量线框图标（`presetIconInk` `#965832` @ 26% 细线描边）。
  2. **列表行缩略图**：从冷灰平底恢复为 `main` 基线的双色暖粉渐变（`primary100` `#FFF3EB` → `primary300` `#FFDFCC`）。
* **预期效果**：
  无论用户有无配图，首屏都拥有充盈自然的漫射暖光，杜绝占位破败感，找回品牌标志性灵魂。

---

### 模块 2：活动胶囊去灰泥化，全面对齐 main 温暖纸质体系
* **涉及文件**：
  * [`Tab2ActivityDisplay.swift`](file://<repo>-typography-optimization/AIEnglishApp/Mine/Components/Tab2ActivityDisplay.swift)
  * [`Tab2ActivityRow.swift`](file://<repo>-typography-optimization/AIEnglishApp/Mine/Components/Tab2ActivityRow.swift)
  * [`Theme.swift`](file://<repo>-typography-optimization/AIEnglishApp/Theme/Theme.swift)
* **具体改动**：
  不使用任何截图吸色，直接采用 `main` 基线原生 Token 规范胶囊材质：
  * **底色调整**：彻底移除冷灰泥色 `tab2ActivityChipBg`（`#F4EFE8`），改用 `main` 基线原生暖纸底 **`AppTheme.Color.pageBg`（`Primitive.neutral50` `#FCF8F3`）** 或最浅暖杏阶 **`Primitive.primary50`（`#FFF8F4`）**；
  * **边框调整**：叠加 `main` 基线原生的 **`AppTheme.Color.cardBorder`（0.5pt 细微暖柔线，`#2B2521` @ 8%）**，为实体建立轻盈自然的触碰边界；
  * **文字字色**：严格使用 `main` 基线主墨字 **`AppTheme.Color.textPrimary`（`Primitive.neutral900` `#211811`）**。
* **预期效果**：
  胶囊在暖白卡片（`warmWhite` `#FFFDFB`）上天然形成清晰却柔和的微层级，彻底消除 60% 面积的发脏感，使卡片重新恢复出版物般的整洁清爽。

---

### 模块 3：图上标签轻量化与通透化（去膏药感）
* **涉及文件**：
  * [`Tab2HeroCard.swift`](file://<repo>-typography-optimization/AIEnglishApp/Mine/Components/Tab2HeroCard.swift)
* **具体改动**：
  * **浅色预设图上（OnLight 态）**：采用微透白底（`Color.white.opacity(0.85)`）+ 0.5pt 暖柔微边，文字使用深炭墨字，理由圆点高亮纯正暖橙（`#FF7622`）；
  * **真实照片上（Photo 态）**：保留深色半透明托底，但优化通透度与内边距，消除生硬的黑块感。
* **预期效果**：
  标签轻盈、自然地浮于画面之上，不再像生硬贴在卡片上的“黑膏药”。

---

### 模块 4：图片加载异常的优雅降级机制
* **涉及文件**：
  * [`CachedRemoteImage.swift`](file://<repo>-typography-optimization/AIEnglishApp/Mine/Components/CachedRemoteImage.swift)
  * [`HeroCollageView.swift`](file://<repo>-typography-optimization/AIEnglishApp/Mine/Components/HeroCollageView.swift)
  * [`Tab2HeroCard.swift`](file://<repo>-typography-optimization/AIEnglishApp/Mine/Components/Tab2HeroCard.swift)
* **异常频次与根因分析（技术事实）**：
  * **出现频次**：在真实生产环境下为**「极低频偶发事件」**。正常网络下，图片经 Signed URL 下载一次后即进入手机内存与磁盘两级缓存，后续为 0 延迟秒开；
  * **偶发诱因**：① 用户在地铁/电梯中网络瞬间断开或超时；② App 长期切后台唤醒后，Supabase 短效 Signed URL 临时失效（HTTP 403）；③ 本地测试阶段 mock 外链不可达。
* **具体改动**：
  * 纠正原报告中把 Tab1 审核拦截文案（`This content can't be processed`）与 Tab2 混淆的问题；Tab2 原本直接暴露的是 `ImageLoadFailedPlaceholder` 的灰色三角感叹号；
  * **改造策略**：当 Hero 图片加载失败或链接失效时，**不再直接暴露灰色感叹号报错占位**，而是**静默降级为模块 1 的晨曦暖光预设图**。
* **预期效果**：
  在任何极端弱网或数据延迟场景下，用户打开 Tab2 看到的永远是一张完整、优雅的晨曦主题插画卡，不会产生“软件出 Bug 坏掉了”的恐慌，网络恢复或刷新后自然重新展示实拍照片。

---

## 四、 涉及代码清单与影响范围

| 影响模块 | 涉及文件 | 变动性质 | 业务影响 |
|---|---|---|---|
| **晨曦预设图** | `CategoryPresetArtView.swift`<br>`RowPresetThumb.swift` | 恢复 main 基线绘图逻辑 | 纯样式，无逻辑副作用 |
| **活动胶囊** | `Tab2ActivityDisplay.swift`<br>`Tab2ActivityRow.swift` | 胶囊样式改为 main 纸质 Token | 纯样式，保持两行槽位机制 |
| **图上标签** | `Tab2HeroCard.swift` | OnLight 浅底标签通透化 | 纯样式，逻辑保持一致 |
| **异常降级** | `HeroCollageView.swift`<br>`Tab2HeroCard.swift` | 图片加载失败降级为预设图 | 提升容错体验，不改网络底层 |
| **设计令牌** | `AIEnglishApp/Theme/Theme.swift` | 集中收敛语义 Token，移除灰泥色 | 全局规范化，杜绝硬编码 |

---

## 五、 评审决策表（供评审人确认）

| 决策项 | 改造提议 | 依据与优势 | 评审结论 |
|---|---|---|---|
| **1. 预设图方向** | 放弃平底冷灰（`#F3EDE6`），**全面恢复 main 基线晨曦双光晕、三段渐变与手绘图标** | 100% 对齐 main 原生代码，找回品牌 Warm Minimalism 灵魂，消灭冰冷死板感 | **建议通过** |
| **2. 胶囊材质方向** | 放弃灰泥色（`#F4EFE8`），**采用 main 原生纸质色盘（`neutral50` / `primary50` + 0.5pt 暖微边）** | 拒绝截图吸色偏差，严格在既有 Token 体系内取值，消灭 60% 灰暗脏感，与卡片浑然一体 | **建议通过** |
| **3. 异常处理机制** | 放弃灰色感叹号报错占位，**图片异常时静默降级为晨曦暖光预设图** | 生产环境低频偶发现象；贯彻容错设计（Fault Tolerance），保证首屏永远体面完整 | **建议通过** |
