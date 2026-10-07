import SwiftUI

/// 「More topics to explore」的排布形态——纯函数，视图与单测共用。
/// 胶囊宽度一律跟随文字自然宽度，任何形态都不拉伸撑满整行。
enum Tab2ExploreTagLayout: Equatable {
    /// 0 个：整块不渲染（标题一起）。
    case hidden
    /// 1~3 个：单排靠左，右侧自然留白。
    case singleRow
    /// 4 个：上 3 下 1 的非对称节奏。
    case threePlusOne
    /// ≥5 个：两排，前一排取 ceil(n/2) 个，整体可横滑、右侧自然微露。
    case twoRows

    static func forCount(_ count: Int) -> Tab2ExploreTagLayout {
        switch count {
        case ..<1: return .hidden
        case 1...3: return .singleRow
        case 4: return .threePlusOne
        default: return .twoRows
        }
    }

    /// 按形态把主题切成若干排（hidden → 空）。
    static func rows<T>(_ items: [T]) -> [[T]] {
        switch forCount(items.count) {
        case .hidden: return []
        case .singleRow: return [items]
        case .threePlusOne: return [Array(items.prefix(3)), Array(items.suffix(1))]
        case .twoRows:
            let split = (items.count + 1) / 2
            return [Array(items.prefix(split)), Array(items.dropFirst(split))]
        }
    }
}

extension SceneCategory {
    /// 还没有任何词的主题（RPC 只返回有词的分类，所以由全集减去有词的推算）。
    /// 顺序按枚举声明顺序，Other 恒在最后。旧中文键经 `from(_:)` 归一后再比对。
    static func unstarted(given categories: [Tab2CategoryData]) -> [SceneCategory] {
        let started = Set(categories.filter { $0.wordCount >= 1 }.map { SceneCategory.from($0.sceneCategory) })
        return allCases.filter { !started.contains($0) }
    }
}

/// Tab2「More topics to explore」区块：一级标题 + 未开启主题胶囊 + 可选注脚。
/// 待解锁页与已解锁页共用；topics 为空时整块不渲染。
struct Tab2MoreTopicsSection: View {
    let topics: [SceneCategory]
    /// 待解锁页传说明注脚；已解锁页传 nil（用户已懂规则，不再解释）。
    var footnote: Tab2Footnote? = nil
    /// 变化即把横滑归位到最左（MineView 在用户离开 Tab2 时换新值）。
    var resetToken: UUID? = nil

    private let scrollStartID = "tab2ExploreTopicsStart"

    /// 可视宽度与内容宽度：内容超出可视宽度才真的能横向滚动。能滚动时才认领页签滑动手势，
    /// 放得下的（比如只剩 3 个）不抢——那种情况下右划仍应切回 Today。
    @State private var viewportWidth: CGFloat = 0
    @State private var contentWidth: CGFloat = 0
    private var isScrollable: Bool { contentWidth > viewportWidth + 0.5 }

    var body: some View {
        let rows = Tab2ExploreTagLayout.rows(topics)
        if rows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("More topics to explore")
                    .font(AppTheme.Font.sectionTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, AppTheme.Tab2ExploreTopics.Layout.titleToTags)

                // 单一水平滚动容器包住所有排：多排联动横滑，少时自然靠左。
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: AppTheme.Tab2ExploreTopics.Layout.tagGap) {
                            ForEach(rows.indices, id: \.self) { index in
                                HStack(spacing: AppTheme.Tab2ExploreTopics.Layout.tagGap) {
                                    ForEach(rows[index], id: \.self) { topic in
                                        Tab2ExploreTopicTag(topic: topic)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        // 给胶囊阴影留出不被裁切的余量
                        .padding(.vertical, AppTheme.Tab2ExploreTopics.Shadow.tagRadius)
                        // 锚点挂在含左内边距的整块内容上：归位后左侧留白完整，不会把第一枚胶囊贴到屏幕边。
                        .id(scrollStartID)
                        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { viewportWidth = $0 }
                    // 手指在这里横向拖动时，页签容器不把这次手势当作切页（见 TabSwipeArbiter）。
                    .claimsTabSwipe(isScrollable: isScrollable)
                    .onChange(of: resetToken) { _, _ in
                        // 用户已离开 Tab2、看不到这里——无动画直接归位，回来时就是初始状态。
                        proxy.scrollTo(scrollStartID, anchor: .leading)
                    }
                }

                if let footnote {
                    footnote
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.top, AppTheme.Tab2ExploreTopics.Layout.tagsToFootnote)
                }
            }
        }
    }
}

/// 未开启主题的中性胶囊：纯展示，不可点（PM 2026-10-03 选 B，视觉暂不弱化，看真机效果再定）。
struct Tab2ExploreTopicTag: View {
    let topic: SceneCategory

    var body: some View {
        HStack(spacing: AppTheme.Tab2ExploreTopics.Layout.tagIconToLabel) {
            Image(systemName: topic.iconName)
                .font(.system(size: AppTheme.Tab2ExploreTopics.Layout.tagIconGlyph, weight: .regular))
                .foregroundStyle(AppTheme.Tab2ExploreTopics.Color.tagIcon)
                .accessibilityHidden(true)

            Text(topic.englishLabel)
                .font(AppTheme.Font.tab2ExploreTagLabel)
                .foregroundStyle(AppTheme.Tab2ExploreTopics.Color.tagLabel)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, AppTheme.Tab2ExploreTopics.Layout.tagHorizontalInset)
        .frame(minHeight: AppTheme.Tab2ExploreTopics.Layout.tagMinHeight)
        .background {
            Capsule()
                .fill(AppTheme.Tab2ExploreTopics.Color.tagFill)
                .strokeBorder(
                    AppTheme.Tab2ExploreTopics.Color.tagBorder,
                    lineWidth: AppTheme.Tab2ExploreTopics.Layout.tagBorderWidth
                )
        }
        .shadow(
            color: AppTheme.Tab2ExploreTopics.Color.tagShadow,
            radius: AppTheme.Tab2ExploreTopics.Shadow.tagRadius,
            y: AppTheme.Tab2ExploreTopics.Shadow.tagY
        )
    }
}
