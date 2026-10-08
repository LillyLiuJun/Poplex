#if DEBUG
import SwiftUI

// =====================================================================
// MARK: - Onboarding S1 生产同构沙箱 (OnboardingS1ProductionLab)
// =====================================================================
// 🎯 核心使命：
//   1. 架构 100% 同构于生产 OnboardingScreen1View（报头 36pt + 弹性 Spacer + 文案 + 尾块锚定 CTA）；
//   2. 文案严格使用最初 main 的原版：「Build your language\nfrom work & life.」；
//   3. 将 4 组真实落差方案以同构逻辑精确实现：
//      - main 真实原版：heroToCTA = 200pt (基准线 399pt)
//      - 方案 3：heroToCTA = 180pt (微沉 20pt，标题顶 418pt)
//      - 方案 1：heroToCTA = 160pt (下沉 40pt，标题顶 439pt · 推荐首选)
//      - 方案 4：heroToCTA = 110pt (深沉 90pt，标题顶 489pt · 经典海报底锚)
//   4. 零污染生产代码，支持 Xcode Canvas 100% 满屏原生沉浸检视与横向同轴对比。

enum S1HeroPositionOption: String, CaseIterable, Identifiable {
    case mainBaseline = "🟢 main 真实基线 (heroToCTA = 200pt)"
    case option3      = "🟣 方案 3 · 黄金留白比 (heroToCTA = 180pt · 微沉20pt)"
    case option1      = "🔵 方案 1 · 黄金中偏下 (heroToCTA = 160pt · 下沉40pt · 推荐)"
    case option4      = "🟠 方案 4 · 深底锚海报 (heroToCTA = 110pt · 深沉90pt)"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .mainBaseline: return "main 原版"
        case .option3:      return "方案 3 (微沉)"
        case .option1:      return "方案 1 (推荐)"
        case .option4:      return "方案 4 (深沉)"
        }
    }

    /// 核心距离：文字组下缘到 Continue 按钮上缘的严格物理距离
    var heroToCTA: CGFloat {
        switch self {
        case .mainBaseline: return 200.0
        case .option3:      return 180.0
        case .option1:      return 160.0
        case .option4:      return 110.0
        }
    }

    /// 标题顶距屏幕顶部的真实物理坐标 (iPhone 16 Pro 852pt 视口下)
    var titleTopCoord: CGFloat {
        switch self {
        case .mainBaseline: return 399.0
        case .option3:      return 418.0
        case .option1:      return 439.0
        case .option4:      return 489.0
        }
    }

    var badge: String {
        switch self {
        case .mainBaseline: return "真实基线"
        case .option3:      return "微沉 20pt"
        case .option1:      return "推荐首选 · 下沉 40pt"
        case .option4:      return "海报底锚 · 下沉 90pt"
        }
    }

    var note: String {
        switch self {
        case .mainBaseline:
            return "main 分支最初设计的基准落位。距 Continue 严格 200pt，上方由 Spacer 弹性吸收，呼吸自然舒展。"
        case .option3:
            return "比 main 略微下沉 20pt（距 Continue 180pt）。上留白与下留白呈黄金反比，文字与 Continue 对仗微收紧。"
        case .option1:
            return "比 main 明确下沉 40pt（距 Continue 160pt）。视觉重心正好落在 61.8% 黄金分割线，天顶更显开阔，下方稳健扎实。"
        case .option4:
            return "比 main 大幅下沉 90pt（距 Continue 110pt）。文字极度压底，现代先锋海报质感，天高地厚。"
        }
    }
}

// =====================================================================
// MARK: - 生产同构画板 (OnboardingS1ProductionCanvas)
// =====================================================================

struct OnboardingS1ProductionCanvas: View {
    var option: S1HeroPositionOption = .option1
    var showGuides: Bool = false
    var mastheadMarkHeight: CGFloat = AppTheme.Size.onboardingS1MastheadMarkHeight

    private let mastheadReferenceFrameHeight: CGFloat = PoplexLockupMark.minimumHeight
    private var mastheadInsets: (top: CGFloat, leading: CGFloat) {
        let lockup = PoplexLockupMark(markHeight: mastheadMarkHeight)
        return (
            top: lockup.topInset - mastheadReferenceFrameHeight * PoplexLockupMark.topInsetRatio,
            leading: lockup.leadingInset - mastheadReferenceFrameHeight * PoplexLockupMark.leadingInsetRatio
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // 1. 共享背景 (暖纸 + 点纹 + 晨曦光晕)
                OnboardingAuraBackground()

                // 2. 生产同构滑动/弹性内容流
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 顶部报头 (定稿 36pt，与标题共左轴)
                        PoplexLockupMark(markHeight: mastheadMarkHeight)
                            .padding(.leading, AppTheme.Space.paddingPage - mastheadInsets.leading)
                            .padding(.top, AppTheme.Size.onboardingS1MastheadTop - mastheadInsets.top)

                        // 上方留白弹性吸收机型差异
                        Spacer(minLength: AppTheme.Space.onboardingHeaderToContent)

                        // 核心文字块：main 原版最初文案
                        textBlock
                            .padding(.horizontal, AppTheme.Space.paddingPage)

                        // 锚定尾块：严格按照当前方案的 heroToCTA 撑出距离
                        Color.clear.frame(
                            height: option.heroToCTA
                                + AppTheme.Size.onboardingContinueBottom
                                + AppTheme.Size.inputBarMinHeight
                        )
                    }
                    .frame(minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)

                // 3. 底部固定沉底 Continue 按钮 (近黑胶囊)
                OnboardingPrimaryButton(title: "Continue", action: {})
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.bottom, AppTheme.Size.onboardingContinueBottom)

                // 4. 标尺线 (可选透视)
                if showGuides {
                    guidesOverlay(screenHeight: geo.size.height)
                }
            }
        }
    }

    // 文字组：main 原版最初文案 (两行大标题 + 两行副标题)
    private var textBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.onboardingTitleToLead) {
            Text("Build your language\nfrom work & life.")
                .font(AppTheme.Font.onboardingHeroSerif)
                .tracking(AppTheme.Typography.trackingDisplay)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Not textbooks. Not drills.\nJust what's happening around you.")
                .font(AppTheme.Font.onboardingLeadSerif)
                .lineSpacing(AppTheme.Typography.lineBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // 标尺辅助线
    private func guidesOverlay(screenHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // main 真实顶线
            guideLine(y: 399, color: Color(red: 0.18, green: 0.49, blue: 0.20), label: "main 399pt", isDashed: true)

            // 方案 3 顶线
            guideLine(y: 418, color: Color(red: 0.55, green: 0.14, blue: 0.67), label: "方案3 418pt", isDashed: true)

            // 方案 1 顶线
            guideLine(y: 439, color: Color(red: 0.10, green: 0.46, blue: 0.82), label: "方案1 439pt (推荐)", isDashed: false)

            // 方案 4 顶线
            guideLine(y: 489, color: Color(red: 0.85, green: 0.26, blue: 0.08), label: "方案4 489pt", isDashed: true)
        }
        .allowsHitTesting(false)
    }

    private func guideLine(y: CGFloat, color: Color, label: String, isDashed: Bool) -> some View {
        ZStack(alignment: .trailing) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: 1000, y: y))
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: isDashed ? [4, 4] : []))

            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .offset(y: y - 10)
                .padding(.trailing, 16)
        }
    }
}

// =====================================================================
// MARK: - 四机并排横向对比画板 (OnboardingS1MultiPhoneInspectionView)
// =====================================================================

struct OnboardingS1MultiPhoneInspectionView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                phoneCard(option: .mainBaseline, badgeColor: Color(red: 0.18, green: 0.49, blue: 0.20))
                phoneCard(option: .option3, badgeColor: Color(red: 0.55, green: 0.14, blue: 0.67))
                phoneCard(option: .option1, badgeColor: Color(red: 0.10, green: 0.46, blue: 0.82))
                phoneCard(option: .option4, badgeColor: Color(red: 0.85, green: 0.26, blue: 0.08))
            }
            .padding(24)
        }
        .background(Color(white: 0.12))
    }

    private func phoneCard(option: S1HeroPositionOption, badgeColor: Color) -> some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(option.shortTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                Text(option.badge)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(badgeColor)

                Text("heroToCTA: \(Int(option.heroToCTA))pt ｜ 顶线: \(Int(option.titleTopCoord))pt")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(width: 320, alignment: .leading)

            OnboardingS1ProductionCanvas(option: option, showGuides: false)
                .frame(width: 320, height: 694) // 852pt 等比缩放
                .clipShape(RoundedRectangle(cornerRadius: 38))
                .overlay(
                    RoundedRectangle(cornerRadius: 38)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
        }
    }
}

// =====================================================================
// MARK: - 交互式实时滑块实验室 (OnboardingS1InteractiveSliderView)
// =====================================================================

struct OnboardingS1InteractiveSliderView: View {
    @State private var heroToCTA: CGFloat = 160
    @State private var showGuides: Bool = true

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    OnboardingAuraBackground()

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            PoplexLockupMark(markHeight: AppTheme.Size.onboardingS1MastheadMarkHeight)
                                .padding(.leading, AppTheme.Space.paddingPage)
                                .padding(.top, AppTheme.Size.onboardingS1MastheadTop)

                            Spacer(minLength: AppTheme.Space.onboardingHeaderToContent)

                            VStack(alignment: .leading, spacing: AppTheme.Space.onboardingTitleToLead) {
                                Text("Build your language\nfrom work & life.")
                                    .font(AppTheme.Font.onboardingHeroSerif)
                                    .tracking(AppTheme.Typography.trackingDisplay)
                                    .foregroundStyle(AppTheme.Color.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("Not textbooks. Not drills.\nJust what's happening around you.")
                                    .font(AppTheme.Font.onboardingLeadSerif)
                                    .lineSpacing(AppTheme.Typography.lineBody)
                                    .foregroundStyle(AppTheme.Color.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, AppTheme.Space.paddingPage)

                            Color.clear.frame(
                                height: heroToCTA
                                    + AppTheme.Size.onboardingContinueBottom
                                    + AppTheme.Size.inputBarMinHeight
                            )
                        }
                        .frame(minHeight: geo.size.height)
                    }

                    OnboardingPrimaryButton(title: "Continue", action: {})
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.bottom, AppTheme.Size.onboardingContinueBottom)
                }
            }
            .ignoresSafeArea()

            // 悬浮滑块控制器
            VStack(spacing: 8) {
                HStack {
                    Text("距 Continue 间距 (heroToCTA):")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(Int(heroToCTA)) pt")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.Color.brandStrong)
                }

                Slider(value: $heroToCTA, in: 80...240, step: 5)
                    .tint(AppTheme.Color.brandStrong)

                HStack(spacing: 8) {
                    quickButton("200pt (main)", value: 200)
                    quickButton("180pt (方案3)", value: 180)
                    quickButton("160pt (方案1)", value: 160)
                    quickButton("110pt (方案4)", value: 110)
                }
            }
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
        }
    }

    private func quickButton(_ title: String, value: CGFloat) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                heroToCTA = value
            }
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(heroToCTA == value ? AppTheme.Color.brandStrong : Color.white.opacity(0.8))
                .foregroundStyle(heroToCTA == value ? Color.white : Color.primary)
                .clipShape(Capsule())
        }
    }
}

// =====================================================================
// MARK: - Xcode Canvas 纯原生 Previews
// =====================================================================

// 1. 方案 1：黄金中偏下 (下沉 40pt · heroToCTA = 160pt · 推荐首选)
#Preview("1. 方案 1 · 黄金中偏下 (下沉 40pt · 推荐)") {
    OnboardingS1ProductionCanvas(option: .option1, showGuides: false)
}

// 2. 方案 3：黄金留白比 (微沉 20pt · heroToCTA = 180pt)
#Preview("2. 方案 3 · 黄金留白比 (微沉 20pt)") {
    OnboardingS1ProductionCanvas(option: .option3, showGuides: false)
}

// 3. main 真实基线 (heroToCTA = 200pt)
#Preview("3. main 真实基线 (heroToCTA = 200pt)") {
    OnboardingS1ProductionCanvas(option: .mainBaseline, showGuides: false)
}

// 4. 方案 4：深底锚海报 (下沉 90pt · heroToCTA = 110pt)
#Preview("4. 方案 4 · 深底锚海报 (下沉 90pt)") {
    OnboardingS1ProductionCanvas(option: .option4, showGuides: false)
}

// 5. 标尺透视：方案 1 带四线标尺
#Preview("5. 标尺透视 · 四档落差标尺线") {
    OnboardingS1ProductionCanvas(option: .option1, showGuides: true)
}

// 6. 并排对比：四机同屏横向滚动检视
#Preview("6. 四机横向并排对比 (一屏同轴)") {
    OnboardingS1MultiPhoneInspectionView()
}

// 7. 交互滑块：现场拖拽滑块感受任意像素位移
#Preview("7. 交互滑块 · 自由拖动下沉位移") {
    OnboardingS1InteractiveSliderView()
}
#endif
