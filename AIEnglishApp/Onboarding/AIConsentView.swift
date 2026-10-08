import SwiftUI

/// AI 数据同意门：首次调用 generate 前弹出，符合 App Review 5.1.2(i) 第三方 AI 披露要求。
struct AIConsentView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("ai_consent_accepted_at") private var aiConsentAt: Double = 0
    @State private var showPrivacy = false

    var onAgree: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题固定在弹窗顶部：靠左对齐，呼吸留白与整体 Sheet 一致
            Text("Before you continue")
                .font(AppTheme.Font.sectionTitleSerif)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.bottom, AppTheme.Space.paddingCard)

            // 文案区可滚：小屏/大字号下文案变长时在弹窗内滚动，按钮始终可见。
            // 弹窗高度固定（AppTheme.Size.consentSheetHeight），正常字号下无感。
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                    Text("This content is generated through Google's Gemini API. We don't collect your real identity or use your data for ads. You can delete all your data anytime in Settings.")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .lineSpacing(AppTheme.Typography.lineBody)

                    Button {
                        showPrivacy = true
                    } label: {
                        Text("Learn more in our Privacy Policy")
                            .font(AppTheme.Font.buddy)
                            // 文字走种子品牌橙 brandStrong（#FF7622）—— PM 明确指定用品牌色。
                            //
                            // ⚠️ 已知代价，非疏漏：#FF7622 对暖纸底（#FBF8F5）约 2.52:1（2026-10-08 重算），达不到 WCAG AA
                            // 对正文的 4.5:1；brandStrong 的 token 注释原文写的是「满饱和图形…永不做文字」，
                            // 橙做文字的合规出口本是 brandInk（#C2410C，对暖纸底 4.89:1）。
                            // 权衡由 PM 拍板：品牌辨识度优先。若日后无障碍审查要换回合规档，
                            // 把此处 brandStrong 改成 brandInk 即可，无其他连带。
                            .foregroundStyle(AppTheme.Color.brandStrong)
                    }
                    .buttonStyle(.iconControl)
                }
            }
            // 理想高度声明为 0：弹窗协商高度时不会把「文案完整高度」算进去，
            // sheet 保持固定高度不撑高；运行时再拿「弹窗总高 - 标题 - 按钮区」的
            // 剩余空间，内容超出时才能滚动。
            .frame(minHeight: 0, idealHeight: 0, maxHeight: .infinity)
            .scrollBounceBehavior(.basedOnSize)

            VStack(spacing: AppTheme.Space.paddingM) {
                Button {
                    aiConsentAt = Date().timeIntervalSince1970
                    dismiss()
                    onAgree?()
                } label: {
                    Text("Agree and continue")
                        .font(AppTheme.Font.ctaLabel)
                        .foregroundStyle(AppTheme.Color.textOnChip)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Space.paddingCard)
                        .background(AppTheme.Color.interactive, in: RoundedRectangle(cornerRadius: AppTheme.Radius.large))
                }

                Button {
                    dismiss()
                } label: {
                    Text("Not now")
                        .font(AppTheme.Font.buddy)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppTheme.Space.paddingS)
                }
            }
        }
        // ⚠️ 不要删：iOS 18+ 会给 sheet 里的 Button 自动加一层灰色圆角底 + 阴影，
        // 三个按钮（Privacy Policy 链接 / Agree / Not now）会各自套上一个系统灰底，
        // 与这套暖纸材质完全不搭。.plain 是关掉它的开关。
        // buttonStyle 走 environment，会向下传染到子树里所有 Button，故挂在最外层一次即可
        // （此前是三个按钮各写一次）。本视图内没有需要系统样式的 Button；
        // 若将来在这里加了需要默认样式的按钮，请在那个按钮上单独覆盖，而不是删掉这一行。
        .buttonStyle(.plain)
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.top, AppTheme.Space.paddingHero)
        .padding(.bottom, AppTheme.Space.paddingPage)
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
        .sheet(isPresented: $showPrivacy) {
            SafariView(url: LegalLinks.privacy)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Presentation Modifier

private struct ConditionalInteractiveDismissDisabled: ViewModifier {
    let disabled: Bool

    func body(content: Content) -> some View {
        if disabled {
            content.interactiveDismissDisabled(true)
        } else {
            content
        }
    }
}

/// AI Consent 弹窗高度档位策略计算（支持单元测试精准验证）
enum AIConsentPresentationDetents {
    static func detents(allowsLarge: Bool) -> Set<PresentationDetent> {
        allowsLarge
            ? [.height(AppTheme.Size.consentSheetHeight), .large]
            : [.height(AppTheme.Size.consentSheetHeight)]
    }
}

extension View {
    /// AI Consent 弹窗的统一呈现修饰符：
    /// - allowsLarge: 为 true 时允许向上拖拽把手展开至 .large（Tab1 场景）；为 false 时锁定单档（Onboarding 场景）。
    /// - isInteractiveDismissDisabled: 仅为 true 时调用 interactiveDismissDisabled，绝不注入 false，
    ///   杜绝 SwiftUI 视图层级中内层 false 覆盖外层 true 的静默失效缺陷。
    func aiConsentSheetPresentation(
        allowsLarge: Bool = false,
        isInteractiveDismissDisabled: Bool = false
    ) -> some View {
        self
            .presentationDetents(AIConsentPresentationDetents.detents(allowsLarge: allowsLarge))
            .presentationDragIndicator(.visible)
            .presentationContentInteraction(.scrolls)
            .modifier(ConditionalInteractiveDismissDisabled(disabled: isInteractiveDismissDisabled))
    }
}

// MARK: - Xcode Canvas Previews

/// Sheet 容器模拟：在 Xcode 静态 Canvas 中直接呈现带顶部横线把手与背景遮罩的视觉效果
private struct AIConsentSheetCanvasPreview: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // 底层页面模拟
            AppTheme.Color.pageBg.ignoresSafeArea()

            // 遮罩
            Color.black.opacity(0.24).ignoresSafeArea()

            // Sheet 主体
            ZStack(alignment: .top) {
                AIConsentView()

                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
            }
            .frame(height: AppTheme.Size.consentSheetHeight)
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
    }
}

/// 交互式预览：在 Xcode Live Preview 中点击按钮即可呼出真实系统 Sheet 观察动效与原生横线
private struct AIConsentInteractivePreview: View {
    @State private var showSheet = true

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack(spacing: 16) {
                Button {
                    showSheet = true
                } label: {
                    Text("Trigger AI Consent Sheet")
                        .font(AppTheme.Font.ctaLabel)
                        .foregroundStyle(AppTheme.Color.textOnChip)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(AppTheme.Color.interactive, in: Capsule())
                }
            }
        }
        .sheet(isPresented: $showSheet) {
            AIConsentView()
                .aiConsentSheetPresentation()
        }
    }
}

#Preview("AI Consent · 真实 Sheet 效果 (含顶部横线)", traits: .fixedLayout(width: 393, height: 852)) {
    AIConsentSheetCanvasPreview()
}

#Preview("AI Consent · 交互式实时弹窗演示 (Xcode Live 预览)") {
    AIConsentInteractivePreview()
}

