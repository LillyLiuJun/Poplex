#if DEBUG
import SwiftUI

/// Tab2 Hero 分类标签、理由胶囊与卡片基线全真沙箱 (Hero Labels, Reason & Baseline Sandbox)
///
/// 🎯 核心定位与原则：
/// 1. 100% 消费生产同源组件：Tab2HeroCard、Tab2CardLabels、SceneCategory、Theme.swift；
/// 2. 覆盖不可控实拍照片封面（深色、高光、暖色）与 12 大分类手绘预设艺术底（方案 A 色阶实心底）；
/// 3. 覆盖全业务状态：Hot 态 (今日记录 1 次/多条)、Quiet 沉静态 (昨日/数日/一周/一月)、Only words 空态；
/// 4. 显式呈现双光谱色彩与排印契约：分类标签 (13pt Regular) + 推荐理由 (11.5pt Medium) 的微观解构。
struct Tab2HeroAndEmptyStateParityPreviewView: View {
    @State private var selectedTabSection: SectionTab = .interactiveBaseline
    @State private var selectedCoverType: CoverType = .photoDark
    @State private var selectedPresetCategory: SceneCategory = .food
    @State private var selectedReasonState: ReasonStateOption = .hotMultiple
    @State private var emptyMode: EmptyLayoutMode = .compareBoth
    @State private var toastMessage: String?

    enum SectionTab: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case interactiveBaseline  = "1. Hero 交互基线全景"
        case photoSpectrum        = "2. 照片底 · 状态全光谱"
        case presetSpectrum       = "3. 预设底 · 12分类矩阵"
        case microInspector       = "4. 微观标尺 · 规格解剖"
        case emptyLayoutCompare   = "5. 空态高度对比 (历史)"
    }

    enum CoverType: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case photoDark    = "照片 · 咖啡深调"
        case photoBright  = "照片 · 办公高光"
        case photoWarm    = "照片 · 日常晨曦"
        case photoOutdoor = "照片 · 旅行户外"
        case presetArt    = "预设 · 手绘艺术底"
    }

    enum ReasonStateOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case hotMultiple  = "Hot · 今日 3 次"
        case hotSingle    = "Hot · 今日 1 次"
        case quiet1Day    = "Quiet · 昨天"
        case quiet4Days   = "Quiet · 4 天前"
        case quiet1Week   = "Quiet · 1 周前"
        case quiet1Month  = "Quiet · 1 月前"
        case onlyWords    = "空态 · Only words"
    }

    enum EmptyLayoutMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case compareBoth = "A / B 方案平铺对比"
        case routeA      = "路线 A: 现状 (收窄变矮)"
        case routeB      = "路线 B: 保槽位 (高度恒定) ⭐"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerControl

            Divider().opacity(0.15)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedTabSection {
                    case .interactiveBaseline:
                        interactiveBaselineSection
                    case .photoSpectrum:
                        photoSpectrumSection
                    case .presetSpectrum:
                        presetSpectrumSection
                    case .microInspector:
                        microInspectorSection
                    case .emptyLayoutCompare:
                        emptyLayoutSection
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 16)
                .padding(.bottom, 60)
            }
            .background(AppTheme.Color.pageBg.ignoresSafeArea())
        }
        .overlay(alignment: .bottom) {
            if let toast = toastMessage {
                Text(toast)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.black.opacity(0.8)))
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - 顶栏控制
    private var headerControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Tab2 Hero 分类标签与理由样式沙箱")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Spacer()
                Text("最新基线")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppTheme.Color.brandStrong.opacity(0.12))
                    .clipShape(Capsule())
            }

            Picker("模块选择", selection: $selectedTabSection) {
                ForEach(SectionTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 12)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 1. Hero 交互基线全景
    private var interactiveBaselineSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "Hero 卡片全真交互基线",
                subtitle: "100% 直连生产 Tab2HeroCard 组件。支持实时切换封面背景类型、12 大手绘分类与理由状态。"
            )

            // 控制面板卡片
            VStack(alignment: .leading, spacing: 14) {
                Text("场景参数控制台")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Color.textSecondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("封面底图类型:").font(.caption2).foregroundStyle(AppTheme.Color.textMuted)
                    Picker("封面底图", selection: $selectedCoverType) {
                        ForEach(CoverType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if selectedCoverType == .presetArt {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("预设手绘艺术分类:").font(.caption2).foregroundStyle(AppTheme.Color.textMuted)
                        Picker("预设分类", selection: $selectedPresetCategory) {
                            ForEach(SceneCategory.allCases, id: \.self) { cat in
                                Text(cat.englishLabel).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("推荐理由状态:").font(.caption2).foregroundStyle(AppTheme.Color.textMuted)
                    Picker("理由状态", selection: $selectedReasonState) {
                        ForEach(ReasonStateOption.allCases) { state in
                            Text(state.rawValue).tag(state)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .padding(14)
            .background(AppTheme.Color.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.medium).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))

            // 当前实装参数指示器
            currentSpecPillGroup

            // 生产 Hero 卡片实机呈现
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("▍ 生产组件 Tab2HeroCard 渲染结果")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                    Spacer()
                    Text("单开手风琴入口")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Color.textMuted)
                }

                Tab2HeroCard(
                    category: buildInteractiveCategoryData(),
                    onTalk: { showToast("点击 Hero 卡片：触发 Start talking") }
                )
            }
        }
    }

    private var currentSpecPillGroup: some View {
        HStack(spacing: 8) {
            specTag(label: "分类标签", value: "13pt Regular", color: AppTheme.Color.tab2HeroPhotoOverlayText, bg: Color.black.opacity(0.65))
            specTag(label: "理由胶囊", value: "11.5pt Medium", color: AppTheme.Color.tab2ReasonPillOnPhotoText, bg: Color.black.opacity(0.65))
            specTag(label: "投影状态", value: "半径 6pt / Y 1pt (方案 A 统一)", color: AppTheme.Color.textPrimary, bg: AppTheme.Color.cardBorder.opacity(0.5))
        }
    }

    private func specTag(label: String, value: String, color: Color, bg: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(AppTheme.Color.textMuted)
            Text(value).font(.system(size: 11, weight: .bold)).foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - 2. 照片底 · 全状态全光谱展示
    private var photoSpectrumSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "照片底 · 理由全状态全光谱走查",
                subtitle: "实拍背景下：纯白 13pt 裸字分类 + 白 82% 理由文字 + 6pt 黑色投影。Hot 态与 Quiet 态共用同一套高对比配色，克制不喧宾夺主。"
            )

            VStack(spacing: 14) {
                photoStateCard(title: "1. Hot 态 · 今日记录 3 次", note: "高频活跃 · 文案自解释", reason: "Added 3 times today", cat: "Food & Drink", url: MockData.photoCoffeeUrl)
                photoStateCard(title: "2. Hot 态 · 今日首次记录", note: "温和鼓励 · 单数文案", reason: "Added something today", cat: "Daily Routine", url: MockData.photoMorningUrl)
                photoStateCard(title: "3. Quiet 态 · 昨天有记录", note: "自然过渡 · since yesterday", reason: "Nothing new since yesterday", cat: "Work & Study", url: MockData.photoWorkUrl)
                photoStateCard(title: "4. Quiet 态 · 4 天未记", note: "温和唤醒 · in 4 days", reason: "Nothing new in 4 days", cat: "Social & Feelings", url: MockData.photoSocialUrl)
                photoStateCard(title: "5. Quiet 态 · 满 1 周未记", note: "周阶折叠 · in the last week", reason: "Nothing new in the last week", cat: "Travel & Commute", url: MockData.photoTravelUrl)
                photoStateCard(title: "6. Quiet 态 · 满 1 月天花板", note: "30天克制 · 绝不说90天", reason: "Nothing new in a month", cat: "Health & Fitness", url: MockData.photoHealthUrl)
            }
        }
    }

    private func photoStateCard(title: String, note: String, reason: String, cat: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.caption.weight(.bold)).foregroundStyle(AppTheme.Color.textPrimary)
                Spacer()
                Text(note).font(.caption2).foregroundStyle(AppTheme.Color.textMuted)
            }

            // 提取完整 Tab2HeroCard 展示真实状态
            Tab2HeroCard(
                category: makePhotoCategory(cat: cat, reasonText: reason, url: url),
                onTalk: {}
            )
        }
    }

    // MARK: - 3. 预设底 · 12 分类矩阵
    private var presetSpectrumSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "预设底 · 12 分类手绘艺术底图",
                subtitle: "无可控照片时降级为 150pt primary300 实心预设底：单色焦糖深字 (#8A4A20) + 72% 次级理由文字，0 投影零脏晕。"
            )

            LazyVStack(spacing: 16) {
                ForEach(SceneCategory.allCases, id: \.self) { cat in
                    presetCardItem(category: cat)
                }
            }
        }
    }

    private func presetCardItem(category: SceneCategory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(category.englishLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Spacer()
                Text("手绘线稿 + 实色底")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            Tab2HeroCard(
                category: makePresetCategory(cat: category),
                onTalk: {}
            )
        }
    }

    // MARK: - 4. 微观标尺 · 规格解剖
    private var microInspectorSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "Hero 标签与理由排印微观标尺",
                subtitle: "逐像素解剖分类标签、理由胶囊、间距与双底色适配光学法则。"
            )

            // 标尺卡片 1：照片深底
            macroSpecCard(
                title: "A. 不可控照片底 (Photo Cover)",
                desc: "54pt 顶部 Scrim 压光 + 纯白 13pt Regular + 白82% 11.5pt Medium + 6pt 投影",
                isLight: false
            )

            // 标尺卡片 2：预设浅底
            macroSpecCard(
                title: "B. 预设艺术浅底 (Preset Art)",
                desc: "primary300 暖杏实底 + 焦糖深字 (#8A4A20) + 72% 次级理由字 + 0 投影",
                isLight: true
            )

            // 设计规范对比表
            specSummaryTable
        }
    }

    private func macroSpecCard(title: String, desc: String, isLight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.bold)).foregroundStyle(AppTheme.Color.textPrimary)
            Text(desc).font(.caption).foregroundStyle(AppTheme.Color.textSecondary)

            ZStack(alignment: .topLeading) {
                if isLight {
                    Rectangle()
                        .fill(AppTheme.Color.tab2PresetArtBackground)
                        .frame(height: 72)
                } else {
                    CachedRemoteImage(signedUrl: MockData.photoCoffeeUrl, stableKey: MockData.photoCoffeeUrl, placeholder: { Rectangle().fill(Color.black) })
                        .frame(height: 72)
                        .clipped()
                        .overlay(Rectangle().fill(Color.black.opacity(0.35)))
                }

                // 实际标签行（方案 A 统一：全量纯白裸字 + 柔焦微阴影）
                HStack(spacing: 8) {
                    Text("Food & Drink")
                        .font(AppTheme.Font.tab2HeroChipCategory)
                        .foregroundStyle(AppTheme.Color.tab2HeroPhotoOverlayText)
                        .shadow(color: AppTheme.Color.tab2HeroPhotoOverlayShadow.opacity(AppTheme.Tab2Hero.Opacity.photoTextShadow), radius: 6, y: 1)

                    Text("Added 3 times today")
                        .font(AppTheme.Font.tab2ReasonPill)
                        .foregroundStyle(AppTheme.Color.tab2ReasonPillOnPhotoText)
                        .shadow(color: AppTheme.Color.tab2HeroPhotoOverlayShadow.opacity(AppTheme.Tab2Hero.Opacity.photoTextShadow), radius: 6, y: 1)
                }
                .padding(.top, AppTheme.Tab2Hero.Layout.chipTopLeading)
                .padding(.leading, AppTheme.Tab2Hero.Layout.chipTopLeading)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
        }
        .padding(14)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var specSummaryTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("物理参数与 Token 映射清单 (方案 A 全量统一)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.Color.textPrimary)

            VStack(spacing: 8) {
                specRow(item: "分类标签字号", token: "AppTheme.Font.tab2HeroChipCategory", spec: "Gothic A1 13.0pt Regular")
                specRow(item: "理由胶囊字号", token: "AppTheme.Font.tab2ReasonPill", spec: "Gothic A1 11.5pt Medium")
                specRow(item: "标签与理由间距", token: "photoTopRow HStack(spacing: 8)", spec: "8.0 pt")
                specRow(item: "距离卡片顶边/左边", token: "AppTheme.Tab2Hero.Layout.chipTopLeading", spec: "12.0 pt (Primitive.space12)")
                specRow(item: "文字柔焦微投影", token: "photoOverlayShadowRadius / Y", spec: "Radius 6.0pt / Y 1.0pt / 50% 黑 (全量统一)")
                specRow(item: "分类标签文字颜色", token: "AppTheme.Color.tab2HeroPhotoOverlayText", spec: "#FFFFFF 纯白 (方案 A 全量统一)")
                specRow(item: "理由胶囊文字颜色", token: "AppTheme.Color.tab2ReasonPillOnPhotoText", spec: "#FFFFFF @ 82% 柔白 (方案 A 全量统一)")
            }
        }
        .padding(14)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func specRow(item: String, token: String, spec: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item).font(.caption.weight(.medium)).foregroundStyle(AppTheme.Color.textPrimary)
                Text(token).font(.system(size: 10, design: .monospaced)).foregroundStyle(AppTheme.Color.textMuted)
            }
            Spacer()
            Text(spec).font(.caption.weight(.bold)).foregroundStyle(AppTheme.Color.brandStrong)
        }
        .padding(.vertical, 4)
        .dividerLine()
    }

    // MARK: - 5. 空态高度对比 (历史传承)
    private var emptyLayoutSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeader(
                title: "Hero 与 More 卡片：空态高度对比",
                subtitle: "核心对比：无活动时是‘收窄变矮（现状）’还是‘保 52pt/45pt 槽位、维持标准高度（路线 B）’？"
            )

            VStack(alignment: .leading, spacing: 12) {
                sampleBadge(label: "【生产标准】Hero 正常态 (含活动胶囊) · 标准 52pt 槽高", isRouteB: false)
                Tab2HeroCard(category: MockData.heroNormalPhoto, onTalk: {})
            }

            VStack(alignment: .leading, spacing: 12) {
                sampleBadge(label: "【路线 A · 现状】Hero 空态 (无活动) · 槽位取消，卡片缩水变矮", isRouteB: false)
                Tab2HeroCard(category: MockData.heroEmptyPhoto, onTalk: {})
            }

            VStack(alignment: .leading, spacing: 12) {
                sampleBadge(label: "【路线 B · 推荐】Hero 空态 (无活动) · 保留 52pt 槽位，高度恒定一致 ⭐", isRouteB: true)
                HeroCardRouteB(category: MockData.heroEmptyPhoto, onTalk: {})
            }
        }
    }

    // MARK: - 辅助组件与生成器
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(2)
        }
    }

    private func sampleBadge(label: String, isRouteB: Bool) -> some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(isRouteB ? AppTheme.Color.brandStrong : AppTheme.Color.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(isRouteB ? AppTheme.Color.brandStrong.opacity(0.12) : AppTheme.Color.cardBorder.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func showToast(_ msg: String) {
        toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if toastMessage == msg { toastMessage = nil }
        }
    }

    // MARK: - 交互数据构造
    private func buildInteractiveCategoryData() -> Tab2CategoryData {
        let scString: String
        let coverUrl: String?

        switch selectedCoverType {
        case .photoDark:
            scString = "food_drink"
            coverUrl = MockData.photoCoffeeUrl
        case .photoBright:
            scString = "work_study"
            coverUrl = MockData.photoWorkUrl
        case .photoWarm:
            scString = "daily_routines"
            coverUrl = MockData.photoMorningUrl
        case .photoOutdoor:
            scString = "getting_around"
            coverUrl = MockData.photoTravelUrl
        case .presetArt:
            scString = selectedPresetCategory.rawValue
            coverUrl = nil
        }

        let (date, count): (Date?, Int) = {
            switch selectedReasonState {
            case .hotMultiple: return (Date(), 3)
            case .hotSingle:   return (Date(), 1)
            case .quiet1Day:   return (Calendar.current.date(byAdding: .day, value: -1, to: Date()), 0)
            case .quiet4Days:  return (Calendar.current.date(byAdding: .day, value: -4, to: Date()), 0)
            case .quiet1Week:  return (Calendar.current.date(byAdding: .day, value: -7, to: Date()), 0)
            case .quiet1Month: return (Calendar.current.date(byAdding: .day, value: -30, to: Date()), 0)
            case .onlyWords:   return (nil, 0)
            }
        }()

        let activities: [Tab2Activity] = {
            if selectedReasonState == .onlyWords { return [] }
            return [
                Tab2Activity(sceneDetail: "Morning coffee & discussion", occurrenceCount: 4, cover: coverUrl.map { Tab2Activity.Cover(materialId: "m1", imageUrl: $0) }),
                Tab2Activity(sceneDetail: "Reviewing weekly milestones", occurrenceCount: 2)
            ]
        }()

        return Tab2CategoryData(
            sceneCategory: scString,
            wordCount: 48,
            unlocked: true,
            lastMaterialAt: date,
            newMaterialCount: count,
            activityCount: activities.count,
            activities: activities
        )
    }

    private func makePhotoCategory(cat: String, reasonText: String, url: String) -> Tab2CategoryData {
        let isHot = reasonText.contains("today")
        let daysAgo: Int = {
            if reasonText.contains("yesterday") { return 1 }
            if reasonText.contains("4 days") { return 4 }
            if reasonText.contains("last week") { return 7 }
            if reasonText.contains("a month") { return 30 }
            return 0
        }()
        let date = isHot ? Date() : Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())
        let count = isHot ? 3 : 0

        return Tab2CategoryData(
            sceneCategory: SceneCategory.from(cat).rawValue,
            wordCount: 42,
            unlocked: true,
            lastMaterialAt: date,
            newMaterialCount: count,
            activityCount: 2,
            activities: [
                Tab2Activity(sceneDetail: "Primary daily activity", occurrenceCount: 3, cover: Tab2Activity.Cover(materialId: "p1", imageUrl: url)),
                Tab2Activity(sceneDetail: "Secondary conversation practice", occurrenceCount: 1)
            ]
        )
    }

    private func makePresetCategory(cat: SceneCategory) -> Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: cat.rawValue,
            wordCount: 35,
            unlocked: true,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()),
            newMaterialCount: 0,
            activityCount: 2,
            activities: [
                Tab2Activity(sceneDetail: "Routine exercise in category", occurrenceCount: 2),
                Tab2Activity(sceneDetail: "General practice session", occurrenceCount: 1)
            ]
        )
    }
}

private extension View {
    func dividerLine() -> some View {
        overlay(alignment: .bottom) {
            Divider().opacity(0.12)
        }
    }
}

// MARK: - 路线 B 保持槽位高度的测试组件
private struct HeroCardRouteB: View {
    let category: Tab2CategoryData
    let onTalk: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private var display: Tab2ActivityDisplay { Tab2ActivityDisplay.compute(category: category) }
    private var usesPresetArt: Bool { display.photoCover == nil }

    var body: some View {
        Button(action: onTalk) {
            VStack(spacing: 0) {
                topArt
                    .overlay(alignment: .topLeading) {
                        // 与生产 Tab2HeroCard 同一个组件：并排 / 放不下换两行；空时间的 Only words so far 封面不显示。
                        let state = Tab2CardLabels.reasonPillState(lastMaterialAt: category.lastMaterialAt, newMaterialCount: category.newMaterialCount)
                        Tab2HeroCoverLabels(
                            categoryName: category.englishLabel,
                            reasonText: state.text == Tab2CardLabels.onlyWordsSoFar ? nil : state.text,
                            onPresetArt: usesPresetArt
                        )
                        .padding(.top, AppTheme.Tab2Hero.Layout.chipTopLeading)
                        .padding(.leading, AppTheme.Tab2Hero.Layout.chipTopLeading)
                        .padding(.trailing, AppTheme.Tab2Hero.Layout.chipTopLeading)
                    }

                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: AppTheme.Tab2Hero.Layout.sectionLabelToCapsules) {
                        Text("Recent activities")
                            .font(AppTheme.Font.tab2HeroActivitySectionLabel)
                            .tracking(AppTheme.Tab2Hero.Layout.sectionLabelTracking)
                            .textCase(.uppercase)
                            .foregroundStyle(AppTheme.Color.textMuted)

                        if display.showsActivities {
                            Tab2ActivityCapsuleGroup(
                                activities: display.valid,
                                activityCount: category.activityCount,
                                blockedCount: display.blockedCount,
                                metrics: Tab2ActivityCapsuleMetrics.hero(),
                                nameFont: AppTheme.Font.tab2HeroCapsuleName,
                                moreFont: AppTheme.Font.tab2HeroCapsuleMore
                            )
                        } else {
                            VStack(alignment: .leading, spacing: 0) {
                                Tab2OnlyWordsLine()
                                    .frame(height: AppTheme.Tab2Hero.Layout.activityCapsuleRowHeight, alignment: .leading)
                                Spacer(minLength: 0)
                            }
                            .frame(height: Tab2ActivityCapsuleMetrics.hero().twoRowHeight)
                        }
                    }
                    .padding(.top, AppTheme.Tab2Hero.Layout.bodyTopInset)

                    HStack(alignment: .center, spacing: AppTheme.Space.paddingS) {
                        Text(Tab2CardLabels.words(category.wordCount))
                            .font(AppTheme.Font.tab2HeroFootrowWords)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .layoutPriority(1)
                        Spacer(minLength: 0)
                        HStack(spacing: AppTheme.Tab2Hero.Layout.ctaContentGap) {
                            Text("Start talking")
                            Image(systemName: "arrow.right").imageScale(.small)
                        }
                        .font(AppTheme.Font.tab2HeroCTA)
                        .foregroundStyle(AppTheme.Color.textOnChip)
                        .padding(.horizontal, AppTheme.Tab2Hero.Layout.ctaHorizontalInset)
                        .frame(height: AppTheme.Tab2Hero.Layout.ctaHeight)
                        .background(
                            AppTheme.Color.interactive,
                            in: RoundedRectangle(
                                cornerRadius: AppTheme.Tab2Hero.Layout.ctaCornerRadius,
                                style: .continuous
                            )
                        )
                    }
                    .padding(.top, AppTheme.Tab2Hero.Layout.activityToCTA)
                }
                .padding(.horizontal, AppTheme.Tab2Hero.Layout.bodyHorizontalInset)
                .padding(.bottom, AppTheme.Tab2Hero.Layout.bodyBottomInset)
                .offset(y: usesPresetArt ? 0 : AppTheme.Tab2Hero.Layout.artTextOverlap)
                .padding(.bottom, usesPresetArt ? 0 : AppTheme.Tab2Hero.Layout.artTextOverlap)
            }
            .background(AppTheme.Color.warmGlassSurface)
            .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
            .overlay(RoundedRectangle(cornerRadius: AppTheme.Radius.large).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
            .cardShadow()
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var topArt: some View {
        if let cover = display.photoCover {
            Tab2HeroPhotoArt(cover: cover)
        } else {
            CategoryPresetArtView(category: sceneCategory)
        }
    }
}

// MARK: - Mock 数据准备
private enum MockData {
    static let photoMorningUrl = "https://images.unsplash.com/photo-1506744038136-46273834b3fb?w=600&auto=format&fit=crop&q=80"
    static let photoCoffeeUrl  = "https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?w=600&auto=format&fit=crop&q=80"
    static let photoWorkUrl    = "https://images.unsplash.com/photo-1497215728101-856f4ea42174?w=600&auto=format&fit=crop&q=80"
    static let photoSocialUrl  = "https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=600&auto=format&fit=crop&q=80"
    static let photoTravelUrl  = "https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=600&auto=format&fit=crop&q=80"
    static let photoHealthUrl  = "https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=600&auto=format&fit=crop&q=80"

    static let heroEmptyPhoto = Tab2CategoryData(
        sceneCategory: "work_study", wordCount: 34, unlocked: true,
        lastMaterialAt: Date(), newMaterialCount: 1, activityCount: 0,
        activities: [Tab2Activity(sceneDetail: "", occurrenceCount: 1, cover: Tab2Activity.Cover(materialId: "m1", imageUrl: photoWorkUrl))]
    )
    static let heroNormalPhoto = Tab2CategoryData(
        sceneCategory: "food_drink", wordCount: 47, unlocked: true,
        lastMaterialAt: Date(), newMaterialCount: 3, activityCount: 2,
        activities: [
            Tab2Activity(sceneDetail: "Making pour-over coffee", occurrenceCount: 5, cover: Tab2Activity.Cover(materialId: "m2", imageUrl: photoCoffeeUrl)),
            Tab2Activity(sceneDetail: "Ordering lunch at cafe", occurrenceCount: 3)
        ]
    )
}

#Preview("Hero Labels & Reason Sandbox") {
    Tab2HeroAndEmptyStateParityPreviewView()
}
#endif
