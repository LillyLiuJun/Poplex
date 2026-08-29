import SwiftUI

private enum SettingsScreenAnchor {
    static let top = "settings-screen-top"
}

/// 设置区三个页面共用的外壳：暖纸底 + Canvas 装饰 + 固定顶栏 + 滚动内容。
///
/// 三页此前各写了一遍同样的 ZStack/ScrollView/VStack 结构，差异只有四处：
/// 顶部内边距、是否有返回键、固定标题文案、是否随滚动收键盘。这四处作为参数
/// 暴露，其余共享。
///
/// **不含 NavigationStack**：AboutAI / Feedback 是被 push 出来的目的地，
/// 自带 NavigationStack 会套娃。Settings 作为 sheet 根页自己包一层。
///
/// **也不含 `.close` 悬浮键**：Settings 的关闭键挂在 NavigationStack **之外**，
/// 因此在二级页上依然浮着（用户在任何一层都能一键收起整个 sheet）。
/// 那是有意的呈现层行为，不属于单页外壳的职责，留在 SettingsView 里。
///
/// **顶栏遮罩归本外壳所有**（原先挂在 SettingsView 的关闭键上）：
/// 关闭键是父层 overlay，画在**任何**子页面之上；遮罩跟着它，就会盖住
/// 二级页自己的返回键——返回键看着发虚、也点不动。遮罩属于「这一页的顶部」，
/// 必须和它遮的内容待在同一层，父层只留那颗不带底的关闭键。
struct SettingsScreen<Content: View>: View {
    /// 返回键。传 nil 表示这一页不需要（Settings 用页外的悬浮关闭键）。
    var onBack: (() -> Void)?
    /// 固定在顶栏、居中、不随内容滚动的页面标题。有值时（不论是否有返回键）
    /// 都会在顶栏预留一整条 `barHeight`——三页现在都传，保留 nil 只是给
    /// 未来某个不需要标题的调用点留的口子。
    var pinnedTitle: String?
    /// 内容相对顶栏的额外留白。有返回键或固定标题时会自动再加上一整条顶栏高度。
    var topPadding: CGFloat = AppTheme.Space.paddingSection
    /// 仅 Feedback 需要——它有长文本输入框。
    var dismissesKeyboardOnScroll: Bool = false
    /// 值发生变化即把内容滚回顶部。调用方在**推入**二级页时自增，
    /// 这样重置发生在页面被盖住的瞬间，用户回来时看到的已是顶部，看不到跳动。
    var scrollToTopToken: Int = 0

    @ViewBuilder let content: () -> Content

    /// 滚动锚点 id。泛型类型不允许 static 存储属性，故放在类型外。
    private var topAnchor: String { SettingsScreenAnchor.top }

    /// 顶栏控件边长，随 Dynamic Type 放大——必须与 SettingsCircleButton 用同一个
    /// 基准，否则大字号下按钮长大了、遮罩带还是原来那么高，按钮会露出带子外面。
    @ScaledMetric(relativeTo: .body) private var barControlSide = AppTheme.Size.barControl

    /// 顶栏条高 = 控件本体 + 上下留白。遮罩带按它算——遮罩的职责是罩住顶部
    /// 那条固定控件带，所以它跟控件走，与内容排版留白（topPadding）各自独立。
    private var barHeight: CGFloat {
        barControlSide + AppTheme.Space.paddingS * 2
    }

    /// 静止状态下内容之上的空白区高度。
    private var contentTopInset: CGFloat {
        (onBack == nil && pinnedTitle == nil ? 0 : barHeight) + topPadding
    }

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()
            CanvasBackground().ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
                        content()
                    }
                    .padding(.top, contentTopInset)
                    .padding(.bottom, AppTheme.Space.paddingScreenBottom)
                    .frame(maxWidth: .infinity)
                    // 锚点挂在**加完内边距之后**的容器上。挂在容器内部的话，
                    // `scrollTo(anchor: .top)` 会把那个内部视图的顶边对齐到视口顶边，
                    // 等于把顶部内边距一起滚出屏幕——归顶后页面会比初始状态高一整个
                    // topPadding（实测正好差 48pt）。挂在外面，对齐的就是真正的内容原点。
                    .id(topAnchor)
                }
                .scrollDismissesKeyboard(dismissesKeyboardOnScroll ? .interactively : .automatic)
                .onChange(of: scrollToTopToken) { _, _ in
                    proxy.scrollTo(topAnchor, anchor: .top)
                }
            }
        }
        // 柔化层先画：内容从它下面滚过去。它照旧吃点按——被盖住的内容看不清，
        // 让它可点等于鼓励误触。
        //
        // 用 SheetTopScrim（pageBg 同色渐隐）而不是 Tab1 的 TopBarProgressiveMask
        // （ultraThinMaterial）：material 自带一层偏冷的半透明白，盖在这片平坦的
        // 暖纸底上会显出一条更冷更灰的横带，边界正压在 sheet 顶边——详见该文件注释。
        .overlay(alignment: .top) {
            SheetTopScrim()
                .frame(height: barHeight)
        }
        // 固定标题：居中、系统导航栏字号量级的品牌衬线，遮罩之上、返回键之下
        // （返回键在左侧，标题居中，短文案下两者不会重叠，见设计稿）。
        // h1 语义从原本三页各自的滚动大标题搬过来——分组标题（SettingsCard）
        // 是 h2，读屏用户靠这层级知道 "Legal" 从属于 "Settings"，见
        // settingsPageTitleSemantics 的注释。
        .overlay(alignment: .top) {
            if let pinnedTitle {
                Text(pinnedTitle)
                    .font(AppTheme.Font.settingsPinnedTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .frame(height: barHeight)
                    .frame(maxWidth: .infinity)
                    .settingsPageTitleSemantics()
            }
        }
        // 返回键后画，稳稳压在遮罩之上。
        .overlay(alignment: .top) {
            if let onBack {
                HStack {
                    SettingsCircleButton(kind: .back, action: onBack)
                    Spacer()
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.vertical, AppTheme.Space.paddingS)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
