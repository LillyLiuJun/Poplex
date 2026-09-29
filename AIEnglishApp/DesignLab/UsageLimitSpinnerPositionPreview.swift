#if DEBUG
import SwiftUI
import UIKit

// =====================================================================
// MARK: - Daily Limit 状态 07 加载菊花微位置精准校准沙箱
// =====================================================================
// 🎯 截图问题精准复盘：
//   从用户截图中可以清晰看到：
//   菊花当前严重下沉！「/ 5 generations today」浮在上面，菊花沉在左下方，
//   两者高低错位、严重脱节。
//
// 🔍 SwiftUI 底层原因揭秘：
//   代码中使用了 HStack(alignment: .firstTextBaseline)。
//   在 SwiftUI 中，对于没有文字的通用视图（如 ProgressView），系统默认的
//   .firstTextBaseline 会直接取其底边 (d[.bottom])！
//   这就导致系统把菊花的「底部」死死钉在文字的基线上，把整个菊花整体往下推沉了！
//
// 💡 本沙箱提供 4 档精准垂直校准微调方案 + 1 个「实时微调滑块」：
//   - 【Baseline】: 当前截图中严重下沉的现状 (对照组)
//   - 【微调 1 · 完美光学对齐 (上提 5.5pt)】: 菊花中心与「/ 5」大写字高中心精确平齐
//   - 【微调 2 · 斜杠中线对齐 (上提 7.0pt)】: 菊花与斜杠「/」的几何重心平齐
//   - 【微调 3 · 占位框包裹对齐 (上提 4.0pt)】: 模拟 Charter 24pt 数字的字框几何中心
//   - 【微调 4 · 纤细微型菊花 (16pt micro · 上提 5.0pt)】: 菊花比例缩小，更加精致轻柔

enum SpinnerAlignOption: String, CaseIterable, Identifiable {
    case baseline = "00 · Baseline: 当前截图中严重下沉 (错位对照)"
    case adjust1  = "01 · 微调 1: 完美光学对齐 (上提 5.5pt · 最推荐)"
    case adjust2  = "02 · 微调 2: 斜杠中线对齐 (上提 7.0pt)"
    case adjust3  = "03 · 微调 3: 24pt数字中线 (上提 4.0pt)"
    case adjust4  = "04 · 微调 4: 纤细微型菊花 (16pt · 上提 5.0pt)"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .baseline: return "Baseline (下沉)"
        case .adjust1:  return "微调 1 (上提 5.5pt)"
        case .adjust2:  return "微调 2 (上提 7.0pt)"
        case .adjust3:  return "微调 3 (上提 4.0pt)"
        case .adjust4:  return "微调 4 (16pt 微型)"
        }
    }

    var yOffset: CGFloat {
        switch self {
        case .baseline: return 0
        case .adjust1:  return -5.5
        case .adjust2:  return -7.0
        case .adjust3:  return -4.0
        case .adjust4:  return -5.0
        }
    }

    var spinnerScale: CGFloat {
        switch self {
        case .adjust4:  return 0.82
        default:        return 1.0
        }
    }

    var description: String {
        switch self {
        case .baseline:
            return "当前版本：由于 SwiftUI firstTextBaseline 取底边，菊花严重挂在文字下方，视觉断层。"
        case .adjust1:
            return "光学对齐：将菊花上提 5.5pt，中心精确落在「/ 5」的主字高水平线上，浑然一体。"
        case .adjust2:
            return "斜杠中线：上提 7.0pt，与斜杠最高点到最低点正中对齐，略微偏高，适合喜欢高重心的排版。"
        case .adjust3:
            return "数字中线：上提 4.0pt，精确落在原来 Charter 24pt 数字的重心地平线上。"
        case .adjust4:
            return "纤巧微型：缩减为 82% 比例 (约 16pt)，上提 5.0pt，字缝透气，极其克制温和。"
        }
    }
}

// =====================================================================
// MARK: - 单卡片精修渲染器
// =====================================================================

struct SpinnerCardCalibratedView: View {
    let option: SpinnerAlignOption
    var customOffset: CGFloat? = nil
    var showAuxiliaryLine: Bool = false // 辅助对齐红线

    private var activeOffset: CGFloat {
        customOffset ?? option.yOffset
    }

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

            // 用量卡片
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .leading) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        // 菊花主体（带精准垂直微调）
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppTheme.Color.textSecondary)
                            .scaleEffect(option.spinnerScale)
                            .frame(width: 22, height: 22)
                            .offset(y: activeOffset)

                        Text("/ 5 generations today")
                            .font(.custom("GothicA1-Light", size: 15, relativeTo: .subheadline))
                            .foregroundStyle(AppTheme.Color.textSecondary)

                        Spacer()
                    }

                    // 辅助视准线（方便看清居中对齐关系）
                    if showAuxiliaryLine {
                        Rectangle()
                            .fill(Color.red.opacity(0.35))
                            .frame(height: 0.5)
                            .offset(y: -1) // 大致字身水平中心
                    }
                }

                // 2.0pt 极薄轨道
                Capsule()
                    .fill(AppTheme.Color.neutralFaint.opacity(0.3))
                    .frame(height: 2.0)
                    .padding(.top, 2)
            }
            .padding(AppTheme.Space.paddingCard)
            .surfaceCard(cornerRadius: AppTheme.Radius.large)

            // 底部注记
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
// MARK: - 实时滑块校准实验室 (可自己手拖 offset 找到最舒服的点)
// =====================================================================

struct UsageLimitSpinnerCalibrationLab: View {
    @State private var selectedOption: SpinnerAlignOption = .adjust1
    @State private var manualOffsetY: CGFloat = -5.5
    @State private var showLine: Bool = false
    @State private var isManualMode: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 顶部档位选择
                VStack(spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SpinnerAlignOption.allCases) { opt in
                                let isSelected = (!isManualMode && selectedOption == opt)
                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        isManualMode = false
                                        selectedOption = opt
                                        manualOffsetY = opt.yOffset
                                    }
                                } label: {
                                    Text(opt.shortTitle)
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

                    // 方案描述
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isManualMode ? "手动微调模式 (yOffset: \(String(format: "%.1f", manualOffsetY))pt)" : selectedOption.rawValue)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(AppTheme.Color.textPrimary)
                            Text(isManualMode ? "拖动下方滑块以 0.5pt 精度精细微移菊花，直到你视觉上最舒服。" : selectedOption.description)
                                .font(.system(size: 11))
                                .foregroundStyle(AppTheme.Color.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)

                    // 手动微调滑条与辅助线开关
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text("垂直位移 Y:")
                                    .font(.system(size: 11, weight: .bold))
                                Text("\(String(format: "%.1f", manualOffsetY)) pt")
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(AppTheme.Color.brandInk)
                            }
                            Slider(value: $manualOffsetY, in: -10...2, step: 0.5)
                                .tint(AppTheme.Color.brandStrong)
                                .onChange(of: manualOffsetY) { _, _ in
                                    isManualMode = true
                                }
                        }

                        Divider().frame(height: 28)

                        Button {
                            showLine.toggle()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: showLine ? "eye.fill" : "eye.slash")
                                    .font(.system(size: 11))
                                Text("辅助红线")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(showLine ? Color.red.opacity(0.12) : AppTheme.Color.cardBg)
                            .foregroundStyle(showLine ? Color.red : AppTheme.Color.textSecondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                }
                .padding(.vertical, 10)
                .background(AppTheme.Color.cardBg)
                .overlay(alignment: .bottom) { Divider() }

                // 画布渲染
                ScrollView {
                    VStack(spacing: 20) {
                        SpinnerCardCalibratedView(
                            option: selectedOption,
                            customOffset: manualOffsetY,
                            showAuxiliaryLine: showLine
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 12, y: 4)
                        .padding(.top, 24)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("菊花位置精准微调实验室")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// =====================================================================
// MARK: - Xcode Canvas #Preview 预设矩阵
// =====================================================================

#Preview("00 · ★ 菊花位置实时微调实验室 (可拖滑块微调)") {
    UsageLimitSpinnerCalibrationLab()
}

#Preview("01 · Baseline: 当前截图中严重下沉 (错位对照)") {
    SpinnerCardCalibratedView(option: .baseline)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("02 · 微调 1: 完美光学对齐 (上提 5.5pt · 最推荐)") {
    SpinnerCardCalibratedView(option: .adjust1)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("03 · 微调 2: 斜杠中线对齐 (上提 7.0pt)") {
    SpinnerCardCalibratedView(option: .adjust2)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("04 · 微调 3: 24pt数字中线 (上提 4.0pt)") {
    SpinnerCardCalibratedView(option: .adjust3)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("05 · 微调 4: 纤细微型菊花 (16pt · 上提 5.0pt)") {
    SpinnerCardCalibratedView(option: .adjust4)
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}

#Preview("06 · 各方案同屏并排横向画廊 (直观高低对比)") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 20) {
            ForEach(SpinnerAlignOption.allCases) { opt in
                VStack(spacing: 8) {
                    Text(opt.shortTitle)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    SpinnerCardCalibratedView(option: opt, showAuxiliaryLine: true)
                        .frame(width: 330, height: 260)

                    Text("yOffset: \(String(format: "%.1f", opt.yOffset)) pt")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(opt == .baseline ? Color.red : Color.secondary)
                }
            }
        }
        .padding(24)
    }
    .background(Color(uiColor: .systemGroupedBackground))
}

#endif
