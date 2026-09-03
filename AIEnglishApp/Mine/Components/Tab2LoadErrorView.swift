import SwiftUI
import UIKit

/// Tab2 首次加载失败且没有缓存时的轻量恢复状态。
/// 它是系统反馈，不是页面核心内容：层级必须低于 Tab2 的编辑式空状态与主 CTA。
struct Tab2LoadErrorView: View {
    var topInset: CGFloat = 0
    var isRetrying = false
    let onRetry: () async -> Void

    var body: some View {
        ZStack {
            AppTheme.Color.pageBg.ignoresSafeArea()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                UnavailableContentIllustration()
                    .accessibilityHidden(true)
                    .padding(.bottom, AppTheme.Space.paddingM)

                VStack(spacing: AppTheme.Space.paddingS) {
                    Text("Something went wrong.")
                        .font(AppTheme.Font.feedbackTitleSerif)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text("This page couldn’t load. Try again in a moment.")
                        .font(AppTheme.Font.statusNote)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .multilineTextAlignment(.center)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task { await onRetry() }
                } label: {
                    HStack(spacing: AppTheme.Space.paddingS) {
                        if isRetrying {
                            ProgressView()
                                .tint(AppTheme.Color.textPrimary)
                            Text("Trying again…")
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .imageScale(.small)
                            Text("Try again")
                        }
                    }
                    .font(AppTheme.Font.compactActionLabel)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingSection)
                    .frame(minHeight: AppTheme.Size.barControl)
                    .background(AppTheme.Color.pillNeutralBg)
                    .clipShape(Capsule())
                }
                .buttonStyle(PressableButtonStyle(pressedScale: 0.98, pressedOpacity: 0.82))
                .disabled(isRetrying)
                .accessibilityLabel(isRetrying ? "Trying again" : "Try again")
                .padding(.top, AppTheme.Space.paddingPage)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
            .padding(.top, max(topInset, AppTheme.Size.barControl))
        }
    }
}

/// 一册没有完全摊平的书：封底、书页与轻微错位形成层次，贴合 Library 场景而不使用警告符号。
private struct UnavailableContentIllustration: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.Radius.small, style: .continuous)
                    .fill(AppTheme.Color.feedbackIllustrationBase)
                    .frame(width: width * 0.82, height: height * 0.45)
                    .rotationEffect(.degrees(2))
                    .offset(y: height * 0.10)

                BookPageShape(side: .left)
                    .fill(AppTheme.Color.feedbackIllustrationPage)
                    .frame(width: width * 0.42, height: height * 0.48)
                    .rotationEffect(.degrees(-4), anchor: .bottomTrailing)
                    .offset(x: -width * 0.20, y: height * 0.01)
                    .shadow(
                        color: AppTheme.Shadow.paperLayerColor,
                        radius: AppTheme.Shadow.paperLayerRadius,
                        x: AppTheme.Shadow.paperLayerX,
                        y: AppTheme.Shadow.paperLayerY
                    )

                BookPageShape(side: .right)
                    .fill(AppTheme.Color.feedbackIllustrationTopPage)
                    .frame(width: width * 0.42, height: height * 0.48)
                    .rotationEffect(.degrees(5), anchor: .bottomLeading)
                    .offset(x: width * 0.20, y: -height * 0.02)
                    .shadow(
                        color: AppTheme.Shadow.paperLayerColor,
                        radius: AppTheme.Shadow.paperLayerRadius,
                        x: AppTheme.Shadow.paperLayerX,
                        y: AppTheme.Shadow.paperLayerY
                    )

                Capsule(style: .continuous)
                    .fill(AppTheme.Color.feedbackIllustrationAccent)
                    .frame(width: width * 0.075, height: height * 0.22)
                    .rotationEffect(.degrees(9))
                    .offset(x: width * 0.16, y: height * 0.31)
            }
        }
        .frame(width: AppTheme.Size.feedbackIllustrationSize, height: AppTheme.Size.feedbackIllustrationSize)
    }
}

private struct BookPageShape: Shape {
    enum Side {
        case left
        case right
    }

    let side: Side

    func path(in rect: CGRect) -> Path {
        side == .left ? leftPage(in: rect) : rightPage(in: rect)
    }

    private func leftPage(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.12))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.20),
            control1: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.minY),
            control2: CGPoint(x: rect.minX + rect.width * 0.23, y: rect.minY + rect.height * 0.05)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.minY + rect.height * 0.88),
            control1: CGPoint(x: rect.minX + rect.width * 0.02, y: rect.minY + rect.height * 0.45),
            control2: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.72)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.82),
            control1: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.minY + rect.height * 0.76),
            control2: CGPoint(x: rect.minX + rect.width * 0.73, y: rect.minY + rect.height * 0.77)
        )
        path.closeSubpath()
        return path
    }

    private func rightPage(in rect: CGRect) -> Path {
        let mirrored = leftPage(in: rect)
        return mirrored.applying(
            CGAffineTransform(
                a: -1,
                b: 0,
                c: 0,
                d: 1,
                tx: rect.minX + rect.maxX,
                ty: 0
            )
        )
    }
}

#Preview("Tab2 Load Error · Default") {
    Tab2LoadErrorView { }
}

#Preview("Tab2 Load Error · Retrying") {
    Tab2LoadErrorView(isRetrying: true) { }
}
