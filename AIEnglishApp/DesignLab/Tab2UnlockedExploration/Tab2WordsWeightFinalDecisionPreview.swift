#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 解锁页 Words 胶囊字重终审沙箱 (Regular 400 vs Light 300 真实场景终局对比)
//
// 🎯 核心目标：
// 1. 需求 2 已敲定：全面预装方案 2-A (categoryToActivity = 9.5pt)，高度稳定保持在 119pt！
// 2. 需求 1 聚焦终审：字号锁定 12pt，贴身终局对比两种字重：
//    - 方案 A ⭐（12pt Regular 400 · 强烈推荐）：左右笔触 1:1 光学同宽，边缘锐利扎实，全天候全光照高易读性
//    - 方案 B（12pt Light 300 · 极致轻灵）：极细无衬线，如高级手账刻度，空灵通透
// 3. 示例数据极度饱满真实：
//    - Talk about today: 4 个真实日常活动胶囊 + 高品质封面 + Practice CTA
//    - More to talk about: 4 个完整卡片 (Food, Work, Shopping, Travel)，全部应用 9.5pt 舒展间距
//    - Topics in progress: 4 个进行中卡片，其中包含手风琴展开态展示真实单词卡 (empathize, rekindle 等)
//    - More topics to explore: 落地后的 H-25 方案 (25pt 高度白底浅边)
// 4. 提供【左右同屏双视口并排】与【单屏快速切换】两种模式，无需脑补，一眼定案。

struct Tab2WordsWeightFinalDecisionPreviewView: View {
    @State private var viewMode: ViewMode
    @State private var singleSelectedWeight: TargetWeight
    @State private var expandedCategoryId: String? = "social"

    init(initialMode: ViewMode = .sideBySide, initialWeight: TargetWeight = .regular400) {
        _viewMode = State(initialValue: initialMode)
        _singleSelectedWeight = State(initialValue: initialWeight)
    }

    enum ViewMode: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case sideBySide = "左右双屏平铺对比"
        case singleScreen = "单屏沉浸切换"
    }

    enum TargetWeight: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case regular400 = "方案 A · 12pt Regular (400) ⭐"
        case light300 = "方案 B · 12pt Light (300)"

        var weight: Font.Weight {
            switch self {
            case .regular400: return .regular
            case .light300: return .light
            }
        }

        var badgeText: String {
            switch self {
            case .regular400: return "Regular 400 (同频扎实)"
            case .light300: return "Light 300 (极细空灵)"
            }
        }

        var rationale: String {
            switch self {
            case .regular400: return "左右两端笔触 1:1 光学同宽，晨光与户外均清晰稳定，经典耐看"
            case .light300: return "极细发丝级笔画，刻度感极强，次级事实感完全退让"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topControlBar

            Divider().opacity(0.12)

            switch viewMode {
            case .sideBySide:
                sideBySideView
            case .singleScreen:
                singleScreenView
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    // MARK: - 顶端控制条

    private var topControlBar: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(AppTheme.Color.brandStrong).frame(width: 8, height: 8)
                    Text("Tab2 Words 胶囊字重终审 (12pt Regular vs Light)")
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }

                Spacer()

                Text("已预装间距 9.5pt (2-A)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.green.opacity(0.85))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12), in: Capsule())
            }

            HStack {
                Picker("展示模式", selection: $viewMode) {
                    ForEach(ViewMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)

                if viewMode == .singleScreen {
                    Picker("字重选择", selection: $singleSelectedWeight) {
                        ForEach(TargetWeight.allCases) { w in
                            Text(w.rawValue).tag(w)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.Color.cardBg)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
                }
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, 8)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 视图模式 1: 左右双屏平铺对比 (支持横向滚动，同屏对照)

    private var sideBySideView: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 20) {
                // 左视口：方案 A (Regular 400)
                VStack(alignment: .leading, spacing: 8) {
                    screenHeaderTag(
                        title: "方案 A · 12pt Regular (400) ⭐ 推荐",
                        subtitle: "笔触与 13pt Regular 1:1 光学同频 · 坚挺耐看",
                        isRecommend: true
                    )

                    fullPageContentView(targetWeight: .regular400)
                        .frame(width: 360, height: 780)
                        .background(AppTheme.Color.pageBg)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(AppTheme.Color.brandStrong.opacity(0.4), lineWidth: 1.5))
                        .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
                }

                // 右视口：方案 B (Light 300)
                VStack(alignment: .leading, spacing: 8) {
                    screenHeaderTag(
                        title: "方案 B · 12pt Light (300) 极细",
                        subtitle: "极细发丝级刻度 · 彻底消融胶囊存在感",
                        isRecommend: false
                    )

                    fullPageContentView(targetWeight: .light300)
                        .frame(width: 360, height: 780)
                        .background(AppTheme.Color.pageBg)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.06), radius: 10, y: 4)
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.vertical, 12)
        }
    }

    private func screenHeaderTag(title: String, subtitle: String, isRecommend: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isRecommend ? AppTheme.Color.brandStrong : AppTheme.Color.textPrimary)
                }
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 视图模式 2: 单屏沉浸切换视图

    private var singleScreenView: some View {
        fullPageContentView(targetWeight: singleSelectedWeight)
    }

    // MARK: - 极度高保真全量页面视口 (前三部分完全落地 + 间距 9.5pt + 充实案例)

    private func fullPageContentView(targetWeight: TargetWeight) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingBetweenSections) { // 28pt 标准区块间距
                Color.clear.frame(height: 8)

                // ── 1. Talk about today (Hero 区块) ──
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    Text("Talk about today")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Tab2HeroCard(
                        category: FinalDecisionMockStore.richHeroData,
                        onTalk: {}
                    )
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                // ── 2. More to talk about (4 个完整卡片 · 已预装 9.5pt 间距) ──
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("More to talk about")
                            .font(AppTheme.Font.sectionTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Spacer()

                        Text("间距 9.5pt (2-A 已锁定)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.Color.brandStrong)
                    }

                    VStack(spacing: AppTheme.Tab2MoreRow.Layout.rowGap) {
                        ForEach(FinalDecisionMockStore.richMoreCategories) { item in
                            CustomSpacingActivityCard(
                                category: item,
                                spacing: 9.5
                            )
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                // ── 3. Topics in progress (4 个进行中分类 · 字重比对重点区) ──
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Topics in progress")
                            .font(AppTheme.Font.sectionTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Spacer()

                        Text(targetWeight.badgeText)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.Color.brandStrong)
                    }

                    VStack(spacing: 0) {
                        // 1. Social & Feelings (展开态：展示真实单词卡)
                        AccordionProgressRow(
                            title: "Social & Feelings",
                            icon: "bubble.left.and.bubble.right",
                            count: 16,
                            isExpanded: expandedCategoryId == "social",
                            targetWeight: targetWeight,
                            onToggle: {
                                withAnimation(AppTheme.Motion.accordionToggle) {
                                    expandedCategoryId = (expandedCategoryId == "social" ? nil : "social")
                                }
                            }
                        )

                        // 2. Health & Fitness (收起态)
                        AccordionProgressRow(
                            title: "Health & Fitness",
                            icon: "figure.run",
                            count: 12,
                            isExpanded: false,
                            targetWeight: targetWeight,
                            onToggle: {}
                        )

                        // 3. Digital & Tech (收起态)
                        AccordionProgressRow(
                            title: "Digital & Tech",
                            icon: "laptopcomputer",
                            count: 7,
                            isExpanded: false,
                            targetWeight: targetWeight,
                            onToggle: {}
                        )

                        // 4. Hobbies & Leisure (收起态)
                        AccordionProgressRow(
                            title: "Hobbies & Leisure",
                            icon: "paintpalette",
                            count: 3,
                            isExpanded: false,
                            targetWeight: targetWeight,
                            onToggle: {}
                        )
                    }
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .surfaceCard(cornerRadius: AppTheme.Radius.large)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                // ── 4. More topics to explore (落地后的 H-25 方案 · 25pt) ──
                VStack(alignment: .leading, spacing: 0) {
                    Text("More topics to explore")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.bottom, AppTheme.Tab2ExploreTopics.Layout.titleToTags)

                    Tab2MoreTopicsSection(
                        topics: FinalDecisionMockStore.richUnstartedTopics
                    )

                    Text("Record moments from your day to start these topics.")
                        .font(AppTheme.Font.metaNote)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.top, AppTheme.Tab2ExploreTopics.Layout.tagsToFootnote)
                }

                // 底部落款
                VStack(spacing: 6) {
                    PoplexWordmark(
                        capHeight: 12.5,
                        style: .mono(AppTheme.Color.textMuted),
                        showsPeriod: true
                    )
                    Text("English from your everyday life.")
                        .font(AppTheme.Font.libraryFooterTagline)
                        .tracking(0.5)
                        .foregroundStyle(AppTheme.Color.textMuted.opacity(0.85))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, AppTheme.Space.tab2FooterBottom)
            }
            .background(alignment: .bottom) {
                BottomAuraFooter()
            }
        }
    }
}

// MARK: - 可变字重的 AccordionProgressRow (支持手风琴展开查看单词条目)

private struct AccordionProgressRow: View {
    let title: String
    let icon: String
    let count: Int
    let isExpanded: Bool
    let targetWeight: Tab2WordsWeightFinalDecisionPreviewView.TargetWeight
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)

                    Text(title)
                        .font(AppTheme.Font.tab2TopicLabel) // 13pt Regular 400
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    // 🌟 终审 Words 胶囊本体 (12pt Regular vs 12pt Light)
                    HStack(spacing: AppTheme.Size.pillHSpacing) {
                        Text(Tab2CardLabels.words(count))
                            .font(.system(size: 12, weight: targetWeight.weight))
                            .monospacedDigit()
                            .foregroundStyle(AppTheme.Color.textSecondary)

                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: AppTheme.Size.expandArrow))
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .padding(.horizontal, AppTheme.Size.pillHPad)
                    .padding(.vertical, AppTheme.Size.pillVPad)
                    .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
                    .overlay(Capsule().strokeBorder(AppTheme.Color.tab2ProgressPillBorder, lineWidth: 0.5))
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.vertical, AppTheme.Space.paddingS)
            }
            .buttonStyle(.plain)

            // 手风琴展开时的详细单词条目
            if isExpanded {
                VStack(spacing: 12) {
                    Divider().opacity(0.08)

                    sampleWordRow(lemma: "empathize with", pos: "phrase · v.", meaning: "产生共鸣；感同身受", sentence: "I can totally empathize with your busy schedule.")
                    sampleWordRow(lemma: "rekindle friendship", pos: "phrase · v.", meaning: "重温旧谊", sentence: "It was so nice rekindling our college connection.")
                    sampleWordRow(lemma: "heartwarming", pos: "word · adj.", meaning: "暖心的", sentence: "We had a truly heartwarming conversation.")
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func sampleWordRow(lemma: String, pos: String, meaning: String, sentence: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(AppTheme.Color.tab2ActivityChipBg)
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "text.quote").font(.system(size: 12)).foregroundStyle(AppTheme.Color.textMuted))

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(lemma)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text(pos)
                        .font(.system(size: 10))
                        .foregroundStyle(AppTheme.Color.textMuted)
                }

                Text(meaning)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Text(sentence)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 真实预装 9.5pt 间距的 CustomSpacingActivityCard

private struct CustomSpacingActivityCard: View {
    let category: Tab2CategoryData
    let spacing: CGFloat

    private var display: Tab2ActivityDisplay {
        Tab2ActivityDisplay.compute(category: category)
    }

    var body: some View {
        HStack(spacing: 0) {
            Color.clear
                .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth)
                .overlay {
                    if let cover = category.activities.first?.cover, let url = cover.imageUrl {
                        CachedRemoteImage(
                            signedUrl: url,
                            stableKey: url,
                            placeholder: { Rectangle().fill(AppTheme.Color.imagePlaceholderBg) }
                        )
                        .clipped()
                        .saturation(AppTheme.Tab2MoreRow.ImageTreatment.photoSaturation)
                        .overlay(
                            Rectangle()
                                .fill(AppTheme.Color.tab2MoreRowPhotoToneWarm)
                                .blendMode(.multiply)
                                .opacity(AppTheme.Tab2MoreRow.Opacity.photoToneWarm)
                        )
                    } else {
                        Rectangle().fill(AppTheme.Color.imagePlaceholderBg)
                    }
                }
                .clipped()

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(category.englishLabel)
                        .font(AppTheme.Font.tab2MoreRowCategory)
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Spacer()

                    Text("Yesterday")
                        .font(AppTheme.Font.tab2MoreRowTimeline)
                        .foregroundStyle(AppTheme.Color.neutralFaint)
                }
                .padding(.trailing, AppTheme.Tab2MoreRow.Layout.hatRowTrailingInset)

                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        activityBlock
                            .padding(.top, spacing) // 🌟 9.5pt 黄金间距

                        Text(Tab2CardLabels.words(category.wordCount))
                            .font(AppTheme.Font.tab2MoreRowMeta)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .monospacedDigit()
                            .padding(.top, AppTheme.Tab2MoreRow.Layout.activityToWords)
                    }
                    .padding(.trailing, AppTheme.Tab2MoreRow.Layout.contentTrailingInset)

                    Image(systemName: "arrow.right")
                        .font(.system(size: AppTheme.Tab2MoreRow.Layout.arrowGlyph, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .padding(.trailing, AppTheme.Tab2MoreRow.Layout.arrowTrailingInset)
                }
            }
            .padding(.top, AppTheme.Tab2MoreRow.Layout.contentTopInset)
            .padding(.bottom, AppTheme.Tab2MoreRow.Layout.contentBottomInset)
            .padding(.leading, AppTheme.Tab2MoreRow.Layout.contentLeadingInset)
        }
        .frame(minHeight: AppTheme.Tab2MoreRow.Layout.rowHeight) // 119pt
        .background(AppTheme.Color.warmGlassSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
        )
        .cardShadow()
    }

    private var activityBlock: some View {
        Tab2ActivityCapsuleGroup(
            activities: display.valid,
            activityCount: category.activityCount,
            blockedCount: display.blockedCount,
            metrics: Tab2ActivityCapsuleMetrics.more(),
            nameFont: AppTheme.Font.tab2MoreRowCapsuleName,
            moreFont: AppTheme.Font.tab2MoreRowCapsuleMore
        )
    }
}

// MARK: - 丰富高保真 Mock 数据中心

private enum FinalDecisionMockStore {

    // 1. Hero
    static var richHeroData: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: "Daily Routine",
            wordCount: 47,
            unlocked: true,
            notSpokenCount: 47,
            lastTalkedAt: nil,
            lastMaterialAt: Date(),
            newMaterialCount: 3,
            activityCount: 7,
            activities: [
                Tab2Activity(
                    sceneDetail: "Morning espresso at boutique cafe",
                    occurrenceCount: 3,
                    cover: Tab2Activity.Cover(
                        materialId: "m-hero-fd-1",
                        imageUrl: "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=800&auto=format&fit=crop&q=80"
                    )
                ),
                Tab2Activity(sceneDetail: "Subway commute listening to podcast", occurrenceCount: 2),
                Tab2Activity(sceneDetail: "Stretching in the living room", occurrenceCount: 2),
                Tab2Activity(sceneDetail: "Picked up fresh sourdough bread", occurrenceCount: 1)
            ]
        )
    }

    // 2. More to talk about (4 个丰富卡片)
    static var richMoreCategories: [Tab2CategoryData] {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let lastWeek = Calendar.current.date(byAdding: .day, value: -7, to: Date())!

        return [
            Tab2CategoryData(
                sceneCategory: "Food & Drink",
                wordCount: 38,
                unlocked: true,
                notSpokenCount: 38,
                lastTalkedAt: nil,
                lastMaterialAt: yesterday,
                newMaterialCount: 2,
                activityCount: 8,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Dinner with old college friends",
                        occurrenceCount: 3,
                        cover: Tab2Activity.Cover(
                            materialId: "m-food-fd-1",
                            imageUrl: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Baking homemade banana bread", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Ordered iced latte at corner shop", occurrenceCount: 1)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "Work & Study",
                wordCount: 28,
                unlocked: true,
                notSpokenCount: 28,
                lastTalkedAt: nil,
                lastMaterialAt: twoDaysAgo,
                newMaterialCount: 1,
                activityCount: 6,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Presented sprint roadmap to team",
                        occurrenceCount: 2,
                        cover: Tab2Activity.Cover(
                            materialId: "m-work-fd-1",
                            imageUrl: "https://images.unsplash.com/photo-1497366216548-37526070297c?w=400&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Reviewed design PR with tech lead", occurrenceCount: 2),
                    Tab2Activity(sceneDetail: "Sprint retrospective sync", occurrenceCount: 1)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "Shopping",
                wordCount: 18,
                unlocked: true,
                notSpokenCount: 18,
                lastTalkedAt: nil,
                lastMaterialAt: threeDaysAgo,
                newMaterialCount: 0,
                activityCount: 5,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Bought organic vegetables at farmers market",
                        occurrenceCount: 2,
                        cover: Tab2Activity.Cover(
                            materialId: "m-shop-fd-1",
                            imageUrl: "https://images.unsplash.com/photo-1488459716781-31db52582fe9?w=400&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Picked up parcel from smart locker", occurrenceCount: 1)
                ]
            ),
            Tab2CategoryData(
                sceneCategory: "Travel & Commute",
                wordCount: 22,
                unlocked: true,
                notSpokenCount: 22,
                lastTalkedAt: nil,
                lastMaterialAt: lastWeek,
                newMaterialCount: 0,
                activityCount: 4,
                activities: [
                    Tab2Activity(
                        sceneDetail: "Took express subway into downtown",
                        occurrenceCount: 3,
                        cover: Tab2Activity.Cover(
                            materialId: "m-travel-fd-1",
                            imageUrl: "https://images.unsplash.com/photo-1519501025264-65ba15a82390?w=400&auto=format&fit=crop&q=80"
                        )
                    ),
                    Tab2Activity(sceneDetail: "Walked through riverside park in sunset", occurrenceCount: 1)
                ]
            )
        ]
    }

    // 3. More topics to explore (9 个未开启分类)
    static var richUnstartedTopics: [SceneCategory] {
        [
            .homeFamily,
            .weather,
            .other,
            .homeFamily,
            .weather,
            .other,
            .homeFamily,
            .weather,
            .other
        ]
    }
}

// MARK: - Xcode Canvas 预览入口
 
#Preview("终审对比 · 方案 A (12pt Regular ⭐)") {
    Tab2WordsWeightFinalDecisionPreviewView(initialMode: .singleScreen, initialWeight: .regular400)
}

#Preview("终审对比 · 方案 B (12pt Light 极细)") {
    Tab2WordsWeightFinalDecisionPreviewView(initialMode: .singleScreen, initialWeight: .light300)
}

#Preview("终审对比 · 左右双屏平铺同屏对比") {
    Tab2WordsWeightFinalDecisionPreviewView(initialMode: .sideBySide)
}

#endif
