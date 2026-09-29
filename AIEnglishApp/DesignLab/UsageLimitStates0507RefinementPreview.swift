#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - Daily Limit 状态 05 (离线空态) & 状态 07 (加载动效) 优化方案沙箱
// =====================================================================
// 🎯 核心问题剖析：
//
// 1. 【状态 07 · 加载动效位置问题】：
//    - 现状：ProgressView 菊花直接顶在数字槽位（[ 🌀 ] / 5 generations today）。
//    - 痛点：
//      a) firstTextBaseline 下缺少文字基线，导致与后面的文字对齐偏位；
//      b) 数据加载完成瞬间，菊花消失变为数字 2，文字瞬间向左抖动 14pt，产生明显的排版跳动 (Layout Hitch)；
//      c) 视觉上像把转动的表情符号硬卡在句子里，不够稳重。
//    - 提案矩阵：
//      • 方案 7-A (最推荐)：左侧用 Charter 24pt 浅灰破折号 "–" 稳定占位，微型菊花移至卡片右侧 (Spacer 之后) 静默旋转，零排版跳变；
//      • 方案 7-B (顶栏指示)：卡片内纯净展示 "– / 5 generations today"，顶栏 "Daily limit" 右侧配微型菊花；
//      • 方案 7-C (微光呼吸)：数字 "–" 占位，2.0pt 极薄微线轨采用轻缓的不透明度呼吸动效，无旋转菊花。
//
// 2. 【状态 05 · 冷启动离线空状态“重”的问题】：
//    - 现状：整张用量卡片被撕掉，突兀换成一张带有 32pt 巨大断网图标、20pt 粗衬线大标题的 310pt 居中大牌子。
//    - 痛点：
//      a) 巨型居中看板带有全屏 404 故障的沉重压迫感；
//      b) 打破了全 App 其余 6 个状态“用量卡+极薄线”的统一认知模型；
//      c) 高度被强行撑到 310pt，产生突兀的高度跳变（未达标全为 260pt）。
//    - 提案矩阵：
//      • 方案 5-A (最推荐 · 统一模型)：保持用量卡结构（Charter 24pt 浅灰 "–" + 2.0pt 空轨），卡下方展示与状态 3 完全同源的 16pt 左对齐出版物弱网注记 + [Try again] 微胶囊。高度严格锁定 260pt！
//      • 方案 5-B (紧凑轻量卡)：保留独立卡片形态，但将 32pt 图标缩至 18pt，标题降至 16pt 常规体，高度压缩至 260pt；
//      • 方案 5-C (横向整合卡)：整合为类似 SettingsRow 的横向条带（左侧图标、中间提示、右侧重试按钮），高度 260pt。

// =====================================================================
// MARK: - 状态 07 加载动画位置方案实现
// =====================================================================

enum LoadingStyle07: String, CaseIterable, Identifiable {
    case baseline = "Baseline (当前行内插队 · 有跳变)"
    case optionA  = "方案 7-A (右侧静默菊花 · 零跳变 · 最推荐)"
    case optionB  = "方案 7-B (顶栏标题旁微指示)"
    case optionC  = "方案 7-C (轨道轻微呼吸 · 无菊花)"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .baseline: return "Baseline"
        case .optionA:  return "7-A: 右侧菊花"
        case .optionB:  return "7-B: 顶栏指示"
        case .optionC:  return "7-C: 呼吸微线"
        }
    }

    var description: String {
        switch self {
        case .baseline:
            return "当前版本：ProgressView 塞在文字槽位。数据返回时后面的文字会明显左跳。"
        case .optionA:
            return "方案 7-A：左侧用 Charter 24pt \"–\" 占位，小菊花在最右侧静默加载。数据回来时原位平滑变数字，零跳动。"
        case .optionB:
            return "方案 7-B：用量卡内完全不放菊花，纯净展示 \"– / 5\"；菊花放在顶栏 Daily limit 标题右侧。"
        case .optionC:
            return "方案 7-C：左侧 \"– / 5\" 占位，2.0pt 极薄轨道自身进行优雅的不透明度微光呼吸，完全省去机械旋转菊花。"
        }
    }
}

/// 状态 07 各方案卡片组件 (带实时“数据到达模拟”切换)
struct LoadingCard07View: View {
    let style: LoadingStyle07
    let isDataLoaded: Bool // 模拟数据到达与未到达对比

    @State private var pulseOpacity: Double = 0.3

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingCard) {
            // 顶栏
            HStack {
                Text("Daily limit")
                    .font(AppTheme.Font.settingsDocumentTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)

                if style == .optionB && !isDataLoaded {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.Color.textSecondary)
                        .padding(.leading, 4)
                }

                Spacer()
            }
            .padding(.top, 4)

            // 卡片内容
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    if isDataLoaded {
                        Text("2")
                            .font(.custom("Charter", size: 24, relativeTo: .title2))
                            .foregroundStyle(AppTheme.Color.settingsRowText)
                            .transition(.opacity)
                    } else {
                        switch style {
                        case .baseline:
                            // Baseline: 菊花硬插在数字位
                            ProgressView()
                                .controlSize(.small)
                                .tint(AppTheme.Color.textSecondary)
                                .frame(width: 28, height: 28)
                        case .optionA, .optionB, .optionC:
                            // 优雅破折号平稳占位
                            Text("–")
                                .font(.custom("Charter", size: 24, relativeTo: .title2))
                                .foregroundStyle(AppTheme.Color.textMuted)
                        }
                    }

                    Text("/ 5 generations today")
                        .font(.custom("GothicA1-Light", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Spacer()

                    // 方案 7-A: 右侧静默微型菊花
                    if style == .optionA && !isDataLoaded {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppTheme.Color.textSecondary)
                            .transition(.opacity)
                    }
                }

                // 2.0pt 极薄轨道
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.Color.neutralFaint.opacity(0.3))
                            .frame(height: 2.0)

                        if isDataLoaded {
                            Capsule()
                                .fill(AppTheme.Color.textSecondary)
                                .frame(width: geo.size.width * 0.4, height: 2.0)
                        } else if style == .optionC {
                            // 方案 7-C: 呼吸微线
                            Capsule()
                                .fill(AppTheme.Color.textSecondary.opacity(pulseOpacity))
                                .frame(width: geo.size.width * 0.3, height: 2.0)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                                        pulseOpacity = 0.8
                                    }
                                }
                        }
                    }
                }
                .frame(height: 2.0)
                .padding(.top, 2)
            }
            .padding(AppTheme.Space.paddingCard)
            .surfaceCard(cornerRadius: AppTheme.Radius.large)

            // 底部正常注记
            Text("Your daily generations refresh every day at midnight.")
                .font(AppTheme.Font.settingsFormIntro)
                .foregroundStyle(AppTheme.Color.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.Space.paddingXS)
                .padding(.top, 2)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.top, AppTheme.Space.titleToContent)
        .padding(.bottom, AppTheme.Space.paddingPage)
        .frame(width: 375, height: 260, alignment: .top)
        .background(AppTheme.Color.pageBg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24).stroke(AppTheme.Color.cardBorder, lineWidth: 1.0)
        }
    }
}

// =====================================================================
// MARK: - 状态 05 冷启动离线空态去重方案实现
// =====================================================================

enum OfflineEmptyStyle05: String, CaseIterable, Identifiable {
    case baseline = "Baseline (当前 310pt 巨幅看板 · 偏重)"
    case optionA  = "方案 5-A (统一用量卡+卡下弱网注记 · 260pt · 最推荐)"
    case optionB  = "方案 5-B (紧凑轻量空态卡 · 260pt)"
    case optionC  = "方案 5-C (横向条带整合卡 · 260pt)"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .baseline: return "Baseline"
        case .optionA:  return "5-A: 统一卡+注记"
        case .optionB:  return "5-B: 紧凑轻卡"
        case .optionC:  return "5-C: 横向条卡"
        }
    }

    var sheetHeight: CGFloat {
        switch self {
        case .baseline: return 310
        case .optionA, .optionB, .optionC: return 260
        }
    }

    var description: String {
        switch self {
        case .baseline:
            return "当前版本：撕毁用量卡，变成 32pt 巨大图标 + 20pt 粗标题 + 310pt 高度。视觉沉重，破坏统一模型。"
        case .optionA:
            return "方案 5-A：保留统一用量卡（– / 5），卡下配 16pt 左对齐出版物弱网注记 + 行内 Try again。高度锁死 260pt，极度克制。"
        case .optionB:
            return "方案 5-B：保留独立卡，但图标大幅缩为 18pt 细线微图标，标题降为 16pt 常规体，整体紧凑收拢，高度 260pt。"
        case .optionC:
            return "方案 5-C：整合成类似 Settings 行的横向卡片（左侧小图标、中间文案、右侧重试按钮），高度 260pt。"
        }
    }
}

/// 状态 05 各方案视图实现
struct OfflineEmpty05View: View {
    let style: OfflineEmptyStyle05
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Space.paddingCard) {
            // 顶栏
            HStack {
                Text("Daily limit")
                    .font(AppTheme.Font.settingsDocumentTitleSerif)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Spacer()
            }
            .padding(.top, 4)

            // 各方案主体差异
            switch style {
            case .baseline:
                // 当前 Baseline 310pt 巨幅看板
                VStack(spacing: AppTheme.Space.paddingM) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .frame(width: 44, height: 44)

                    VStack(spacing: AppTheme.Space.paddingXS) {
                        Text("You're offline")
                            .font(AppTheme.Font.settingsDocumentTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Text("Connect to the internet to check your remaining quota and generate content.")
                            .font(AppTheme.Font.settingsFormIntro)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(AppTheme.Typography.lineBody)
                    }

                    Button(action: onRetry) {
                        HStack(spacing: AppTheme.Space.paddingXS) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Try again")
                                .font(AppTheme.Font.inlineActionLabel)
                        }
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(AppTheme.Color.neutralFaint.opacity(0.4), in: Capsule())
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(AppTheme.Space.paddingCard)
                .frame(maxWidth: .infinity)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)

            case .optionA:
                // 方案 5-A: 统一用量卡骨架 + 卡下左对齐弱网注记 (260pt)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("–")
                            .font(.custom("Charter", size: 24, relativeTo: .title2))
                            .foregroundStyle(AppTheme.Color.textMuted)

                        Text("/ 5 generations today")
                            .font(.custom("GothicA1-Light", size: 15, relativeTo: .subheadline))
                            .foregroundStyle(AppTheme.Color.textSecondary)

                        Spacer()
                    }

                    // 2.0pt 空灰轨道
                    Capsule()
                        .fill(AppTheme.Color.neutralFaint.opacity(0.3))
                        .frame(height: 2.0)
                        .padding(.top, 2)
                }
                .padding(AppTheme.Space.paddingCard)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)

                // 卡下出版物左对齐弱网注记 + 行内微胶囊 Try again
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)

                    Text("You're offline. Couldn't load today's quota.")
                        .font(AppTheme.Font.settingsFormIntro)
                        .foregroundStyle(AppTheme.Color.textMuted)

                    Spacer()

                    Button(action: onRetry) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10.5, weight: .semibold))
                            Text("Retry")
                                .font(.system(size: 11.5, weight: .medium))
                        }
                        .foregroundStyle(AppTheme.Color.settingsRowText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.Color.cardBg)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(AppTheme.Color.cardBorder, lineWidth: 0.6)
                        }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal, AppTheme.Space.paddingXS)
                .padding(.top, 2)

            case .optionB:
                // 方案 5-B: 紧凑轻量空态卡 (260pt)
                VStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    VStack(spacing: 3) {
                        Text("You're offline")
                            .font(.custom("Charter", size: 16, relativeTo: .body))
                            .foregroundStyle(AppTheme.Color.settingsRowText)

                        Text("Connect to check quota & generate")
                            .font(.custom("GothicA1-Light", size: 13, relativeTo: .caption))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }

                    Button(action: onRetry) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Try again")
                                .font(.custom("GothicA1-Medium", size: 12, relativeTo: .caption))
                        }
                        .foregroundStyle(AppTheme.Color.settingsRowText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.Color.cardBg, in: Capsule())
                        .overlay {
                            Capsule().stroke(AppTheme.Color.cardBorder, lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.top, 2)
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)

            case .optionC:
                // 方案 5-C: 横向条带整合卡 (260pt)
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.Color.neutralFaint.opacity(0.35))
                            .frame(width: 36, height: 36)
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.Color.settingsRowText)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("You're offline")
                            .font(.custom("Charter", size: 15.5, relativeTo: .body))
                            .foregroundStyle(AppTheme.Color.settingsRowText)
                        Text("Connect to load quota")
                            .font(.custom("GothicA1-Light", size: 12.5, relativeTo: .caption))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }

                    Spacer()

                    Button(action: onRetry) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Retry")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(AppTheme.Color.settingsRowText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.Color.pageBg, in: Capsule())
                        .overlay {
                            Capsule().stroke(AppTheme.Color.cardBorder, lineWidth: 0.8)
                        }
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .surfaceCard(cornerRadius: AppTheme.Radius.large)
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.top, AppTheme.Space.titleToContent)
        .padding(.bottom, AppTheme.Space.paddingPage)
        .frame(width: 375, height: style.sheetHeight, alignment: .top)
        .background(AppTheme.Color.pageBg)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24).stroke(AppTheme.Color.cardBorder, lineWidth: 1.0)
        }
    }
}

// =====================================================================
// MARK: - 交互对比实验室主容器 (UsageLimitStates0507LabView)
// =====================================================================

struct UsageLimitStates0507LabView: View {
    enum ActiveLabTab: String, CaseIterable, Identifiable {
        case tab07 = "状态 07: 加载动画位置优化"
        case tab05 = "状态 05: 离线空态去重优化"
        var id: String { rawValue }
    }

    @State private var activeTab: ActiveLabTab = .tab07
    @State private var selected07: LoadingStyle07 = .optionA
    @State private var is07DataLoaded: Bool = false
    @State private var selected05: OfflineEmptyStyle05 = .optionA

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 顶部分页 Tab
                Picker("Tab", selection: $activeTab) {
                    ForEach(ActiveLabTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.vertical, 8)
                .background(AppTheme.Color.cardBg)

                Divider()

                ScrollView {
                    VStack(spacing: 16) {
                        if activeTab == .tab07 {
                            // ── 状态 07 控制区 ──
                            controlSection07
                        } else {
                            // ── 状态 05 控制区 ──
                            controlSection05
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("05 与 07 状态精细优化")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // 状态 07 控制面板与仿真
    private var controlSection07: some View {
        VStack(spacing: 14) {
            // 方案选择药丸
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LoadingStyle07.allCases) { style in
                        let isSelected = (selected07 == style)
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selected07 = style
                            }
                        } label: {
                            Text(style.shortTitle)
                                .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isSelected ? AppTheme.Color.brandWash : AppTheme.Color.cardBg)
                                .foregroundStyle(isSelected ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                                .clipShape(Capsule())
                                .overlay {
                                    if isSelected {
                                        Capsule().stroke(AppTheme.Color.brandTint, lineWidth: 0.8)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 方案解说
            VStack(alignment: .leading, spacing: 2) {
                Text(selected07.rawValue)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
                Text(selected07.description)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .frame(maxWidth: .infinity, alignment: .leading)

            // ★ 数据加载模拟测试按钮 (测试排版是否跳变)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    is07DataLoaded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: is07DataLoaded ? "arrow.counterclockwise" : "play.fill")
                        .font(.system(size: 11))
                    Text(is07DataLoaded ? "点击重置为拉取中" : "点击模拟数据返回 (测试文字是否抖动)")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(is07DataLoaded ? AppTheme.Color.textSecondary : AppTheme.Color.brandInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(is07DataLoaded ? AppTheme.Color.cardBg : AppTheme.Color.brandWash)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(is07DataLoaded ? AppTheme.Color.cardBorder : AppTheme.Color.brandTint, lineWidth: 0.8)
                }
            }

            // 仿真画框
            LoadingCard07View(style: selected07, isDataLoaded: is07DataLoaded)
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        }
    }

    // 状态 05 控制面板与仿真
    private var controlSection05: some View {
        VStack(spacing: 14) {
            // 方案选择药丸
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(OfflineEmptyStyle05.allCases) { style in
                        let isSelected = (selected05 == style)
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                selected05 = style
                            }
                        } label: {
                            Text(style.shortTitle)
                                .font(.system(size: 11.5, weight: isSelected ? .bold : .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isSelected ? AppTheme.Color.brandWash : AppTheme.Color.cardBg)
                                .foregroundStyle(isSelected ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                                .clipShape(Capsule())
                                .overlay {
                                    if isSelected {
                                        Capsule().stroke(AppTheme.Color.brandTint, lineWidth: 0.8)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 方案解说
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selected05.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)
                    Text(selected05.description)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }

                Spacer(minLength: 8)

                Text("\(Int(selected05.sheetHeight))pt")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.Color.neutralFaint.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)

            // 仿真画框
            OfflineEmpty05View(style: selected05, onRetry: {})
                .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
        }
    }
}

// =====================================================================
// MARK: - Xcode Canvas #Preview 预设矩阵
// =====================================================================

#Preview("00 · ★ 05 & 07 状态优化对比实验室 (带动态跳变模拟)") {
    UsageLimitStates0507LabView()
}

#Preview("01 · 状态 07 Baseline: 菊花文字行内硬塞 (文字跳变对照)") {
    LoadingCard07View(style: .baseline, isDataLoaded: false)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("02 · 状态 07 方案 7-A: 卡片右端静默菊花 (零跳变 · 最推荐)") {
    LoadingCard07View(style: .optionA, isDataLoaded: false)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("03 · 状态 07 方案 7-B: 顶栏静默指示 (卡片极简)") {
    LoadingCard07View(style: .optionB, isDataLoaded: false)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("04 · 状态 07 方案 7-C: 呼吸微线 (无旋转菊花)") {
    LoadingCard07View(style: .optionC, isDataLoaded: false)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("05 · 状态 05 Baseline: 310pt 巨幅看板 (过重对照)") {
    OfflineEmpty05View(style: .baseline, onRetry: {})
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("06 · 状态 05 方案 5-A: 统一用量卡+卡下弱网注记 (260pt · 最推荐)") {
    OfflineEmpty05View(style: .optionA, onRetry: {})
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("07 · 状态 05 方案 5-B: 紧凑轻量空态卡 (260pt)") {
    OfflineEmpty05View(style: .optionB, onRetry: {})
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("08 · 状态 05 方案 5-C: 横向条卡 (260pt)") {
    OfflineEmpty05View(style: .optionC, onRetry: {})
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#endif
