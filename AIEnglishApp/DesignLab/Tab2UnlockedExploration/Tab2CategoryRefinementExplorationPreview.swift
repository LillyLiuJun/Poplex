#if DEBUG
import SwiftUI

// MARK: - Tab2 生活分类标签深度优化沙盒
//
// 针对用户指出的核心痛点：
// 1. 第 4 类 (More topics to explore) 实体白胶囊过重、假点击感、与活动胶囊混淆；
// 2. 第 3 类 (Topics in progress) 分类标题感觉偏重 (13.5pt/500 textPrimary 墨色过浓)。
//
// 本沙盒提供第 3 类与第 4 类的多套专属优化方案，并支持同屏联动对比。

struct Tab2CategoryRefinementExplorationPreviewView: View {
    // 第 3 类方案选择器
    @State private var topicTitleScheme: TopicTitleScheme = .fineRegular
    // 第 4 类方案选择器
    @State private var exploreTagScheme: ExploreTagScheme = .softMist

    // 当前测试的生活分类
    @State private var sampleCategory: SceneCategory = .food
    // 手风琴展开测试
    @State private var isExpanded: Bool = false

    // MARK: - 枚举定义

    enum TopicTitleScheme: String, CaseIterable, Identifiable {
        case baseline = "基线 (13.5pt 500 深黑)"
        case softInk = "方案 3-A (降墨度 500 次级灰)"
        case fineRegular = "方案 3-B (细线 13pt 400 纤挺 ⭐)"
        case compactMuted = "方案 3-C (紧凑 12.5pt 500 平齐)"

        var id: String { rawValue }
    }

    enum ExploreTagScheme: String, CaseIterable, Identifiable {
        case baseline = "基线 (30pt 白底厚胶囊)"
        case softMist = "方案 4-A (轻雾柔霜无框 24pt ⭐)"
        case ghostOutline = "方案 4-B (待点亮素线框 24pt)"
        case pureTextFlow = "方案 4-C (去胶囊纯图文流)"
        case microBadge = "方案 4-D (微型精致徽章 22pt)"

        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // 控制看板
                    controlDashboard

                    // 模块 1: 第 3 类 (Topics in progress) 四套方案贴身对比
                    topicsCategorySection

                    // 模块 2: 第 4 类 (More topics to explore) 五套方案贴身对比
                    exploreTagsSection

                    // 模块 3: 联合视口模拟 (从 Topics 浏览到底部 Explore 的整体呼吸感)
                    jointViewportSection
                }
                .padding(.vertical, AppTheme.Space.paddingPage)
            }
            .background(AppTheme.Color.pageBg.ignoresSafeArea())
            .navigationTitle("分类标签减重优化")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 控制看板

    private var controlDashboard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("测试分类:")
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

                Text("已选: 3-B 细线 + 4-A 轻雾")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.Color.brandStrong)
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    // MARK: - 模块 1: 第 3 类 Topics 标题减重

    private var topicsCategorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                badge: "第 3 类 优化",
                title: "Topics in progress 分类行标题减重",
                subtitle: "解决痛点：消除 13.5pt/500 textPrimary 在白卡上的浓黑压迫感"
            )

            VStack(spacing: 12) {
                // 1. 基线
                topicVariantCard(
                    scheme: .baseline,
                    badge: "基线 · 生产原版",
                    specDesc: "13.5pt / Medium (500) / textPrimary (#2C2621 深黑) / 15pt 图标",
                    isRecommended: false
                )

                // 2. 方案 3-A
                topicVariantCard(
                    scheme: .softInk,
                    badge: "方案 3-A · 降墨度温润风",
                    specDesc: "13.5pt / Medium (500) / textSecondary (#72655A 暖褐色) / 15pt 图标",
                    isRecommended: false
                )

                // 3. 方案 3-B ⭐
                topicVariantCard(
                    scheme: .fineRegular,
                    badge: "方案 3-B ⭐ · 细线轻挺风 (推荐)",
                    specDesc: "13pt / Regular (400) 细线 / textPrimary / 14pt 纯净线性图标",
                    isRecommended: true
                )

                // 4. 方案 3-C
                topicVariantCard(
                    scheme: .compactMuted,
                    badge: "方案 3-C · 紧凑平齐风",
                    specDesc: "12.5pt / Medium (500) / textSecondary / 14pt 图标 (与右端胶囊尺寸更平齐)",
                    isRecommended: false
                )
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    private func topicVariantCard(
        scheme: TopicTitleScheme,
        badge: String,
        specDesc: String,
        isRecommended: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(badge)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isRecommended ? AppTheme.Color.brandStrong : AppTheme.Color.textSecondary)

                Spacer()

                if isRecommended {
                    Text("推荐：视觉最透气")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.brandStrong)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.Color.brandStrong.opacity(0.1), in: Capsule())
                }
            }

            // 真实进度卡片行还原
            HStack(alignment: .center, spacing: AppTheme.Size.categoryRowContentSpacing) {
                // 图标
                Image(systemName: sampleCategory.iconName)
                    .font(.system(
                        size: (scheme == .fineRegular || scheme == .compactMuted) ? 14 : 15,
                        weight: scheme == .fineRegular ? .regular : .medium
                    ))
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)

                VStack(alignment: .leading, spacing: AppTheme.Size.rowLabelToProgress) {
                    HStack(alignment: .center) {
                        // 动态切换标题样式
                        Text(sampleCategory.englishLabel)
                            .font(topicFont(for: scheme))
                            .foregroundStyle(topicColor(for: scheme))

                        Spacer()

                        // 右端 WordsPill
                        HStack(spacing: AppTheme.Size.pillHSpacing) {
                            Text("14 words")
                                .font(AppTheme.Font.tab2ProgressCount)
                                .foregroundStyle(AppTheme.Color.textSecondary)
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: AppTheme.Size.expandArrow))
                                .foregroundStyle(AppTheme.Color.textMuted)
                        }
                        .padding(.horizontal, AppTheme.Size.pillHPad)
                        .padding(.vertical, AppTheme.Size.pillVPad)
                        .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
                    }

                    // 1.5pt 微线轨道
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppTheme.Color.progressTrack).frame(height: 1.5)
                        Capsule().fill(AppTheme.Color.progressFill).frame(width: 140, height: 1.5)
                    }
                    .frame(height: 1.5)
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isRecommended ? AppTheme.Color.brandStrong.opacity(0.4) : AppTheme.Color.cardBorder, lineWidth: isRecommended ? 1 : 0.5)
            )

            Text(specDesc)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.leading, 4)
        }
        .padding(14)
        .background(AppTheme.Color.warmGlassSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func topicFont(for scheme: TopicTitleScheme) -> Font {
        switch scheme {
        case .baseline:
            return .system(size: 13.5, weight: .medium)
        case .softInk:
            return .system(size: 13.5, weight: .medium)
        case .fineRegular:
            return .system(size: 13.0, weight: .regular)
        case .compactMuted:
            return .system(size: 12.5, weight: .medium)
        }
    }

    private func topicColor(for scheme: TopicTitleScheme) -> Color {
        switch scheme {
        case .baseline, .fineRegular:
            return AppTheme.Color.textPrimary
        case .softInk, .compactMuted:
            return AppTheme.Color.textSecondary
        }
    }

    // MARK: - 模块 2: 第 4 类 Explore 标签减重

    private var exploreTagsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                badge: "第 4 类 优化",
                title: "More topics to explore 探索区去胶囊感",
                subtitle: "解决痛点：消除 30pt 白实体块的假按钮感，与活动胶囊划清界限"
            )

            VStack(spacing: 14) {
                // 1. 基线
                exploreVariantCard(
                    scheme: .baseline,
                    badge: "基线 · 生产原版",
                    desc: "30pt 高度 / 纯白 #FFFFFF 实底 / 0.5pt 边框 / 投影。按钮感极重，误以为能点。",
                    isRecommended: false
                )

                // 2. 方案 4-A ⭐
                exploreVariantCard(
                    scheme: .softMist,
                    badge: "方案 4-A ⭐ · 轻雾柔霜 (与活动胶囊同族降重 · 推荐)",
                    desc: "24pt 高度 / 4% 极淡柔灰底 (neutral900@4%) / 彻底去边框与阴影。平贴在背景上，像精致的分类印记而非可点按钮。",
                    isRecommended: true
                )

                // 3. 方案 4-B
                exploreVariantCard(
                    scheme: .ghostOutline,
                    badge: "方案 4-B · 待点亮素线框 (幽灵微边)",
                    desc: "24pt 高度 / 去除底色 (100% 透明) / 仅 0.5pt 浅灰发丝边 (neutral900@10%)。表达‘虚位以待’，视觉重量近乎为零。",
                    isRecommended: false
                )

                // 4. 方案 4-C
                exploreVariantCard(
                    scheme: .pureTextFlow,
                    badge: "方案 4-C · 纯净图文流 (彻底去胶囊)",
                    desc: "彻底抛弃药丸！如杂志目录般纯粹：[图标] 标题，各分类间以中性微弱间隔流式排列。生活分类彻底 100% 保持文字形态。",
                    isRecommended: false
                )

                // 5. 方案 4-D
                exploreVariantCard(
                    scheme: .microBadge,
                    badge: "方案 4-D · 微型收敛徽章 (紧凑缩放)",
                    desc: "高度压到 22pt / 纯白底但彻底去阴影 / 8pt 紧凑内衬。体量大幅收敛，不再喧宾夺主。",
                    isRecommended: false
                )
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    private func exploreVariantCard(
        scheme: ExploreTagScheme,
        badge: String,
        desc: String,
        isRecommended: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(badge)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isRecommended ? AppTheme.Color.brandStrong : AppTheme.Color.textSecondary)

                Spacer()

                if isRecommended {
                    Text("推荐：去伪存真")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.Color.brandStrong)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.Color.brandStrong.opacity(0.1), in: Capsule())
                }
            }

            // 标签流渲染展示 (单排 3 个)
            HStack(spacing: 8) {
                renderExploreTag(topic: sampleCategory, scheme: scheme)
                renderExploreTag(topic: .workStudy, scheme: scheme)
                renderExploreTag(topic: .healthFitness, scheme: scheme)
                Spacer()
            }
            .padding(.vertical, 6)

            Text(desc)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Color.textMuted)
                .lineSpacing(2)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isRecommended ? AppTheme.Color.brandStrong.opacity(0.4) : AppTheme.Color.cardBorder, lineWidth: isRecommended ? 1 : 0.5)
        )
    }

    @ViewBuilder
    private func renderExploreTag(topic: SceneCategory, scheme: ExploreTagScheme) -> some View {
        switch scheme {
        case .baseline:
            // 生产原版: 30pt 白底微边带阴影
            Tab2ExploreTopicTag(topic: topic)

        case .softMist:
            // 方案 4-A: 24pt 高度，与方案 2 活动胶囊同底色 (neutral900 @ 4%)，无边框无阴影
            HStack(spacing: 5) {
                Image(systemName: topic.iconName)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
                Text(topic.englishLabel)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .fixedSize()
            }
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(AppTheme.Color.tab2ActivityChipBg, in: Capsule())

        case .ghostOutline:
            // 方案 4-B: 24pt 高度，透明去底，仅 0.5pt 浅线框
            HStack(spacing: 5) {
                Image(systemName: topic.iconName)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
                Text(topic.englishLabel)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .fixedSize()
            }
            .padding(.horizontal, 8.5)
            .frame(height: 24)
            .background(Color.clear)
            .overlay(Capsule().strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))

        case .pureTextFlow:
            // 方案 4-C: 纯图文流 (彻底去胶囊)
            HStack(spacing: 4) {
                Image(systemName: topic.iconName)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
                Text(topic.englishLabel)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .fixedSize()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)

        case .microBadge:
            // 方案 4-D: 微型收敛徽章 22pt 白底微边无阴影
            HStack(spacing: 4.5) {
                Image(systemName: topic.iconName)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
                Text(topic.englishLabel)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Color.white, in: Capsule())
            .overlay(Capsule().strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
        }
    }

    // MARK: - 模块 3: 联合视口模拟 (从 Topics 滑到底部 Explore)

    private var jointViewportSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(
                badge: "联动视口模拟",
                title: "Topics in Progress ➔ Explore 联合呼吸感",
                subtitle: "选择不同方案组合，体会整屏滑动的上下呼应与通透感"
            )

            VStack(spacing: 12) {
                // 组合切换器
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Topics 标题样式:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.Color.textMuted)
                        Picker("Topics", selection: $topicTitleScheme) {
                            Text("3-B 细线 ⭐").tag(TopicTitleScheme.fineRegular)
                            Text("3-A 次级灰").tag(TopicTitleScheme.softInk)
                            Text("基线原版").tag(TopicTitleScheme.baseline)
                        }
                        .pickerStyle(.menu)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Explore 标签样式:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.Color.textMuted)
                        Picker("Explore", selection: $exploreTagScheme) {
                            Text("4-A 轻雾 ⭐").tag(ExploreTagScheme.softMist)
                            Text("4-B 素线框").tag(ExploreTagScheme.ghostOutline)
                            Text("4-C 纯图文").tag(ExploreTagScheme.pureTextFlow)
                            Text("基线原版").tag(ExploreTagScheme.baseline)
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // 模拟完整版面
                VStack(alignment: .leading, spacing: 18) {
                    // Topics 区块标题
                    Text("Topics in progress")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    // 进度卡片容器
                    VStack(spacing: 0) {
                        simulatedProgressRow(cat: sampleCategory)
                        Divider().padding(.horizontal, 14).opacity(0.1)
                        simulatedProgressRow(cat: .workStudy)
                    }
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))

                    // Explore 区块标题
                    Text("More topics to explore")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.top, 10)

                    // 探索标签排布流
                    HStack(spacing: 8) {
                        renderExploreTag(topic: .healthFitness, scheme: exploreTagScheme)
                        renderExploreTag(topic: .shopping, scheme: exploreTagScheme)
                        renderExploreTag(topic: .gettingAround, scheme: exploreTagScheme)
                    }
                    HStack(spacing: 8) {
                        renderExploreTag(topic: .leisure, scheme: exploreTagScheme)
                        renderExploreTag(topic: .tech, scheme: exploreTagScheme)
                    }
                }
                .padding(16)
                .background(AppTheme.Color.pageBg)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5))
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    private func simulatedProgressRow(cat: SceneCategory) -> some View {
        HStack(alignment: .center, spacing: AppTheme.Size.categoryRowContentSpacing) {
            Image(systemName: cat.iconName)
                .font(.system(
                    size: topicTitleScheme == .fineRegular ? 14 : 15,
                    weight: topicTitleScheme == .fineRegular ? .regular : .medium
                ))
                .foregroundStyle(AppTheme.Color.textMuted)
                .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(cat.englishLabel)
                        .font(topicFont(for: topicTitleScheme))
                        .foregroundStyle(topicColor(for: topicTitleScheme))

                    Spacer()

                    HStack(spacing: 4) {
                        Text("14 words")
                            .font(AppTheme.Font.tab2ProgressCount)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(AppTheme.Color.textMuted)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
                }

                // 微线
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.Color.progressTrack).frame(height: 1.5)
                    Capsule().fill(AppTheme.Color.progressFill).frame(width: 120, height: 1.5)
                }
                .frame(height: 1.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 辅助微组件

    private func sectionTitle(badge: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.Color.brandStrong, in: Capsule())

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
            }

            Text(subtitle)
                .font(AppTheme.Font.metaNote)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }
}

// MARK: - Canvas 预览入口

#Preview("Tab2 · 分类标签减重优化 (第3类 & 第4类)") {
    Tab2CategoryRefinementExplorationPreviewView()
}
#endif
