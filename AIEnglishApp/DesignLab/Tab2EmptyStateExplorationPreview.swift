#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 零素材空状态（Nothing here yet）插画与版式双维重构沙盒
// 🎯 核心进化（回应用户反馈）：
//   1. 文案升级：采用版式 2 的全新精炼文案直接替代旧文案：
//      - 标题：Nothing here yet.
//      - 副标：Your captured moments will gather here as personalized speaking topics.
//   2. 插画 B 暖度升级（保留手账人文感，注入晨曦暖光）：
//      - 方案 B+ (推荐): 晨曦暖阳手账 + 琥珀橙丝带书签 (Warm Sunlit Journal with Amber Ribbon)
//      - 方案 B1: 晨曦双光晕 + 奶油暖纸手账 (Dual Blooms & Cream Parchment)
//      - 方案 B 原版: 现存手账对照 (Original B · 偏冷白)
//      - 方案 A / C: 取景器 / 生活静物对照

struct Tab2EmptyStateExplorationPreviewView: View {
    @State private var selectedLayout: EmptyLayoutOption = .centered
    @State private var selectedIllustration: IllustrationOption = .proposalBWarmSunlit
    @State private var showTopBarShell: Bool = true
    @State private var selectedTab: AppTab = .mine

    enum EmptyLayoutOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case centered    = "版式 2: 黄金律·画廊中心 (推荐)"
        case topAnchored = "版式 1: 顶部锚定·杂志流"
        case framedCard  = "版式 3: 微卡片·画框承载"
        case baseline    = "版式 0: 现状基线对照"
    }

    enum IllustrationOption: String, CaseIterable, Identifiable {
        var id: String { rawValue }
        case proposalBWarmSunlit = "手账 B · 晨曦暖阳 (推荐)"
        case proposalBWarmSunset = "手账 B · 琥珀斜阳 (浓郁)"
        case proposalBWarmSoft   = "手账 B · 柔光日记 (漫散)"
        case proposalBOriginal   = "手账 B 原版 (冷白对照)"
        case baseline            = "线上原版便签 (对照)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶端双维控制台
            dualDimensionControlBar

            Divider().opacity(0.15)

            // 全真手机视口
            ZStack(alignment: .top) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        layoutContent
                    }
                    .padding(.top, showTopBarShell ? 64 : AppTheme.Space.paddingPage)
                    .padding(.bottom, 110)
                }
                .scrollBounceBehavior(.always, axes: .vertical)
                .background(AppTheme.Color.pageBg.ignoresSafeArea())

                // 全真浮动顶栏
                if showTopBarShell {
                    floatingTopBar
                }

                // 常驻沉底 Capture 操作栏
                bottomDockContainer
            }
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    // MARK: - 顶端控制面板

    private var dualDimensionControlBar: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Text("DesignLab")
                        .font(AppTheme.Font.sectionLabel)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.Color.brandTint)
                        .foregroundStyle(AppTheme.Color.brandStrong)
                        .clipShape(Capsule())

                    Text("Nothing here yet 暖度与排版定案沙盒")
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textPrimary)
                }

                Spacer()

                Toggle("模拟顶栏", isOn: $showTopBarShell)
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .labelsHidden()
                Text(showTopBarShell ? "含顶栏" : "纯内容")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }

            // 1. 排版版式切换器
            Picker("排版架构", selection: $selectedLayout) {
                ForEach(EmptyLayoutOption.allCases) { opt in
                    Text(opt.rawValue).tag(opt)
                }
            }
            .pickerStyle(.segmented)

            // 2. 插画暖度风格切换器
            Picker("插画暖度搭配", selection: $selectedIllustration) {
                ForEach(IllustrationOption.allCases) { ill in
                    Text(ill.rawValue).tag(ill)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingS)
        .background(AppTheme.Color.cardBg)
    }

    // MARK: - 动态版式渲染

    @ViewBuilder
    private var layoutContent: some View {
        switch selectedLayout {
        case .centered:
            layout2CenteredView

        case .topAnchored:
            layout1TopAnchoredView

        case .framedCard:
            layout3FramedCardView

        case .baseline:
            layout0BaselineView
        }
    }

    // ─────────────────────────────────────────────────────────────
    // 版式 2: 黄金律·画廊中心聚焦 (采用最新替换文案，纯净克制)
    // ─────────────────────────────────────────────────────────────
    private var layout2CenteredView: some View {
        VStack(alignment: .center, spacing: 0) {
            // 上方 4 份留白 (光学中心上提至 40% 黄金分割点，彻底消除下坠感)
            Spacer(minLength: 46)

            // 1. 居中聚光插画 (搭载温暖手账图元)
            currentIllustrationView
                .padding(.bottom, AppTheme.Space.paddingSection)

            // 2. 居中对称文字系统 (新文案直接替换，零冗余)
            Text("Nothing here yet.")
                .font(AppTheme.Font.pageTitleSerif)
                .tracking(AppTheme.Typography.trackingDisplay)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .multilineTextAlignment(.center)

            Text("Your captured moments will gather here as personalized speaking topics.")
                .font(AppTheme.Font.onboardingLeadSerif)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(AppTheme.Typography.lineBody)
                .multilineTextAlignment(.center)
                .padding(.top, AppTheme.Space.onboardingTitleToLead)
                .frame(maxWidth: 300)

            // 下方 6 份留白 (从容通透，流淌到底部按钮)
            Spacer(minLength: 120)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .frame(minHeight: 580)
    }

    // ─────────────────────────────────────────────────────────────
    // 版式 1: 顶部锚定·杂志扉页流 (同样消费新替换文案)
    // ─────────────────────────────────────────────────────────────
    private var layout1TopAnchoredView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1. 视觉引子
            currentIllustrationView
                .padding(.top, AppTheme.Space.paddingSection)
                .padding(.bottom, AppTheme.Space.titleToContent)

            // 2. 标题区
            Text("Nothing here yet.")
                .font(AppTheme.Font.pageTitleSerif)
                .tracking(AppTheme.Typography.trackingDisplay)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text("Your captured moments will gather here as personalized speaking topics.")
                .font(AppTheme.Font.onboardingLeadSerif)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(AppTheme.Typography.lineBody)
                .padding(.top, AppTheme.Space.onboardingTitleToLead)
                .frame(maxWidth: 320, alignment: .leading)

            // 自然开阔的大留白
            Spacer(minLength: 160)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .frame(minHeight: 580, alignment: .topLeading)
    }

    // ─────────────────────────────────────────────────────────────
    // 版式 3: 微卡片·画框承载
    // ─────────────────────────────────────────────────────────────
    private var layout3FramedCardView: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingSection) {
            Text("Talk about today")
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.top, AppTheme.Space.paddingPage)

            VStack(spacing: 0) {
                ZStack {
                    LinearGradient(
                        colors: [
                            AppTheme.Color.brandTint.opacity(0.35),
                            AppTheme.Color.cardBg
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 140)

                    currentIllustrationView
                }
                .frame(maxWidth: .infinity)
                .clipped()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Nothing here yet.")
                        .font(AppTheme.Font.sectionTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text("Your captured moments will gather here as personalized speaking topics.")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .lineSpacing(AppTheme.Typography.lineBody)
                }
                .padding(AppTheme.Space.paddingCard)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .surfaceCard(cornerRadius: AppTheme.Radius.large)
            .padding(.horizontal, AppTheme.Space.paddingPage)

            Spacer(minLength: 80)
        }
        .frame(minHeight: 580, alignment: .topLeading)
    }

    // ─────────────────────────────────────────────────────────────
    // 版式 0: 现状基线排版 (对照组)
    // ─────────────────────────────────────────────────────────────
    private var layout0BaselineView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            currentIllustrationView
                .padding(.bottom, AppTheme.Space.titleToContent)

            Text("Nothing here yet.")
                .font(AppTheme.Font.pageTitleSerif)
                .tracking(AppTheme.Typography.trackingDisplay)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text("Start with a moment from your day.")
                .font(AppTheme.Font.onboardingLeadSerif)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineSpacing(AppTheme.Typography.lineBody)
                .padding(.top, AppTheme.Space.onboardingTitleToLead)

            Spacer()
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .frame(minHeight: 520, alignment: .topLeading)
    }

    // MARK: - 插画搭配选择器插槽

    @ViewBuilder
    private var currentIllustrationView: some View {
        switch selectedIllustration {
        case .proposalBWarmSunlit:
            EmptyStateProposalBWarmSunlitIllustration()

        case .proposalBWarmSunset:
            EmptyStateProposalBWarmSunsetIllustration()

        case .proposalBWarmSoft:
            EmptyStateProposalBWarmSoftIllustration()

        case .proposalBOriginal:
            EmptyStateProposalBIllustration()

        case .baseline:
            EmptyStateBaselineIllustration()
        }
    }

    // MARK: - 顶栏与底栏

    private var floatingTopBar: some View {
        ZStack {
            TopTabSelector(selectedTab: $selectedTab)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppTheme.Size.topBarSideClearance)

            HStack {
                SettingsMenuButton { }
                    .padding(.leading, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)
                Spacer()
                UsageLimitButton { }
                    .padding(.trailing, AppTheme.Size.topBarSideClearance - AppTheme.Size.barControl)
            }
        }
        .padding(.bottom, AppTheme.Space.paddingS)
        .background {
            TopBarProgressiveMask()
        }
    }

    private var bottomDockContainer: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                Button { } label: {
                    HStack(spacing: AppTheme.Space.paddingS) {
                        Image(systemName: "camera")
                            .font(.system(size: AppTheme.Size.emptyStateCaptureIconGlyph, weight: .regular))
                        Text("Capture something")
                            .font(AppTheme.Font.ctaLabel)
                    }
                    .foregroundStyle(AppTheme.Color.cardBg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .frame(minHeight: AppTheme.Size.inputBarMinHeight)
                    .background(AppTheme.Color.interactive)
                    .clipShape(Capsule())
                    .shadow(
                        color: AppTheme.Color.interactive.opacity(0.25),
                        radius: 10,
                        x: 0,
                        y: 4
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Space.bottomBarActionBottom)
            }
            .padding(.top, AppTheme.Space.paddingS)
            .background {
                VariableBlurBackdrop(extraExtend: 16)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
        }
    }
}

// =====================================================================
// MARK: - 方案 1：手账 B · 晨曦暖阳 (Sunlit Morning · 推荐金牌标准)
// =====================================================================
// 暖度升级核心突破：
//   1. 破界漫射光晕：宽域晨曦三层光场 (150pt/130pt/80pt 阶梯渐变)，彻底告别局促窄光；
//   2. 双层暖纸结构：底层微露暖赭牛皮纸/皮革托底 (-6°)，表层暖阳象牙纸页 (-2°)，厚实温润；
//   3. 品牌琥珀橙丝带：顶端下垂品牌橙燕尾丝带，质感轻盈灵动；
//   4. 焦糖暖墨线迹：手账格线采用温润焦糖棕色，首行点缀晨曦晶莹橙印。

struct EmptyStateProposalBWarmSunlitIllustration: View {
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // 1. 晨曦三层漫射光场 (破界环境暖光)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.Color.brandStrong.opacity(0.38),
                            Color(red: 1.0, green: 0.62, blue: 0.35).opacity(0.18),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 75
                    )
                )
                .frame(width: 150, height: 150)
                .blur(radius: 22)
                .offset(x: 14, y: -6)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.66, blue: 0.27).opacity(0.42),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 15,
                        endRadius: 65
                    )
                )
                .frame(width: 130, height: 130)
                .blur(radius: 16)
                .offset(x: -12, y: 10)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.51, blue: 0.12).opacity(0.48),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 40
                    )
                )
                .frame(width: 80, height: 80)
                .blur(radius: 10)
                .offset(x: 6, y: -10)

            // 2. 双层暖纸结构
            // 底层：暖赭牛皮纸/皮革封面托底 (微旋 -6°)
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.69, blue: 0.48),
                            Color(red: 0.81, green: 0.48, blue: 0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 82)
                .opacity(0.88)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color(red: 0.81, green: 0.48, blue: 0.24).opacity(0.35), lineWidth: 0.8)
                }
                .rotationEffect(.degrees(-6))

            // 表层：暖阳象牙质感纸页 (微旋 -2°)，搭载焦糖暖墨与丝带书签
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 1.0, green: 0.99, blue: 0.97), location: 0.0),
                                .init(color: Color(red: 0.98, green: 0.95, blue: 0.89), location: 0.45),
                                .init(color: Color(red: 0.96, green: 0.90, blue: 0.78), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 82)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                Color(red: 0.88, green: 0.63, blue: 0.39).opacity(0.65),
                                lineWidth: 0.9
                            )
                    }
                    .shadow(
                        color: AppTheme.Color.brandStrong.opacity(0.16),
                        radius: 12,
                        x: 0,
                        y: 6
                    )

                // 焦糖暖墨手写线与橙章
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.Color.brandStrong)
                            .frame(width: 6.8, height: 6.8)
                            .shadow(color: AppTheme.Color.brandStrong.opacity(0.45), radius: 2.5)

                        Capsule()
                            .fill(Color(red: 0.66, green: 0.43, blue: 0.24).opacity(0.50))
                            .frame(width: 36, height: 2.4)
                    }

                    Capsule()
                        .fill(Color(red: 0.66, green: 0.43, blue: 0.24).opacity(0.30))
                        .frame(width: 54, height: 1.8)

                    Capsule()
                        .fill(Color(red: 0.66, green: 0.43, blue: 0.24).opacity(0.22))
                        .frame(width: 42, height: 1.8)

                    Capsule()
                        .fill(Color(red: 0.66, green: 0.43, blue: 0.24).opacity(0.16))
                        .frame(width: 30, height: 1.8)

                    Spacer(minLength: 0)

                    HStack {
                        Spacer()
                        Circle()
                            .stroke(AppTheme.Color.brandStrong.opacity(0.60), lineWidth: 1.0)
                            .frame(width: 11, height: 11)
                            .overlay {
                                Text("P")
                                    .font(.system(size: 6.5, weight: .bold))
                                    .foregroundStyle(AppTheme.Color.brandStrong)
                            }
                    }
                }
                .padding(14)

                // 垂落的品牌橙丝带书签 (Amber Silk Ribbon)
                JournalRibbonShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.Color.brandStrong,
                                Color(red: 0.85, green: 0.31, blue: 0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8.5, height: 34)
                    .offset(x: 58, y: -6)
                    .shadow(color: Color(red: 0.71, green: 0.24, blue: 0.04).opacity(0.38), radius: 3, x: 1, y: 2)
            }
            .frame(width: 88, height: 82)
            .rotationEffect(.degrees(-2))
        }
        .frame(width: 140, height: 104)
        .scaleEffect(scale)
        .accessibilityHidden(true)
    }
}

// =====================================================================
// MARK: - 方案 2：手账 B · 琥珀斜阳 (Golden Sunset · 浓郁金暖高温度)
// =====================================================================

struct EmptyStateProposalBWarmSunsetIllustration: View {
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // 浓郁金琥珀落日光场
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.41, blue: 0.06).opacity(0.45),
                            Color(red: 1.0, green: 0.65, blue: 0.20).opacity(0.20),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .blur(radius: 25)
                .offset(x: 14, y: -6)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.71, blue: 0.20).opacity(0.55),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 15,
                        endRadius: 70
                    )
                )
                .frame(width: 140, height: 140)
                .blur(radius: 18)
                .offset(x: -12, y: 10)

            // 底层浓郁暖赭底页 (微旋 -6°)
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.91, green: 0.61, blue: 0.36),
                            Color(red: 0.73, green: 0.35, blue: 0.11)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 82)
                .opacity(0.95)
                .rotationEffect(.degrees(-6))

            // 暖金麦香纸页 (微旋 -2°)
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 1.0, green: 0.98, blue: 0.95), location: 0.0),
                                .init(color: Color(red: 0.98, green: 0.91, blue: 0.78), location: 0.50),
                                .init(color: Color(red: 0.95, green: 0.84, blue: 0.63), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 82)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(red: 0.91, green: 0.61, blue: 0.36).opacity(0.75), lineWidth: 1.0)
                    }
                    .shadow(color: Color(red: 0.9, green: 0.31, blue: 0.04).opacity(0.22), radius: 14, x: 0, y: 6)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(red: 0.90, green: 0.35, blue: 0.0))
                            .frame(width: 6.8, height: 6.8)

                        Capsule()
                            .fill(Color(red: 0.59, green: 0.33, blue: 0.14).opacity(0.60))
                            .frame(width: 36, height: 2.4)
                    }

                    Capsule()
                        .fill(Color(red: 0.59, green: 0.33, blue: 0.14).opacity(0.38))
                        .frame(width: 54, height: 1.8)

                    Capsule()
                        .fill(Color(red: 0.59, green: 0.33, blue: 0.14).opacity(0.28))
                        .frame(width: 42, height: 1.8)

                    Spacer(minLength: 0)

                    HStack {
                        Spacer()
                        Circle()
                            .stroke(Color(red: 0.90, green: 0.35, blue: 0.0), lineWidth: 1.1)
                            .frame(width: 11, height: 11)
                            .overlay {
                                Text("P")
                                    .font(.system(size: 6.5, weight: .bold))
                                    .foregroundStyle(Color(red: 0.90, green: 0.35, blue: 0.0))
                            }
                    }
                }
                .padding(14)

                JournalRibbonShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.46, blue: 0.13),
                                Color(red: 0.85, green: 0.31, blue: 0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8.5, height: 34)
                    .offset(x: 58, y: -6)
                    .shadow(color: Color(red: 0.75, green: 0.20, blue: 0.0).opacity(0.45), radius: 3, x: 1, y: 2)
            }
            .frame(width: 88, height: 82)
            .rotationEffect(.degrees(-2))
        }
        .frame(width: 140, height: 104)
        .scaleEffect(scale)
        .accessibilityHidden(true)
    }
}

// =====================================================================
// MARK: - 方案 3：手账 B · 柔光日记 (Soft Hearth · 空气感漫射)
// =====================================================================

struct EmptyStateProposalBWarmSoftIllustration: View {
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.Color.brandStrong.opacity(0.28),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 75
                    )
                )
                .frame(width: 150, height: 150)
                .blur(radius: 22)
                .offset(x: 10, y: -4)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.72, blue: 0.37).opacity(0.32),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 15,
                        endRadius: 65
                    )
                )
                .frame(width: 130, height: 130)
                .blur(radius: 16)
                .offset(x: -8, y: 8)

            // 单层象牙纸页
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 1.0, green: 0.99, blue: 0.98), location: 0.0),
                                .init(color: Color(red: 0.98, green: 0.95, blue: 0.89), location: 0.5),
                                .init(color: Color(red: 0.96, green: 0.90, blue: 0.78), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 82)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(red: 0.88, green: 0.69, blue: 0.47).opacity(0.55), lineWidth: 0.8)
                    }
                    .shadow(color: AppTheme.Color.brandStrong.opacity(0.12), radius: 10, x: 0, y: 5)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.Color.brandStrong)
                            .frame(width: 6.5, height: 6.5)

                        Capsule()
                            .fill(Color(red: 0.66, green: 0.43, blue: 0.24).opacity(0.42))
                            .frame(width: 36, height: 2.2)
                    }

                    Capsule()
                        .fill(Color(red: 0.66, green: 0.43, blue: 0.24).opacity(0.25))
                        .frame(width: 54, height: 1.8)

                    Capsule()
                        .fill(Color(red: 0.66, green: 0.43, blue: 0.24).opacity(0.18))
                        .frame(width: 42, height: 1.8)

                    Spacer(minLength: 0)

                    HStack {
                        Spacer()
                        Circle()
                            .stroke(AppTheme.Color.brandStrong.opacity(0.50), lineWidth: 0.9)
                            .frame(width: 10, height: 10)
                            .overlay {
                                Text("P")
                                    .font(.system(size: 6.2, weight: .bold))
                                    .foregroundStyle(AppTheme.Color.brandStrong)
                            }
                    }
                }
                .padding(14)

                JournalRibbonShape()
                    .fill(AppTheme.Color.brandStrong)
                    .frame(width: 8, height: 32)
                    .offset(x: 58, y: -6)
                    .shadow(color: AppTheme.Color.brandStrong.opacity(0.3), radius: 3, x: 1, y: 2)
            }
            .frame(width: 88, height: 82)
            .rotationEffect(.degrees(-2.5))
        }
        .frame(width: 140, height: 104)
        .scaleEffect(scale)
        .accessibilityHidden(true)
    }
}

private struct JournalRibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notch: CGFloat = 4

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

// =====================================================================
// MARK: - 线上现状基线对照 (双纸片便签)
// =====================================================================

struct EmptyStateBaselineIllustration: View {
    var scale: CGFloat = 1.0

    var body: some View {
        EmptyStateIllustration(scale: scale)
    }
}

// =====================================================================
// MARK: - 方案 B 原版：冷白对照
// =====================================================================

struct EmptyStateProposalBIllustration: View {
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: AppTheme.Color.brandTint.opacity(0.35), location: 0.0),
                    .init(color: AppTheme.Color.brandStrong.opacity(0.12), location: 0.45),
                    .init(color: Color.clear, location: 0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: 120, height: 100)
            .blur(radius: 20)
            .offset(x: 10, y: 10)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.Color.cardBg)
                    .frame(width: 86, height: 80)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                AppTheme.Color.cardBorder.opacity(0.85),
                                lineWidth: 0.8
                            )
                    }
                    .shadow(
                        color: Color.black.opacity(0.04),
                        radius: 8,
                        x: 0,
                        y: 4
                    )

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(AppTheme.Color.brandStrong)
                            .frame(width: 6, height: 6)

                        Capsule()
                            .fill(AppTheme.Color.textSecondary.opacity(0.30))
                            .frame(width: 34, height: 2.2)
                    }

                    Capsule()
                        .fill(AppTheme.Color.textSecondary.opacity(0.18))
                        .frame(width: 52, height: 1.8)

                    Capsule()
                        .fill(AppTheme.Color.textSecondary.opacity(0.14))
                        .frame(width: 40, height: 1.8)

                    Spacer(minLength: 0)

                    HStack {
                        Spacer()
                        Circle()
                            .stroke(AppTheme.Color.brandStrong.opacity(0.35), lineWidth: 1.0)
                            .frame(width: 10, height: 10)
                            .overlay {
                                Text("P")
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundStyle(AppTheme.Color.brandStrong)
                            }
                    }
                }
                .padding(14)
            }
            .frame(width: 86, height: 80)
            .rotationEffect(.degrees(-3))
        }
        .frame(width: 124, height: 96)
        .scaleEffect(scale)
        .accessibilityHidden(true)
    }
}

// MARK: - 方案 A / C 插画实现 (保留作为走查对比)

struct EmptyStateProposalAIllustration: View {
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    AppTheme.Color.brandStrong.opacity(0.24),
                    AppTheme.Color.brandTint.opacity(0.12),
                    Color.clear
                ],
                center: .center,
                startRadius: 8,
                endRadius: 55
            )
            .frame(width: 110, height: 110)
            .blur(radius: 12)
            .offset(x: 10, y: -6)

            RadialGradient(
                colors: [
                    AppTheme.Color.brandTint.opacity(0.35),
                    Color.clear
                ],
                center: .center,
                startRadius: 15,
                endRadius: 65
            )
            .frame(width: 130, height: 130)
            .blur(radius: 18)
            .offset(x: -12, y: 10)

            ViewfinderBracketsShape()
                .stroke(
                    AppTheme.Color.textSecondary.opacity(0.70),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 104, height: 80)

            ZStack {
                Circle()
                    .stroke(
                        AppTheme.Color.textSecondary.opacity(0.25),
                        style: StrokeStyle(lineWidth: 0.9, dash: [3, 4])
                    )
                    .frame(width: 48, height: 48)

                Circle()
                    .stroke(
                        AppTheme.Color.textSecondary.opacity(0.45),
                        lineWidth: 1.1
                    )
                    .frame(width: 32, height: 32)

                CrosshairGlyph()
                    .stroke(
                        AppTheme.Color.textSecondary.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.0, lineCap: .round)
                    )
                    .frame(width: 20, height: 20)

                Circle()
                    .fill(AppTheme.Color.brandStrong)
                    .frame(width: 6, height: 6)
                    .shadow(color: AppTheme.Color.brandStrong.opacity(0.4), radius: 3)
            }
        }
        .frame(width: 124, height: 96)
        .scaleEffect(scale)
        .accessibilityHidden(true)
    }
}

private struct ViewfinderBracketsShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let arm: CGFloat = 14
        let r: CGFloat = 5

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + arm))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + arm, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - arm, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + arm))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + arm, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - arm))

        return path
    }
}

private struct CrosshairGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        let gap: CGFloat = 5
        let len: CGFloat = 5

        path.move(to: CGPoint(x: midX, y: midY - gap))
        path.addLine(to: CGPoint(x: midX, y: midY - gap - len))

        path.move(to: CGPoint(x: midX, y: midY + gap))
        path.addLine(to: CGPoint(x: midX, y: midY + gap + len))

        path.move(to: CGPoint(x: midX - gap, y: midY))
        path.addLine(to: CGPoint(x: midX - gap - len, y: midY))

        path.move(to: CGPoint(x: midX + gap, y: midY))
        path.addLine(to: CGPoint(x: midX + gap + len, y: midY))

        return path
    }
}

struct EmptyStateProposalCIllustration: View {
    var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.Color.brandStrong.opacity(0.24),
                            AppTheme.Color.brandTint.opacity(0.10),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 36
                    )
                )
                .frame(width: 72, height: 72)
                .blur(radius: 10)
                .offset(x: -8, y: -4)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.Color.brandTint.opacity(0.35),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 50
                    )
                )
                .frame(width: 90, height: 90)
                .blur(radius: 16)
                .offset(x: 16, y: 12)

            StillLifeCupShape()
                .stroke(
                    AppTheme.Color.textSecondary.opacity(0.80),
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 58, height: 44)
                .offset(y: 8)

            StillLifeSteamShape()
                .stroke(
                    AppTheme.Color.brandStrong.opacity(0.65),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                )
                .frame(width: 18, height: 26)
                .offset(x: -2, y: -24)

            Circle()
                .fill(AppTheme.Color.brandStrong)
                .frame(width: 5, height: 5)
                .offset(x: 22, y: 16)
                .shadow(color: AppTheme.Color.brandStrong.opacity(0.4), radius: 3)
        }
        .frame(width: 124, height: 96)
        .scaleEffect(scale)
        .accessibilityHidden(true)
    }
}

private struct StillLifeCupShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let saucerY = rect.maxY - 2
        path.move(to: CGPoint(x: rect.minX, y: saucerY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - 8, y: saucerY),
            control: CGPoint(x: rect.midX - 4, y: saucerY + 6)
        )

        let cupLeft = rect.minX + 8
        let cupRight = rect.maxX - 16
        let cupTop = rect.minY + 6
        let cupBottom = saucerY - 3

        path.move(to: CGPoint(x: cupLeft, y: cupTop))
        path.addLine(to: CGPoint(x: cupLeft + 2, y: cupBottom - 6))
        path.addQuadCurve(
            to: CGPoint(x: cupRight - 2, y: cupBottom - 6),
            control: CGPoint(x: (cupLeft + cupRight) / 2, y: cupBottom + 2)
        )
        path.addLine(to: CGPoint(x: cupRight, y: cupTop))

        path.addQuadCurve(
            to: CGPoint(x: cupLeft, y: cupTop),
            control: CGPoint(x: (cupLeft + cupRight) / 2, y: cupTop + 4)
        )

        let handleTop = cupTop + 6
        let handleBottom = cupBottom - 8
        path.move(to: CGPoint(x: cupRight - 1, y: handleTop))
        path.addQuadCurve(
            to: CGPoint(x: cupRight - 1, y: handleBottom),
            control: CGPoint(x: rect.maxX + 4, y: (handleTop + handleBottom) / 2)
        )

        return path
    }
}

private struct StillLifeSteamShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX + 4, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX + 6, y: rect.minY + 2),
            control1: CGPoint(x: rect.minX - 4, y: rect.midY + 4),
            control2: CGPoint(x: rect.minX + 12, y: rect.midY - 4)
        )

        path.move(to: CGPoint(x: rect.maxX - 4, y: rect.maxY - 2))
        path.addCurve(
            to: CGPoint(x: rect.maxX - 2, y: rect.minY + 8),
            control1: CGPoint(x: rect.maxX + 2, y: rect.midY + 4),
            control2: CGPoint(x: rect.maxX - 8, y: rect.midY)
        )

        return path
    }
}

// MARK: - SwiftUI Preview

#Preview("Nothing here yet 暖度与排版定案沙盒") {
    Tab2EmptyStateExplorationPreviewView()
}
#endif
