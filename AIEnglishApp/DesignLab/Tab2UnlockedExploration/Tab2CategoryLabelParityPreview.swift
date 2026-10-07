#if DEBUG
import SwiftUI

// MARK: - Tab2 解锁态 · 四类生活分类标签像素级现状对比沙盒
//
// 业务背景：
// 解锁后页面中，SceneCategory（生活分类，如 Food & Drink, Work & Study 等）
// 在 4 个不同区块有着 4 种截然不同的视觉形态：
// 1. 【Hero 封面卡片】: 11.5pt/600 纯白无底浮层（带微投影），紧随理由胶囊
// 2. 【More 推荐行】: 12pt/600 textSecondary 纯字帽行，居缩略图右侧顶端
// 3. 【Topics 进行中行】: 13.5pt/500 textPrimary + 15pt SF Symbol 描边图标 + 进度条
// 4. 【Explore 探索区】: 12pt/400 textSecondary + 13pt SF Symbol + 30pt 高白底微边实体胶囊

struct Tab2CategoryLabelParityPreviewView: View {
    @State private var selectedTab: ViewMode = .allInOne
    @State private var sampleCategory: SceneCategory = .food
    @State private var isAccordionExpanded: Bool = false

    enum ViewMode: String, CaseIterable, Identifiable {
        case allInOne = "全景上下文"
        case isolated = "纯标签贴身对比"
        case analysis = "四维设计审计"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 顶部控制条
                    topControlBar

                    switch selectedTab {
                    case .allInOne:
                        allInOneContextSection
                    case .isolated:
                        isolatedComparisonSection
                    case .analysis:
                        designAnalysisSection
                    }
                }
                .padding(.vertical, AppTheme.Space.paddingPage)
            }
            .background(AppTheme.Color.pageBg.ignoresSafeArea())
            .navigationTitle("Tab2 分类标签现状 (4类)")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 顶部控制器

    private var topControlBar: some View {
        VStack(spacing: 12) {
            Picker("查看模式", selection: $selectedTab) {
                ForEach(ViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // 分类测试切换器
            HStack {
                Text("当前测试分类:")
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textMuted)

                Menu {
                    ForEach(SceneCategory.allCases, id: \.self) { cat in
                        Button(cat.englishLabel) {
                            sampleCategory = cat
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: sampleCategory.iconName)
                        Text(sampleCategory.englishLabel)
                            .fontWeight(.medium)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                    }
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.Color.brandStrong.opacity(0.08), in: Capsule())
                }

                Spacer()
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    // MARK: - 模式 1: 生产全景上下文 (In-Context)

    private var allInOneContextSection: some View {
        VStack(alignment: .leading, spacing: 28) {
            // ① Hero 卡顶行
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(
                    badge: "第 1 类",
                    title: "Hero 封面顶层分类标签",
                    subtitle: "位置: Tab2HeroCard 照片/艺术图左上方浮层"
                )

                heroCardContext
            }

            // ② More 推荐行帽子
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(
                    badge: "第 2 类",
                    title: "More 推荐行分类帽行",
                    subtitle: "位置: Tab2ActivityRow 缩略图右侧首行"
                )

                moreRowContext
            }

            // ③ Topics 进度行
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(
                    badge: "第 3 类",
                    title: "Topics in Progress 进度行标题",
                    subtitle: "位置: CategoryProgressRow 大磨砂卡片内"
                )

                topicsRowContext
            }

            // ④ Explore 探索胶囊
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(
                    badge: "第 4 类",
                    title: "More Topics to Explore 探索标签",
                    subtitle: "位置: Tab2MoreTopicsSection 页面底部探索流"
                )

                exploreTagsContext
            }
        }
    }

    // MARK: - 模式 2: 纯标签贴身对比 (Isolated)

    private var isolatedComparisonSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("四类标签物理参数横向解构")
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingPage)

            VStack(spacing: 16) {
                // 卡片 1
                isolatedCard(
                    tier: "第 1 类 · Hero 封面顶行",
                    fontSpec: "11.5pt / SemiBold (600) / Gothic A1",
                    colorSpec: "纯白 #FFFFFF + 投影 (浅底为 #6F665C)",
                    containerSpec: "无背景 / 无边框 / 纯文字悬浮",
                    iconSpec: "无图标 (仅文字)"
                ) {
                    ZStack {
                        // 模拟暗色封面背景
                        LinearGradient(
                            colors: [Color.black.opacity(0.7), Color.black.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        HStack(spacing: 8) {
                            Text(sampleCategory.englishLabel)
                                .font(AppTheme.Font.tab2HeroChipCategory)
                                .foregroundStyle(Color.white)
                                .shadow(
                                    color: Color.black.opacity(0.5),
                                    radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                                    x: 0,
                                    y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
                                )

                            Text("Added 3 times today")
                                .font(AppTheme.Font.tab2ReasonPill)
                                .foregroundStyle(Color.white.opacity(0.82))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.2), in: Capsule())

                            Spacer()
                        }
                        .padding(.horizontal, 14)
                    }
                }

                // 卡片 2
                isolatedCard(
                    tier: "第 2 类 · More 推荐行帽子",
                    fontSpec: "12pt / SemiBold (600) / Gothic A1",
                    colorSpec: "textSecondary (#72655A 暖灰褐色)",
                    containerSpec: "无背景 / 无边框 / 列表帽行左对齐",
                    iconSpec: "无图标 (图标独立在左侧 68pt 缩略图中)"
                ) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(sampleCategory.englishLabel)
                            .font(AppTheme.Font.tab2MoreRowCategory)
                            .foregroundStyle(AppTheme.Color.textSecondary)

                        Spacer()

                        Text("2h ago")
                            .font(AppTheme.Font.tab2MoreRowTimeline)
                            .foregroundStyle(AppTheme.Color.neutralFaint)
                    }
                    .padding(14)
                    .background(AppTheme.Color.warmGlassSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
                }

                // 卡片 3
                isolatedCard(
                    tier: "第 3 类 · Topics 进行中行",
                    fontSpec: "13.5pt / Medium (500) / Gothic A1",
                    colorSpec: "textPrimary (#2C2621 核心主文字色)",
                    containerSpec: "列表行首行 + 下方 1.5pt 微轨进度条",
                    iconSpec: "有图标 · 15pt SF Symbol 描边 (20×20 纯线条)"
                ) {
                    HStack(spacing: AppTheme.Size.categoryRowContentSpacing) {
                        Image(systemName: sampleCategory.iconName)
                            .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .medium))
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(sampleCategory.englishLabel)
                                    .font(AppTheme.Font.tab2TopicLabel)
                                    .foregroundStyle(AppTheme.Color.textPrimary)

                                Spacer()

                                Text("14 words ▾")
                                    .font(AppTheme.Font.tab2ProgressCount)
                                    .foregroundStyle(AppTheme.Color.textSecondary)
                                    .padding(.horizontal, AppTheme.Size.pillHPad)
                                    .padding(.vertical, AppTheme.Size.pillVPad)
                                    .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
                            }

                            // 进度条
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(AppTheme.Color.progressTrack).frame(height: 1.5)
                                    Capsule().fill(AppTheme.Color.progressFill).frame(width: g.size.width * 0.7, height: 1.5)
                                }
                            }
                            .frame(height: 1.5)
                        }
                    }
                    .padding(14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
                }

                // 卡片 4
                isolatedCard(
                    tier: "第 4 类 · Explore 未开启探索区",
                    fontSpec: "12pt / Regular (400) / Gothic A1",
                    colorSpec: "tagLabel (#72655A textSecondary)",
                    containerSpec: "独立实体胶囊 · 高 30pt / 白底 #FFFFFF / 0.5pt 边框 / 微阴影",
                    iconSpec: "有图标 · 13pt SF Symbol (集成在胶囊内)"
                ) {
                    HStack {
                        Tab2ExploreTopicTag(topic: sampleCategory)
                        Spacer()
                    }
                    .padding(14)
                    .background(AppTheme.Color.pageBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
                }
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    // MARK: - 模式 3: 四维设计审计 (Analysis)

    private var designAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("分类标签现状核心痛点与断层分析")
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingPage)

            VStack(spacing: 14) {
                analysisPointCard(
                    number: "1",
                    title: "容器实体感断层：纯文字 vs 实体白胶囊",
                    desc: "第 1、2 类（Hero / More）为纯文字帽子，第 3 类（Topics）为卡片行内纯文字标题；唯独第 4 类（Explore）做成了【高度 30pt、纯白底色、带阴影的实体胶囊】。这导致用户从前 3 个模块浏览到底部时，分类从‘概念属性’突变成了‘可点击的按钮/药丸’（尽管它不可点）。"
                )

                analysisPointCard(
                    number: "2",
                    title: "图标体系不一致：有图标 vs 无图标",
                    desc: "Topics 和 Explore 拥有 SF Symbol 分类图标（如餐叉、公文包、哑铃）；而占据视觉重心的 Hero 和 More 行却没有图标。这导致同一套分类在页面上下呈现出两套不同的视觉语言。"
                )

                analysisPointCard(
                    number: "3",
                    title: "字号与字重各自为政（4 种完全不同配方）",
                    desc: "Hero 为 11.5pt/600；More 为 12pt/600；Topics 为 13.5pt/500；Explore 为 12pt/400。字号跨越 11.5~13.5pt，字重跨越 Regular / Medium / SemiBold，缺乏统一的层级梯度契约。"
                )

                analysisPointCard(
                    number: "4",
                    title: "与刚刚优化的【活动胶囊】角色混淆",
                    desc: "我们刚刚将活动胶囊（Activity Chip: Morning routine 等）优化为轻雾柔霜无边框方案。如果生活分类（Category）也以胶囊形式出现，页面上就会同时出现‘分类胶囊’和‘活动胶囊’，用户很难一眼分辨哪个是宏观分类、哪个是具体活动。"
                )
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    // MARK: - 上下文组件生成器

    private var heroCardContext: some View {
        Tab2HeroCard(
            category: ParityMockStore.heroCategory(for: sampleCategory),
            onTalk: {}
        )
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private var moreRowContext: some View {
        Tab2ActivityRow(
            category: ParityMockStore.moreCategory(for: sampleCategory),
            onTap: {}
        )
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private var topicsRowContext: some View {
        VStack(spacing: 0) {
            CategoryProgressRow(
                category: ParityMockStore.inProgressCategory(for: sampleCategory),
                isExpanded: isAccordionExpanded,
                onToggle: { withAnimation { isAccordionExpanded.toggle() } },
                loadWords: { ParityMockStore.words(for: sampleCategory) },
                wordsRevision: 0
            )
        }
        .padding(.vertical, AppTheme.Space.paddingS)
        .surfaceCard(cornerRadius: AppTheme.Radius.large)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private var exploreTagsContext: some View {
        VStack(alignment: .leading, spacing: 10) {
            let tags: [SceneCategory] = [sampleCategory, .workStudy, .healthFitness, .shopping]
            HStack(spacing: AppTheme.Tab2ExploreTopics.Layout.tagGap) {
                ForEach(tags.prefix(3), id: \.self) { cat in
                    Tab2ExploreTopicTag(topic: cat)
                }
            }
            HStack(spacing: AppTheme.Tab2ExploreTopics.Layout.tagGap) {
                if tags.count > 3 {
                    Tab2ExploreTopicTag(topic: tags[3])
                }
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    // MARK: - 辅助微组件

    private func sectionHeader(badge: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.Color.brandStrong, in: Capsule())

                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
            }

            Text(subtitle)
                .font(AppTheme.Font.metaNote)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    private func isolatedCard<Content: View>(
        tier: String,
        fontSpec: String,
        colorSpec: String,
        containerSpec: String,
        iconSpec: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tier)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.Color.brandStrong)
                Spacer()
            }

            content()

            VStack(alignment: .leading, spacing: 4) {
                specRow(title: "字体规范", value: fontSpec)
                specRow(title: "色彩规范", value: colorSpec)
                specRow(title: "容器材质", value: containerSpec)
                specRow(title: "图标要素", value: iconSpec)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
    }

    private func specRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title + ":")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Color.textMuted)
                .frame(width: 56, alignment: .leading)

            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Color.textSecondary)

            Spacer()
        }
    }

    private func analysisPointCard(number: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppTheme.Color.brandStrong)
                .frame(width: 24, height: 24)
                .background(AppTheme.Color.brandStrong.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Text(desc)
                    .font(AppTheme.Font.metaNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
    }
}

// MARK: - 真实生产环境 Mock 数据源

private enum ParityMockStore {
    static func heroCategory(for cat: SceneCategory) -> Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: cat.rawValue,
            wordCount: 42,
            unlocked: true,
            notSpokenCount: 0,
            lastTalkedAt: nil,
            lastMaterialAt: Date().addingTimeInterval(-1800),
            newMaterialCount: 3,
            activityCount: 4,
            activities: [
                Tab2Activity(
                    sceneDetail: "Morning coffee",
                    occurrenceCount: 2,
                    cover: Tab2Activity.Cover(materialId: "m1", imageUrl: "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=800&auto=format&fit=crop&q=80")
                ),
                Tab2Activity(sceneDetail: "Water plants", occurrenceCount: 1, cover: nil),
                Tab2Activity(sceneDetail: "Quick journal", occurrenceCount: 1, cover: nil)
            ]
        )
    }

    static func moreCategory(for cat: SceneCategory) -> Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: cat.rawValue,
            wordCount: 28,
            unlocked: true,
            notSpokenCount: 0,
            lastTalkedAt: nil,
            lastMaterialAt: Date().addingTimeInterval(-7200),
            newMaterialCount: 1,
            activityCount: 2,
            activities: [
                Tab2Activity(
                    sceneDetail: "Cook dinner",
                    occurrenceCount: 2,
                    cover: Tab2Activity.Cover(materialId: "m2", imageUrl: "https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=600&auto=format&fit=crop&q=80")
                ),
                Tab2Activity(sceneDetail: "Grocery run", occurrenceCount: 1, cover: nil)
            ]
        )
    }

    static func inProgressCategory(for cat: SceneCategory) -> Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: cat.rawValue,
            wordCount: 14,
            unlocked: false,
            notSpokenCount: 14,
            lastTalkedAt: nil,
            lastMaterialAt: Date().addingTimeInterval(-86400),
            newMaterialCount: 0,
            activityCount: 1,
            activities: [
                Tab2Activity(sceneDetail: "Team sync", occurrenceCount: 1, cover: nil)
            ]
        )
    }

    static func words(for cat: SceneCategory) -> [Tab2WordEntry] {
        [
            Tab2WordEntry(lemma: "flavor", displayForm: "flavor profile", entryKind: "phrase", nativeMeaning: "风味特征"),
            Tab2WordEntry(lemma: "roast", displayForm: "medium roast", entryKind: "phrase", nativeMeaning: "中度烘焙"),
            Tab2WordEntry(lemma: "aroma", displayForm: "rich aroma", entryKind: "phrase", nativeMeaning: "浓郁香气")
        ]
    }
}

// MARK: - Canvas Preview

#Preview("Tab2 · 四类分类标签像素级解构") {
    Tab2CategoryLabelParityPreviewView()
}
#endif
