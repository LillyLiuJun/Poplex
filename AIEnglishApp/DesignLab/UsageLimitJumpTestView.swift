#if DEBUG
import SwiftUI

// DEBUG-only：Daily limit 加载态 ↔ 已加载态的布局位移复现页。
// 入口：Settings → Developer → "Daily limit jump test"。
// 内嵌的是**真实的** UsageLimitSheet（不是副本），叠一把每 10pt 一格的刻度尺，
// 点按钮或开 Auto-flip 来回切换，直接看 "/ 5 generations today" 相对刻度尺上下跳多少。
struct UsageLimitJumpTestView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var autoFlip = ProcessInfo.processInfo.arguments.contains("-jumpAutoFlip")
    @State private var flipCount = 0

    private let sheetHeight: CGFloat = 260
    private let rulerStep: CGFloat = 10
    private let rulerMajorEvery = 5

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            header
                .padding(.horizontal, AppTheme.Space.paddingPage)

            Text(isLoading ? "State: LOADING (spinner)" : "State: LOADED (2 / 5)")
                .font(AppTheme.Font.ctaLabel)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .padding(.horizontal, AppTheme.Space.paddingPage)

            ZStack(alignment: .top) {
                Group {
                    if isLoading {
                        UsageLimitSheet(simulateLoading: true)
                    } else {
                        UsageLimitSheet(usedCount: 2, dailyLimit: 5)
                    }
                }
                .id(isLoading)
                ruler
            }
            .frame(height: sheetHeight)
            .clipped()

            flipButton
                .padding(.horizontal, AppTheme.Space.paddingPage)

            Toggle("Auto-flip every 1.2 s", isOn: $autoFlip)
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .tint(AppTheme.Color.interactive)
                .padding(.horizontal, AppTheme.Space.paddingPage)

            Text("Watch the line \"/ 5 generations today\" against the ruler while the state flips. It should stay on the same ruler line; today it drops about 9 pt when LOADED, and the card below it also shifts about 3 pt.")
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppTheme.Space.paddingPage)

            Spacer(minLength: 0)
        }
        .padding(.top, AppTheme.Space.paddingCard)
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
        .task(id: autoFlip) {
            guard autoFlip else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1.2))
                if Task.isCancelled { break }
                isLoading.toggle()
                flipCount += 1
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Daily limit · jump test")
                .font(AppTheme.Font.ctaLabel)
                .foregroundStyle(AppTheme.Color.textPrimary)
            Spacer()
            Button("Close") { dismiss() }
                .font(AppTheme.Font.statusNote)
                .foregroundStyle(AppTheme.Color.interactive)
        }
    }

    private var flipButton: some View {
        Button {
            isLoading.toggle()
            flipCount += 1
        } label: {
            Text(isLoading ? "Tap → switch to LOADED" : "Tap → switch to LOADING")
                .font(AppTheme.Font.ctaLabel)
                .foregroundStyle(AppTheme.Color.cardBg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Space.paddingCard)
                .background(AppTheme.Color.interactive, in: Capsule())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: flipCount)
    }

    /// 每 10pt 一条细线，每 50pt 一条粗线并标数字；叠在真实 sheet 上方，不拦截点击。
    private var ruler: some View {
        let lines = Int(sheetHeight / rulerStep)
        return ZStack(alignment: .topLeading) {
            ForEach(0...lines, id: \.self) { index in
                let y = CGFloat(index) * rulerStep
                let isMajor = index % rulerMajorEvery == 0
                Rectangle()
                    .fill(AppTheme.Color.brandStrong.opacity(isMajor ? 0.55 : 0.22))
                    .frame(height: isMajor ? 1 : 0.5)
                    .offset(y: y)
                if isMajor {
                    Text("\(Int(y))")
                        .font(AppTheme.Font.metaNote)
                        .foregroundStyle(AppTheme.Color.brandStrong)
                        .offset(x: 2, y: y - 12)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
#endif
