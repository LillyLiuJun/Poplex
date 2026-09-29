#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - Daily Limit (使用额度弹窗) 生产级全状态像素级画板与设计审计
// =====================================================================
// 🎯 核心目标：
//   1. 100% 像素级复原生产代码 (UsageLimitButton.swift -> UsageLimitSheet) 的真实表现；
//   2. 穷尽业务运行中的 7 种核心状态（正常未满、达标展开、离线缓存、离线达标、冷启空态、0次初始、加载态）；
//   3. 提供真实的系统级弹窗容器模拟 (393×852 满屏真机视口，带暖纸底与系统遮罩)；
//   4. 嵌入动态交互式滑块 (Slider 0...5)，动态观察从 4/5 到 5/5 时弹窗高度从 260pt 展开至 375pt 的弹性动画；
//   5. 显式对照看板，精准标定当前 4 大视觉脱节问题（顶部抓手+关闭键冲突、卡片无0.5pt边框、危险红焦虑施压、大小写规范）。

// =====================================================================
// MARK: - 业务状态枚举定义
// =====================================================================

enum UsageLimitVisualState: String, CaseIterable, Identifiable {
    case normalOnline         = "01 · 正常在线 (2/5 · 260pt)"
    case limitReached         = "02 · 在线达标 (5/5 · 375pt)"
    case offlineCacheNormal   = "03 · 离线未达标 (2/5 · 260pt)"
    case offlineCacheReached  = "04 · 离线且达标 (5/5 · 405pt)"
    case offlineEmpty         = "05 · 离线空状态 (–/5 · 310pt)"
    case zeroInitial          = "06 · 初始零使用 (0/5 · 260pt)"
    case loadingState         = "07 · 加载过渡态 (拉取中 · 260pt)"

    var id: String { rawValue }

    var shortTag: String {
        switch self {
        case .normalOnline:        return "2/5 在线"
        case .limitReached:        return "5/5 达标"
        case .offlineCacheNormal:  return "2/5 离线"
        case .offlineCacheReached: return "5/5 离线"
        case .offlineEmpty:        return "离线空态"
        case .zeroInitial:         return "0/5 初始"
        case .loadingState:        return "加载中"
        }
    }

    var sheetHeight: CGFloat {
        switch self {
        case .normalOnline, .zeroInitial, .offlineCacheNormal, .loadingState:
            return 260
        case .limitReached:
            return 375
        case .offlineCacheReached:
            return 405
        case .offlineEmpty:
            return 310
        }
    }

    var usedCount: Int? {
        switch self {
        case .normalOnline, .offlineCacheNormal:
            return 2
        case .limitReached, .offlineCacheReached:
            return 5
        case .zeroInitial:
            return 0
        case .offlineEmpty, .loadingState:
            return nil
        }
    }

    var isFailed: Bool {
        switch self {
        case .offlineCacheNormal, .offlineCacheReached, .offlineEmpty:
            return true
        default:
            return false
        }
    }

    var diagnosisNotes: String {
        switch self {
        case .normalOnline:
            return "【正常在线未满】：高度 260pt。粗黑 34pt Charter 数字，黑色进度条（40%）。卡片无 0.5pt 边框，使用单层 12pt 漂浮阴影；顶部同时有系统抓手与 32pt 关闭小圆圈。"
        case .limitReached:
            return "【在线额度用尽】：高度展开至 375pt。数字和进度条被刷成刺眼危险红 (#DC2626)，插入解释段落与全宽胶囊按钮。产生强烈的犯错/被罚受挫感，违背 Warm Minimalism。"
        case .offlineCacheNormal:
            return "【离线未满带缓存】：高度 260pt。使用本地缓存显示 2/5 与进度条，底部追加带 wifi.slash 的离线弱网提示文案。"
        case .offlineCacheReached:
            return "【离线满额带缓存】：高度撑开至最大 405pt。既包含达标 CTA 申请邀请码按钮，底部又追加弱网同步提示，纵向排布较为密集。"
        case .offlineEmpty:
            return "【冷启动离线空态】：高度 310pt。冷启动无今日缓存且断网，主卡片被替换为 44pt 居中大图标与离线说明卡片。"
        case .zeroInitial:
            return "【初始零使用】：高度 260pt。展示 0 / 5，进度条完全空白，底部展示零点刷新提示。"
        case .loadingState:
            return "【网络请求过渡态】：高度 260pt。数字区域居中展示轻量小菊花 (ProgressView)，不显示误导性的 0，高度保持稳定无抖动。"
        }
    }
}

// =====================================================================
// MARK: - 1:1 像素级系统 Sheet 仿真画板 (UsageLimitCanvasFrame)
// =====================================================================

/// 模拟真机 iPhone 16 (393 × 852) 视口下，真实弹出的底部 Sheet 效果
struct UsageLimitCanvasFrame<SheetContent: View>: View {
    let sheetHeight: CGFloat
    let title: String
    let subtitle: String
    @ViewBuilder let sheetContent: () -> SheetContent

    init(
        sheetHeight: CGFloat,
        title: String = "Daily limit",
        subtitle: String = "Usage Quota Sheet",
        @ViewBuilder sheetContent: @escaping () -> SheetContent
    ) {
        self.sheetHeight = sheetHeight
        self.title = title
        self.subtitle = subtitle
        self.sheetContent = sheetContent
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. 底层宿主界面模拟 (Tab1 暖纸底色 + 顶部微胶囊)
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // 模拟 Tab1 顶部栏
                HStack {
                    Circle()
                        .fill(AppTheme.Color.cardBg)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                        )
                        .surfacePill(in: Circle())

                    Spacer()

                    Text("Today")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    UsageGaugeIcon()
                        .foregroundStyle(AppTheme.Color.textPrimary)
                        .frame(width: 44, height: 44)
                        .surfacePill(in: Circle())
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 16)

                Spacer()

                // 宿主背景模拟卡片
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .fill(AppTheme.Color.cardBg.opacity(0.6))
                        .frame(height: 180)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                    RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                        .fill(AppTheme.Color.cardBg.opacity(0.4))
                        .frame(height: 120)
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                }
                .padding(.bottom, 60)

                Spacer()
            }

            // 2. 真实系统 Sheet 暗色遮罩 (Scrim)
            Color.black.opacity(0.24)
                .ignoresSafeArea()

            // 3. 底部 Sheet 仿真容器 (严格对齐 iOS 17 系统级圆角与物理阴影)
            ZStack(alignment: .top) {
                // 生产级 Sheet 实际内容
                sheetContent()

                // 系统原生顶部拖拽把手指示条 (Drag Indicator)
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
            }
            .frame(height: sheetHeight)
            .background(AppTheme.Color.pageBg)
            .clipShape(UnevenRoundedRectangle(
                topLeadingRadius: AppTheme.Radius.large,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: AppTheme.Radius.large,
                style: .continuous
            ))
            .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: -4)
        }
        .frame(width: 393, height: 852)
        .clipped()
    }
}

// =====================================================================
// MARK: - 全功能交互式实验室 (UsageLimitInteractiveLab)
// =====================================================================

struct UsageLimitInteractiveLab: View {
    @State private var selectedPreset: UsageLimitVisualState = .normalOnline
    @State private var dynamicCount: Double = 2
    @State private var isOfflineMode: Bool = false
    @State private var showSpecsAudit: Bool = true

    init() {
        FontLoader.registerCustomFonts()
    }

    /// 动态计算出的当前弹窗高度
    private var computedHeight: CGFloat {
        if selectedPreset == .offlineEmpty {
            return 310
        }
        let count = Int(dynamicCount)
        if count >= 5 {
            return isOfflineMode ? 405 : 375
        } else {
            return 260
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── 顶部控制台 ──
            VStack(spacing: 10) {
                // 1. 预设状态胶囊选择器
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(UsageLimitVisualState.allCases) { state in
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                    applyPreset(state)
                                }
                            } label: {
                                Text(state.shortTag)
                                    .font(.system(size: 11.5, weight: selectedPreset == state ? .bold : .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedPreset == state ? AppTheme.Color.brandWash : AppTheme.Color.cardBg)
                                    .foregroundStyle(selectedPreset == state ? AppTheme.Color.brandInk : AppTheme.Color.textSecondary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            selectedPreset == state ? AppTheme.Color.brandTint : AppTheme.Color.border,
                                            lineWidth: 0.8
                                        )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }

                // 2. 动效滑块与网络开关 (可直接拖动看 4/5 升至 5/5 时弹窗高度自动拉伸)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("生成次数: \(Int(dynamicCount)) / 5")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Int(dynamicCount) >= 5 ? AppTheme.Color.danger : AppTheme.Color.textPrimary)
                            Spacer()
                            Text(Int(dynamicCount) >= 5 ? "⚠️ 触发达标展开 (375pt)" : "未满额度 (260pt)")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                        }

                        Slider(value: $dynamicCount, in: 0...5, step: 1)
                            .tint(Int(dynamicCount) >= 5 ? AppTheme.Color.danger : AppTheme.Color.textPrimary)
                    }

                    Divider()
                        .frame(height: 28)

                    // 离线开关
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isOfflineMode.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isOfflineMode ? "wifi.slash" : "wifi")
                                .font(.system(size: 12, weight: .semibold))
                            Text(isOfflineMode ? "离线" : "在线")
                                .font(.system(size: 11.5, weight: .bold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(isOfflineMode ? AppTheme.Color.danger.opacity(0.12) : AppTheme.Color.cardBg)
                        .foregroundStyle(isOfflineMode ? AppTheme.Color.danger : AppTheme.Color.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)

                // 3. 诊断信息条
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedPreset.rawValue)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text(selectedPreset.diagnosisNotes)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .lineSpacing(2)
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 8)
            .background(AppTheme.Color.cardBg)
            .overlay(alignment: .bottom) {
                Divider()
            }

            // ── 中间 1:1 真机满屏画布 ──
            UsageLimitCanvasFrame(sheetHeight: computedHeight) {
                if selectedPreset == .offlineEmpty {
                    // 离线冷启空态
                    UsageLimitSheet(usedCount: nil, dailyLimit: 5, initialLoadFailed: true)
                } else if selectedPreset == .loadingState {
                    // 首次加载过渡态
                    UsageLimitSheet(usedCount: nil, dailyLimit: 5, initialLoadFailed: false)
                } else {
                    // 动态次数实时驱动
                    UsageLimitSheet(
                        usedCount: Int(dynamicCount),
                        dailyLimit: 5,
                        initialLoadFailed: isOfflineMode
                    )
                }
            }
            .scaleEffect(0.92, anchor: .top)
            .frame(maxHeight: .infinity)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    private func applyPreset(_ state: UsageLimitVisualState) {
        selectedPreset = state
        if let count = state.usedCount {
            dynamicCount = Double(count)
        }
        isOfflineMode = state.isFailed
    }
}

// =====================================================================
// MARK: - 真实系统级底层 Sheet 唤起器 (UsageLimitSystemSheetLauncher)
// =====================================================================

/// 在真实 SwiftUI 运行环境中体验原生手势、拖拽阻尼与系统级过渡
struct UsageLimitSystemSheetLauncher: View {
    @State private var showSheet = false
    @State private var currentCount: Int = 2
    @State private var isOffline: Bool = false

    init() {
        FontLoader.registerCustomFonts()
    }

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack(spacing: AppTheme.Space.paddingSection) {
                // 模拟 Tab1 顶栏
                HStack {
                    Circle()
                        .fill(AppTheme.Color.cardBg)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                        )
                        .surfacePill(in: Circle())

                    Spacer()

                    Text("Today")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Spacer()

                    UsageLimitButton {
                        showSheet = true
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: AppTheme.Space.paddingM) {
                    Image(systemName: "arrow.up.right.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(AppTheme.Color.brandStrong)

                    Text("Tap the gauge button above or click below to present the real SwiftUI .sheet()")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    // 快速调节次数
                    Stepper("Test Used Count: \(currentCount) / 5", value: $currentCount, in: 0...5)
                        .font(AppTheme.Font.statusNote)
                        .padding(.horizontal, 48)

                    Toggle("Simulate Offline Mode", isOn: $isOffline)
                        .font(AppTheme.Font.statusNote)
                        .padding(.horizontal, 48)

                    Button {
                        showSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Open Daily Limit Sheet")
                                .font(AppTheme.Font.ctaLabel)
                        }
                        .foregroundStyle(AppTheme.Color.textOnChip)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppTheme.Color.interactive, in: Capsule())
                        .padding(.horizontal, 40)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showSheet) {
            UsageLimitSheet(usedCount: currentCount, dailyLimit: 5, initialLoadFailed: isOffline)
        }
    }
}

// =====================================================================
// MARK: - Xcode Canvas #Preview 预设矩阵 (全状态一览)
// =====================================================================

#Preview("00 · ★ 全状态交互实验室 (动效滑块 · 状态切换 · 规范诊断)") {
    UsageLimitInteractiveLab()
}

#Preview("01 · 状态 1: 正常在线未达标 (2/5 · 260pt · 纯正客观)") {
    UsageLimitCanvasFrame(sheetHeight: 260) {
        UsageLimitSheet(usedCount: 2, dailyLimit: 5)
    }
}

#Preview("02 · 状态 2: 在线额度已用尽 (5/5 · 375pt · 展开 CTA)") {
    UsageLimitCanvasFrame(sheetHeight: 375) {
        UsageLimitSheet(usedCount: 5, dailyLimit: 5)
    }
}

#Preview("03 · 状态 3: 离线未达标带缓存 (2/5 · 260pt · 弱网提示)") {
    UsageLimitCanvasFrame(sheetHeight: 260) {
        UsageLimitSheet(usedCount: 2, dailyLimit: 5, initialLoadFailed: true)
    }
}

#Preview("04 · 状态 4: 离线且达标带缓存 (5/5 · 405pt · 弱网提示)") {
    UsageLimitCanvasFrame(sheetHeight: 405) {
        UsageLimitSheet(usedCount: 5, dailyLimit: 5, initialLoadFailed: true)
    }
}

#Preview("05 · 状态 5: 冷启动离线空状态 (无缓存 · 310pt · 居中大图)") {
    UsageLimitCanvasFrame(sheetHeight: 310) {
        UsageLimitSheet(usedCount: nil, dailyLimit: 5, initialLoadFailed: true)
    }
}

#Preview("06 · 状态 6: 0次初始未用态 (0/5 · 260pt · 空轨道)") {
    UsageLimitCanvasFrame(sheetHeight: 260) {
        UsageLimitSheet(usedCount: 0, dailyLimit: 5)
    }
}

#Preview("07 · 状态 7: 首次加载拉取中 (菊花微动效 · 260pt)") {
    UsageLimitCanvasFrame(sheetHeight: 260) {
        UsageLimitSheet(usedCount: nil, dailyLimit: 5, initialLoadFailed: false)
    }
}

#Preview("08 · 真实系统底层 Sheet (支持原生手势拖拽关闭)") {
    UsageLimitSystemSheetLauncher()
}

#endif
