#if DEBUG
import SwiftUI

// DEBUG-only：Hero 封面真机测试页。
// 入口：Settings → Developer → "Hero cover test"。
// 里面放的是**线上真实的 Tab2HeroCard**（预设图作为 Hero，没有真实照片），
// 可以切分类 / 理由状态 / 字号 / 有无活动，直接在真机上看封面左上角的文字与插画。
struct Tab2HeroCoverTestView: View {
    @Environment(\.dismiss) private var dismiss

    private enum ReasonCase: String, CaseIterable, Identifiable {
        case today = "Today ×3", yesterday = "Yesterday", weeks = "3 weeks ago", noDate = "No date"
        var id: String { rawValue }
    }

    private enum TextSize: String, CaseIterable, Identifiable {
        case system = "System", standard = "Default", xxxl = "XXXL", ax1 = "AX1", ax3 = "AX3", ax5 = "AX5"
        var id: String { rawValue }
        /// nil = 不覆盖，跟随手机系统设置。
        var override: DynamicTypeSize? {
            switch self {
            case .system: nil
            case .standard: .large
            case .xxxl: .xxxLarge
            case .ax1: .accessibility1
            case .ax3: .accessibility3
            case .ax5: .accessibility5
            }
        }
    }

    @State private var category: SceneCategory = .weather
    @State private var reason: ReasonCase = .yesterday
    @State private var size: TextSize = .system
    @State private var showsActivities = true
    @State private var savedCap: UIContentSizeCategory?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                // 测试页自己的控件固定在默认字号：系统字号拉到最大时它们也跟着放大会挤成一团、没法操作。
                // 只有下面的 Hero 卡随「Text size」所选字号（System = 跟随手机）变化。
                header.environment(\.dynamicTypeSize, .large)
                controls.environment(\.dynamicTypeSize, .large)
                Tab2HeroCard(category: fixture, onTalk: {})
                    .transformEnvironment(\.dynamicTypeSize) { current in
                        if let override = size.override { current = override }
                    }
                hint.environment(\.dynamicTypeSize, .large)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.paddingCard)
            .padding(.bottom, AppTheme.Space.paddingScreenBottom)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
        // App 整体封顶在「超大」。这个测试页就是为了看无障碍字号下的真实布局，显示期间暂时关掉封顶的
        // 度量压制（活动胶囊用 UIFontMetrics 算尺寸），关闭页面时恢复。
        .onAppear { savedCap = AppDynamicTypeLimit.activeCategory; AppDynamicTypeLimit.activeCategory = nil }
        .onDisappear { AppDynamicTypeLimit.activeCategory = savedCap }
    }

    private var header: some View {
        HStack {
            Text("Hero cover test")
                .font(AppTheme.Font.ctaLabel)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Spacer()
            Button("Close") { dismiss() }
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.interactive)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            row("Category") {
                Picker("Category", selection: $category) {
                    ForEach(SceneCategory.allCases, id: \.self) { Text($0.englishLabel).tag($0) }
                }
                .pickerStyle(.menu)
            }
            row("Reason") {
                Picker("Reason", selection: $reason) {
                    ForEach(ReasonCase.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }
            row("Text size") {
                Picker("Text size", selection: $size) {
                    ForEach(TextSize.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.menu)
            }
            Toggle("Show 2 activities", isOn: $showsActivities)
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .tint(AppTheme.Color.interactive)
        }
        .tint(AppTheme.Color.interactive)
    }

    private func row<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
            Spacer()
            content()
        }
    }

    private var hint: some View {
        Text("Pick a category and watch the top-left of the cover. At AX sizes the reason should drop under the category name and stay whole; \"No date\" should hide the reason. Text size \"System\" follows the phone's Settings → Display & Brightness → Text Size / Accessibility → Larger Text.")
            .font(AppTheme.Font.metaNote)
            .foregroundStyle(AppTheme.Color.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 用真实的数据模型造一张预设图 Hero：不带照片封面的活动 → 走预设图。
    private var fixture: Tab2CategoryData {
        let now = Date()
        let (last, count): (Date?, Int) = {
            switch reason {
            case .today: return (now, 3)
            case .yesterday: return (now.addingTimeInterval(-86_400), 0)
            case .weeks: return (now.addingTimeInterval(-86_400 * 21), 0)
            case .noDate: return (nil, 0)
            }
        }()
        return Tab2CategoryData(
            sceneCategory: category.rawValue,
            wordCount: 24,
            unlocked: true,
            lastMaterialAt: last,
            newMaterialCount: count,
            activityCount: showsActivities ? 2 : 0,
            activities: showsActivities
                ? [Tab2Activity(sceneDetail: "Meetings", occurrenceCount: 2),
                   Tab2Activity(sceneDetail: "Image inquiry", occurrenceCount: 1)]
                : []
        )
    }
}
#endif
