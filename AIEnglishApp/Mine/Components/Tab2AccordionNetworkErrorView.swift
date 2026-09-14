import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// =====================================================================
// Tab2 手风琴网络失败态视图 (Topics In Progress 展开离线断网错误状态)
// 视觉定案：双重偏心光域 · 珊瑚双重云雾 (Tab2CoralDuoAuraWifiIllustration)
// =====================================================================

public struct Tab2AccordionNetworkErrorView: View {
    public var message: String
    public var onRetry: () -> Void

    public init(
        message: String = "Check your connection and try again.",
        onRetry: @escaping () -> Void
    ) {
        self.message = message
        self.onRetry = onRetry
    }

    private func triggerLightHaptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    public var body: some View {
        VStack(spacing: AppTheme.Space.paddingM) { // 12pt
            // 1. 顶部插画：双重偏心光域 · 珊瑚双重云雾 (76pt 饱满体量)
            Tab2CoralDuoAuraWifiIllustration(size: 76)
                .padding(.top, 4)

            // 2. 说明文案：居中弱提示
            Text(message)
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .multilineTextAlignment(.center)

            // 3. 错误态重试按钮：无底框 · danger 错误红 · ↻ Try again
            Button {
                triggerLightHaptic()
                onRetry()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: AppTheme.Size.inlineActionIconGlyph, weight: .semibold))

                    Text("Try again")
                        .font(AppTheme.Font.inlineActionLabel)
                }
                .foregroundStyle(AppTheme.Color.danger)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, AppTheme.Space.paddingPage) // 20pt
    }
}

// MARK: - 珊瑚双重云雾插画 (Tab2CoralDuoAuraWifiIllustration)

public struct Tab2CoralDuoAuraWifiIllustration: View {
    public var size: CGFloat

    private var terracottaBase: Color { AppTheme.Color.feedbackIllustrationBase }
    private var terracottaPage: Color { AppTheme.Color.feedbackIllustrationPage }
    private var terracottaTopPage: Color { AppTheme.Color.feedbackIllustrationTopPage }
    private var terracottaAccent: Color { AppTheme.Color.feedbackIllustrationAccent }

    public init(size: CGFloat = 76) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            // 1. 双重偏心暖陶土柔光域 (无界漫反射消融，零硬框零写实底板)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            terracottaBase.opacity(0.75),
                            terracottaPage.opacity(0.40),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.46
                    )
                )
                .frame(width: size * 0.92, height: size * 0.92)
                .offset(y: size * 0.02)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            terracottaAccent.opacity(0.40),
                            .clear
                        ],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: size * 0.35
                    )
                )
                .frame(width: size * 0.70, height: size * 0.70)
                .offset(x: size * 0.06, y: -size * 0.05)

            // 2. 规整三阶同心信号弧 (由粗到细、由深到浅微退晕)
            Tab2ConcentricWifiArcShape(radius: size * 0.44, angleSpan: 92, originYRatio: 0.20)
                .stroke(
                    terracottaAccent.opacity(0.95),
                    style: StrokeStyle(lineWidth: 4.8, lineCap: .round)
                )
                .shadow(
                    color: AppTheme.Shadow.paperLayerColor,
                    radius: 3.5,
                    x: 0,
                    y: 2.0
                )

            Tab2ConcentricWifiArcShape(radius: size * 0.28, angleSpan: 84, originYRatio: 0.20)
                .stroke(
                    terracottaBase.opacity(0.85),
                    style: StrokeStyle(lineWidth: 4.2, lineCap: .round)
                )

            Tab2ConcentricWifiArcShape(radius: size * 0.16, angleSpan: 76, originYRatio: 0.20)
                .stroke(
                    terracottaTopPage,
                    style: StrokeStyle(lineWidth: 3.8, lineCap: .round)
                )

            // 3. 发射纽扣 (暖白受光盘 + 维度六同款珊瑚红点)
            ZStack {
                Circle()
                    .fill(terracottaTopPage)
                    .frame(width: size * 0.12, height: size * 0.12)
                    .shadow(
                        color: AppTheme.Shadow.paperLayerColor,
                        radius: 2.0,
                        x: 0,
                        y: 1.0
                    )

                Circle()
                    .fill(terracottaAccent)
                    .frame(width: size * 0.065, height: size * 0.065)
            }
            .offset(y: size * 0.20)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 同心信号弧 Shape (Tab2ConcentricWifiArcShape)

public struct Tab2ConcentricWifiArcShape: Shape {
    public let radius: CGFloat
    public var angleSpan: Double
    public var originYRatio: CGFloat

    public init(radius: CGFloat, angleSpan: Double = 90.0, originYRatio: CGFloat = 0.20) {
        self.radius = radius
        self.angleSpan = angleSpan
        self.originYRatio = originYRatio
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY + rect.height * originYRatio)
        let startAngle = 270.0 - angleSpan / 2.0
        let endAngle = 270.0 + angleSpan / 2.0
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(endAngle),
            clockwise: false
        )
        return path
    }
}

// MARK: - Preview

#Preview("Tab2 Accordion Network Error · Outdoor Life") {
    VStack(spacing: AppTheme.Space.paddingPage) {
        Tab2AccordionNetworkErrorView(
            message: "Check your connection and try again."
        ) {
            print("Retry clicked")
        }
    }
    .background(AppTheme.Color.cardBg)
    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium, style: .continuous))
    .padding()
    .background(AppTheme.Color.pageBg)
}
