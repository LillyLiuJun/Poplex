#if DEBUG
import SwiftUI

// 旧方案（预设浅底单色深字，2026-10-06 已废弃）的墨色。线上 Token 已删除，本历史预览自带一份，保持画面不变。
private let legacyPresetLabelInk = Color(red: 138 / 255, green: 74 / 255, blue: 32 / 255)  // #8A4A20
private let legacyReasonInkOnLightArt = Color(red: 138 / 255, green: 74 / 255, blue: 32 / 255).opacity(0.72)

/// Tab2 12个生活分类预设卡（Hero卡 vs More行）全景视觉实验室
///
/// 对应设计稿 `design/tab2_preset_12_categories.html` 与生产代码：
/// - 生产绘制：`CategoryPresetArtView.swift` (150pt Hero 画布)
/// - 生产缩略图：`RowPresetThumb.swift` (76×119pt More 列表行缩略图，由 Hero 裁出)
/// - 生产组件：`Tab2HeroCard.swift` & `Tab2ActivityRow.swift`
/// - 色阶规范：全走 `AppTheme.Color.tab2PresetArt*` 5 个核心语义 Token
struct Tab2PresetCardsMatrixPreview: View {
    @State private var viewMode: ViewMode = .heroCards
    @State private var hasActivities: Bool = true
    @State private var isHotReason: Bool = true
    @State private var selectedCategory: SceneCategory = .food

    enum ViewMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case heroCards   = "1. Hero 卡全景流 (12 分类)"
        case moreRows    = "2. More 行全景流 (12 分类)"
        case sideBySide  = "3. Hero vs 缩略图 对照检视"
        case pureArt     = "4. 纯插画画廊与 12 宫格"
        case tokenSpec   = "5. 色阶与 Token 规范"
    }

    var body: some View {
        VStack(spacing: 0) {
            topControls
            Divider().opacity(0.15)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    switch viewMode {
                    case .heroCards:
                        heroCardsSection
                    case .moreRows:
                        moreRowsSection
                    case .sideBySide:
                        sideBySideSection
                    case .pureArt:
                        pureArtSection
                    case .tokenSpec:
                        tokenSpecSection
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 16)
                .padding(.bottom, 60)
            }
            .background(AppTheme.Color.pageBg.ignoresSafeArea())
        }
    }

    // MARK: - 顶部控制栏

    private var topControls: some View {
        VStack(spacing: 12) {
            Picker("视图模式", selection: $viewMode) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 16) {
                Toggle(isOn: $hasActivities) {
                    Text(hasActivities ? "正常态 (含两行胶囊)" : "空态 (Only words so far)")
                        .font(AppTheme.Font.tab2EmptyStateLine)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.Color.brandStrong))

                Divider().frame(height: 18)

                Toggle(isOn: $isHotReason) {
                    Text(isHotReason ? "Hot 理由 (今天活跃)" : "Quiet 理由 (无新素材)")
                        .font(AppTheme.Font.tab2EmptyStateLine)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }
                .toggleStyle(SwitchToggleStyle(tint: AppTheme.Color.brandStrong))
            }

            if viewMode == .sideBySide {
                HStack {
                    Text("当前检视分类:")
                        .font(AppTheme.Font.actionNote)
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Picker("选择分类", selection: $selectedCategory) {
                        ForEach(SceneCategory.allCases, id: \.self) { cat in
                            Text(cat.englishLabel).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)

                    Spacer()
                }
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 12)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 1. Hero 卡全景流 (12 分类)

    private var heroCardsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "全 12 分类 Hero 卡全景流",
                subtitle: "生产组件 Tab2HeroCard 实装展示 · 150pt 实心 primary300 预设底 + 浅底深字单色标签（无不可控照片 shadow）"
            )

            ForEach(SceneCategory.allCases, id: \.self) { category in
                heroCardItem(for: category)
            }
        }
    }

    private func heroCardItem(for category: SceneCategory) -> some View {
        let info = PresetCategoryInfo.of(category)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(category.englishLabel)
                    .font(AppTheme.Font.compactSectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Text("(\(info.chineseName))")
                    .font(AppTheme.Font.actionNote)
                    .foregroundStyle(AppTheme.Color.textMuted)

                Spacer()

                Text(info.elements)
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.brandInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.Color.tab2PresetArtSurface)
                    .clipShape(Capsule())
            }

            Tab2HeroCard(
                category: makeCategoryData(for: category),
                onTalk: {}
            )
        }
    }

    // MARK: - 2. More 行全景流 (12 分类)

    private var moreRowsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "全 12 分类 More 列表行全景流",
                subtitle: "生产组件 Tab2ActivityRow 实装展示 · 76×119pt 缩略图由对应 Hero 画面裁切生成，两处永远同源"
            )

            VStack(spacing: 12) {
                ForEach(SceneCategory.allCases, id: \.self) { category in
                    Tab2ActivityRow(
                        category: makeCategoryData(for: category),
                        onTap: {}
                    )
                }
            }
        }
    }

    // MARK: - 3. Hero vs More 缩略图 对照检视

    private var sideBySideSection: some View {
        let info = PresetCategoryInfo.of(selectedCategory)
        return VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "Hero 卡 vs More 缩略图 1:1 对照检视",
                subtitle: "检视同源裁切：左侧 7pt 细条原位保留，右侧主物体左移 40pt 贴近细条后等比缩小，两处构图浑然一体"
            )

            // 构成说明卡
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(selectedCategory.englishLabel)
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text("· \(info.chineseName)")
                        .font(AppTheme.Font.englishPrimary)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    elementChip(label: "主物体 (primary100)", value: info.mainObject)
                    elementChip(label: "细条 (7pt primary800)", value: info.accentBar)
                    elementChip(label: "辅物 (primary700)", value: info.secondaryObject)
                }
            }
            .padding(14)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))

            // 1. Hero 真实卡
            VStack(alignment: .leading, spacing: 8) {
                Text("① Hero 预设卡（150pt 全画幅顶图）")
                    .font(AppTheme.Font.actionNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Tab2HeroCard(
                    category: makeCategoryData(for: selectedCategory),
                    onTalk: {}
                )
            }

            // 2. More 列表行
            VStack(alignment: .leading, spacing: 8) {
                Text("② More 列表行（76×119pt 左侧缩略图）")
                    .font(AppTheme.Font.actionNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Tab2ActivityRow(
                    category: makeCategoryData(for: selectedCategory),
                    onTap: {}
                )
            }

            // 3. 裸缩略图放大透视
            VStack(alignment: .leading, spacing: 12) {
                Text("③ 缩略图细节放大约 1.5× 透视")
                    .font(AppTheme.Font.actionNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)

                HStack(spacing: 20) {
                    VStack(spacing: 6) {
                        RowPresetThumb(category: selectedCategory)
                            .frame(width: 76 * 1.5, height: 119 * 1.5)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.Color.cardBorder, lineWidth: 1))
                        Text("114 × 178.5 (1.5×)")
                            .font(AppTheme.Font.metaNote)
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }

                    VStack(spacing: 6) {
                        RowPresetThumb(category: selectedCategory)
                            .frame(width: 76, height: 119)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Color.cardBorder, lineWidth: 1))
                        Text("76 × 119 (1:1 实际尺寸)")
                            .font(AppTheme.Font.metaNote)
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("裁切与对齐特性：")
                            .font(AppTheme.Font.sectionLabel)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                        Text("• 裁切窗口：x: 114, y: 10, w: 120, h: 188\n• 分割线 x=170 右侧主物体整体左移 40pt\n• 细条距离左边沿约 1/4 处，留白匀称\n• 主物体辨识度饱满，绝不露边角残缺")
                            .font(AppTheme.Font.metaNote)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }
                }
                .padding(16)
                .background(AppTheme.Color.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            }
        }
    }

    // MARK: - 4. 纯插画画廊与 12 宫格

    private var pureArtSection: some View {
        VStack(alignment: .leading, spacing: 32) {
            sectionHeader(
                title: "纯插画画廊与 12 宫格缩略图",
                subtitle: "脱去卡身外壳，纯粹检视 12 个分类的矢量插画与缩略图的视觉节奏与几何语言"
            )

            // 12 宫格缩略图
            VStack(alignment: .leading, spacing: 12) {
                Text("More 缩略图 12 宫格全景阵列 (76 × 119)")
                    .font(AppTheme.Font.compactSectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 16
                ) {
                    ForEach(SceneCategory.allCases, id: \.self) { category in
                        VStack(spacing: 6) {
                            RowPresetThumb(category: category)
                                .frame(height: 119)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.Color.cardBorder, lineWidth: 0.5))
                                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)

                            Text(category.englishLabel)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }
                .padding(16)
                .background(AppTheme.Color.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
            }

            // 12 张 Hero 纯图流
            VStack(alignment: .leading, spacing: 16) {
                Text("Hero 纯图画廊 (150pt 全画幅)")
                    .font(AppTheme.Font.compactSectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                ForEach(SceneCategory.allCases, id: \.self) { category in
                    pureHeroArtItem(for: category)
                }
            }
        }
    }

    private func pureHeroArtItem(for category: SceneCategory) -> some View {
        let info = PresetCategoryInfo.of(category)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.englishLabel)
                    .font(AppTheme.Font.keyPhrase)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Text("— \(info.elements)")
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textMuted)
                Spacer()
            }

            CategoryPresetArtView(category: category)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).stroke(AppTheme.Color.cardBorder, lineWidth: 0.5))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 3)
        }
    }

    // MARK: - 5. 色阶与 Token 规范

    private var tokenSpecSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "色阶与设计 Token 规范",
                subtitle: "严格遵循「方向 1」定稿规范，5 组语义 Token 清晰映射，完全替代旧版白渐变与光晕"
            )

            // Token 色卡
            VStack(spacing: 10) {
                tokenColorRow(
                    token: "AppTheme.Color.tab2PresetArtBackground",
                    primitive: "primary300 (#FFDFCC)",
                    role: "卡片纯色底色，无渐变、无光晕、无投影",
                    color: AppTheme.Color.tab2PresetArtBackground
                )
                tokenColorRow(
                    token: "AppTheme.Color.tab2PresetArtSurface",
                    primitive: "primary100 (#FFF3EB)",
                    role: "右侧被裁切的主物体大浅色块",
                    color: AppTheme.Color.tab2PresetArtSurface
                )
                tokenColorRow(
                    token: "AppTheme.Color.tab2PresetArtDetail",
                    primitive: "primary400 (#FFD3B8)",
                    role: "主物体内部细节线条（固定 2pt 粗细）",
                    color: AppTheme.Color.tab2PresetArtDetail
                )
                tokenColorRow(
                    token: "AppTheme.Color.tab2PresetArtAccent",
                    primitive: "primary800 (#FF914E)",
                    role: "左侧 7pt 宽实心细长条，垂直伸出底边",
                    color: AppTheme.Color.tab2PresetArtAccent
                )
                tokenColorRow(
                    token: "AppTheme.Color.tab2PresetArtSecondary",
                    primitive: "primary700 (#FFA36B)",
                    role: "放在主物体上的实心辅物",
                    color: AppTheme.Color.tab2PresetArtSecondary
                )
                tokenColorRow(
                    token: "（已废弃，线上 Token 已删除）旧方案深棕字",
                    primitive: "#8A4A20 (深棕色)",
                    role: "旧方案：预设浅底上的单色类别标签（理由文字走 72% 透明度）；现已统一纯白，不分流",
                    color: legacyPresetLabelInk
                )
            }
            .padding(16)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))

            // 规则总结
            VStack(alignment: .leading, spacing: 10) {
                Text("三要素构图核心原则")
                    .font(AppTheme.Font.keyPhrase)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                bulletPoint("1. 构图同源：Hero 预设图与 More 行缩略图共用 PresetArtwork.draw 唯一入口，缩略图裁切永远与 Hero 保持一致。")
                bulletPoint("2. 浅底深字：预设图为 primary300 实底，标签换为纯文字 + 无 shadow，不再用不可控照片层的深色投影。")
                bulletPoint("3. 拒绝重叠：卡身（Recent activities）不再上叠进图片（artTextOverlap = 0），避免小标题紧贴色块硬边。")
                bulletPoint("4. 统一尺寸：Hero 预设图固定高度 150pt；More 缩略图固定尺寸 76×119pt。")
            }
            .padding(16)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        }
    }

    // MARK: - 辅助子视图与 Mock 构造

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Text(subtitle)
                .font(AppTheme.Font.actionNote)
                .foregroundStyle(AppTheme.Color.textMuted)
                .lineSpacing(3)
        }
    }

    private func elementChip(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(AppTheme.Color.textMuted)
            Text(value)
                .font(AppTheme.Font.metaNote)
                .foregroundStyle(AppTheme.Color.textPrimary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(AppTheme.Color.pageBg)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func tokenColorRow(token: String, primitive: String, role: String, color: Color) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 44, height: 44)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.1), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(primitive)
                        .font(AppTheme.Font.keyPhrase)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Spacer()
                }
                Text(token)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(AppTheme.Color.brandInk)
                Text(role)
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(AppTheme.Font.keyPhrase)
                .foregroundStyle(AppTheme.Color.brandStrong)
            Text(text)
                .font(AppTheme.Font.actionNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(2)
        }
    }

    private func makeCategoryData(for category: SceneCategory) -> Tab2CategoryData {
        let info = PresetCategoryInfo.of(category)
        let activities: [Tab2Activity] = hasActivities ? info.activities.map {
            Tab2Activity(sceneDetail: $0, occurrenceCount: 2, cover: nil)
        } : []

        let lastDate: Date? = isHotReason ? Date() : Calendar.current.date(byAdding: .day, value: info.quietDaysAgo, to: Date())
        let newCount: Int = isHotReason ? info.hotNewCount : 0

        return Tab2CategoryData(
            sceneCategory: category.rawValue,
            wordCount: info.wordCount,
            unlocked: true,
            notSpokenCount: 8,
            lastTalkedAt: lastDate,
            lastMaterialAt: lastDate,
            newMaterialCount: newCount,
            activityCount: activities.count,
            activities: activities
        )
    }
}

// MARK: - 12 分类辅助元信息

private struct PresetCategoryInfo {
    let chineseName: String
    let elements: String
    let mainObject: String
    let accentBar: String
    let secondaryObject: String
    let activities: [String]
    let wordCount: Int
    let quietDaysAgo: Int
    let hotNewCount: Int

    static func of(_ cat: SceneCategory) -> PresetCategoryInfo {
        switch cat {
        case .food:
            return PresetCategoryInfo(
                chineseName: "餐饮美食",
                elements: "餐盘 · 叉子 · 勺子",
                mainObject: "象牙白大圆餐盘 (r=90)",
                accentBar: "7pt 优雅餐叉 (伸出底边)",
                secondaryObject: "斜卧椭圆深匙 (-32°)",
                activities: ["Dinner at home", "Coffee and pastry", "Late-night ramen"],
                wordCount: 52, quietDaysAgo: -5, hotNewCount: 3
            )
        case .workStudy:
            return PresetCategoryInfo(
                chineseName: "工作学业",
                elements: "横线纸 · 铅笔 · 便利贴",
                mainObject: "横线笔记本纸页 (-6°)",
                accentBar: "7pt 尖头铅笔",
                secondaryObject: "正方形便利贴 (+9°)",
                activities: ["Sprint planning meeting", "Writing design review", "Inbox zero"],
                wordCount: 78, quietDaysAgo: -14, hotNewCount: 2
            )
        case .homeFamily:
            return PresetCategoryInfo(
                chineseName: "家庭人际",
                elements: "房子 · 钥匙 · 窗",
                mainObject: "大尖顶房子轮廓与拱门",
                accentBar: "7pt 齿轮长钥匙",
                secondaryObject: "田字格明亮方窗",
                activities: ["Living room declutter", "Cooking with family", "Sunday chores"],
                wordCount: 43, quietDaysAgo: -7, hotNewCount: 1
            )
        case .dailyRoutines:
            return PresetCategoryInfo(
                chineseName: "日常起居",
                elements: "钟面 · 牙刷 · 指针",
                mainObject: "整点刻度大钟面 (r=88)",
                accentBar: "7pt 刷毛牙刷",
                secondaryObject: "9pt 时针与 6pt 分针",
                activities: ["Morning skincare routine", "Stretching before sleep", "Setting alarm"],
                wordCount: 39, quietDaysAgo: -21, hotNewCount: 2
            )
        case .shopping:
            return PresetCategoryInfo(
                chineseName: "购物消费",
                elements: "购物袋 · 衣架钩 · 价签",
                mainObject: "弧形双提手购物袋 (-5°)",
                accentBar: "7pt 弯钩衣架",
                secondaryObject: "打孔折角商品价签 (+14°)",
                activities: ["Weekend grocery haul", "Buying new headphones", "Receipt scanning"],
                wordCount: 64, quietDaysAgo: -4, hotNewCount: 2
            )
        case .gettingAround:
            return PresetCategoryInfo(
                chineseName: "出行交通",
                elements: "地图 · 路牌 · 定位针",
                mainObject: "三折页虚线路线地图 (-6°)",
                accentBar: "7pt 箭头方向路牌",
                secondaryObject: "经典水滴形定位大图钉",
                activities: ["Subway morning commute", "Walking past old town", "Flight layover"],
                wordCount: 56, quietDaysAgo: -5, hotNewCount: 1
            )
        case .healthFitness:
            return PresetCategoryInfo(
                chineseName: "运动健康",
                elements: "瑜伽垫 · 球拍 · 水瓶",
                mainObject: "双条纹圆角瑜伽垫 (-8°)",
                accentBar: "7pt 网球拍",
                secondaryObject: "凸字形便携运动水壶 (+12°)",
                activities: ["Evening 5k run", "Core workout session", "Hydration log"],
                wordCount: 47, quietDaysAgo: -6, hotNewCount: 1
            )
        case .leisure:
            return PresetCategoryInfo(
                chineseName: "休闲娱乐",
                elements: "翻开的书 · 画笔 · 耳机",
                mainObject: "展平翻开的厚精装书页",
                accentBar: "7pt 尖头排笔",
                secondaryObject: "圆润耳罩头戴式耳机",
                activities: ["Finishing novel chapter", "Acoustic guitar practice", "Watercolor sketch"],
                wordCount: 61, quietDaysAgo: -14, hotNewCount: 1
            )
        case .tech:
            return PresetCategoryInfo(
                chineseName: "科技数码",
                elements: "手机 · 数据线 · 通知气泡",
                mainObject: "大圆角智能手机屏幕 (+8°)",
                accentBar: "7pt 编织数据线插头",
                secondaryObject: "长药丸形通知胶囊",
                activities: ["Testing iOS beta", "Setting up smart lights", "Code debugging"],
                wordCount: 85, quietDaysAgo: -10, hotNewCount: 2
            )
        case .weather:
            return PresetCategoryInfo(
                chineseName: "天气环境",
                elements: "云 · 雨伞 · 太阳",
                mainObject: "层叠蓬松三圆大云朵",
                accentBar: "7pt 弯柄雨伞",
                secondaryObject: "右上角微露圆太阳 (r=26)",
                activities: ["Sudden autumn drizzle", "Golden hour sunset walk", "Crisp morning breeze"],
                wordCount: 36, quietDaysAgo: -4, hotNewCount: 1
            )
        case .social:
            return PresetCategoryInfo(
                chineseName: "情绪社交",
                elements: "对话气泡 · 小花 · 心",
                mainObject: "大圆角双向对话气泡",
                accentBar: "7pt 绽放五瓣花枝",
                secondaryObject: "实心微倾爱心 (+12°)",
                activities: ["Catchup call with Alice", "Feeling energized today", "Team lunch chat"],
                wordCount: 58, quietDaysAgo: -7, hotNewCount: 1
            )
        case .other:
            return PresetCategoryInfo(
                chineseName: "其他场景",
                elements: "点阵卡片 · 星光棒 · 星",
                mainObject: "精密圆孔点阵记录卡 (-7°)",
                accentBar: "7pt 魔法星光细棒",
                secondaryObject: "灵动四角凹弧星",
                activities: ["Unsorted voice memo", "Random street poster", "Quick thought note"],
                wordCount: 29, quietDaysAgo: -30, hotNewCount: 1
            )
        }
    }
}

#Preview("Tab2 预设卡 12 分类全景实验室") {
    Tab2PresetCardsMatrixPreview()
}
#endif
