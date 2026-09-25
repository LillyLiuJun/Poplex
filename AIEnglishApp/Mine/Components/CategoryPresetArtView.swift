import SwiftUI

/// Tab2 Hero 卡没有可信照片时的 B1 预设图（2026-09-22 视觉回归 main 基线 §2.1）：
/// 晨曦暖光渐变底 + 双光晕 + 手绘类别图标 + 橙点。结构、token 名、取值逐字段取自
/// `git show main:AIEnglishApp/Mine/Components/CategoryPresetArtView.swift`，
/// 不转录、不另起名——接口仍是当前分支的形状（只有 `category`，无 main 的
/// `categoryLabel`/`popsText`/`moreCount`：图上标签由 `Tab2HeroCard` 在外层
/// `.overlay` 叠加，不在这个视图内渲染）。
struct CategoryPresetArtView: View {
    let category: SceneCategory

    var body: some View {
        ZStack(alignment: .topLeading) {
            presetBackground
            primaryBloom
            secondaryBloom
            presetIcon
            presetDot
        }
        .frame(height: AppTheme.Tab2Hero.Layout.artHeight)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var presetBackground: some View {
        LinearGradient(
            stops: [
                .init(color: AppTheme.Color.tab2HeroPresetGradientTop, location: 0),
                .init(color: AppTheme.Color.tab2HeroPresetGradientMiddle, location: 0.62),
                .init(color: AppTheme.Color.tab2HeroPresetGradientBottom, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var primaryBloom: some View {
        Ellipse()
            .fill(AppTheme.Color.tab2HeroPresetBloomPrimary)
            .opacity(AppTheme.Tab2Hero.Opacity.presetBloomPrimary)
            .frame(
                width: AppTheme.Tab2Hero.Layout.presetBloomPrimaryWidth,
                height: AppTheme.Tab2Hero.Layout.presetBloomPrimaryHeight
            )
            .blur(radius: AppTheme.Tab2Hero.Layout.presetBloomBlur)
            .offset(
                x: AppTheme.Tab2Hero.Layout.presetBloomPrimaryLeading,
                y: AppTheme.Tab2Hero.Layout.presetBloomPrimaryTop
            )
            .allowsHitTesting(false)
    }

    private var secondaryBloom: some View {
        Ellipse()
            .fill(AppTheme.Color.tab2HeroPresetBloomSecondary)
            .opacity(AppTheme.Tab2Hero.Opacity.presetBloomSecondary)
            .frame(
                width: AppTheme.Tab2Hero.Layout.presetBloomSecondaryWidth,
                height: AppTheme.Tab2Hero.Layout.presetBloomSecondaryHeight
            )
            .blur(radius: AppTheme.Tab2Hero.Layout.presetBloomBlur)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .offset(
                x: -AppTheme.Tab2Hero.Layout.presetBloomSecondaryTrailing,
                y: AppTheme.Tab2Hero.Layout.presetBloomSecondaryTop
            )
            .allowsHitTesting(false)
    }

    private var presetIcon: some View {
        PresetIconStroke(paths: category.tab2HeroPresetPaths)
            .frame(
                width: AppTheme.Tab2Hero.Layout.presetIconSize,
                height: AppTheme.Tab2Hero.Layout.presetIconSize
            )
            .padding(.trailing, AppTheme.Tab2Hero.Layout.presetIconTrailing)
            .padding(.top, AppTheme.Tab2Hero.Layout.presetIconTop)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .accessibilityHidden(true)
    }

    private var presetDot: some View {
        Circle()
            .fill(AppTheme.Color.brandStrong)
            .opacity(AppTheme.Tab2Hero.Opacity.presetDot)
            .frame(
                width: AppTheme.Tab2Hero.Layout.presetDotSize,
                height: AppTheme.Tab2Hero.Layout.presetDotSize
            )
            .offset(
                x: AppTheme.Tab2Hero.Layout.presetDotLeading,
                y: AppTheme.Tab2Hero.Layout.presetDotTop
            )
            .accessibilityHidden(true)
    }
}

private struct PresetIconStroke: View {
    let paths: [Path]

    var body: some View {
        PresetIconShape(paths: paths)
            .stroke(
                AppTheme.Color.tab2HeroPresetIcon.opacity(AppTheme.Tab2Hero.Opacity.presetIcon),
                style: StrokeStyle(
                    lineWidth: AppTheme.Tab2Hero.Layout.presetIconStrokeWidth,
                    lineCap: .round,
                    lineJoin: .round
                )
            )
    }
}

/// 文件级可见：More 行内预设图（RowPresetThumb）复用同一组 path——
/// 12 个图标的 path 只有此处一处真相，行内版绝不复制。
struct PresetIconShape: Shape {
    let paths: [Path]

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        return paths.reduce(into: Path()) { composite, path in
            composite.addPath(path.applying(transform))
        }
    }
}

// MARK: - 分类图标路径（24 × 24 viewBox）

/// 文件级可见：path 真相随 PresetIconShape 一起被 RowPresetThumb 复用。
extension SceneCategory {
    var tab2HeroPresetPaths: [Path] {
        switch self {
        case .homeFamily:
            return [presetPath { path in
                path.move(to: CGPoint(x: 3, y: 10))
                path.addLine(to: CGPoint(x: 12, y: 3))
                path.addLine(to: CGPoint(x: 21, y: 10))
                path.addLine(to: CGPoint(x: 21, y: 21))
                path.addLine(to: CGPoint(x: 3, y: 21))
                path.closeSubpath()
                path.move(to: CGPoint(x: 9, y: 21))
                path.addLine(to: CGPoint(x: 9, y: 13))
                path.addLine(to: CGPoint(x: 15, y: 13))
                path.addLine(to: CGPoint(x: 15, y: 21))
            }]
        case .workStudy:
            return [presetPath { path in
                path.addRoundedRect(
                    in: CGRect(x: 2, y: 7, width: 20, height: 13),
                    cornerSize: CGSize(width: 2, height: 2)
                )
                path.move(to: CGPoint(x: 9, y: 7))
                path.addLine(to: CGPoint(x: 9, y: 5))
                path.addCurve(
                    to: CGPoint(x: 11, y: 3),
                    control1: CGPoint(x: 9, y: 4),
                    control2: CGPoint(x: 10, y: 3)
                )
                path.addLine(to: CGPoint(x: 13, y: 3))
                path.addCurve(
                    to: CGPoint(x: 15, y: 5),
                    control1: CGPoint(x: 14, y: 3),
                    control2: CGPoint(x: 15, y: 4)
                )
                path.addLine(to: CGPoint(x: 15, y: 7))
                path.move(to: CGPoint(x: 2, y: 12))
                path.addLine(to: CGPoint(x: 22, y: 12))
            }]
        case .dailyRoutines:
            return [presetPath { path in
                path.addRoundedRect(
                    in: CGRect(x: 3, y: 9, width: 18, height: 9),
                    cornerSize: CGSize(width: 2, height: 2)
                )
                path.move(to: CGPoint(x: 3, y: 13))
                path.addLine(to: CGPoint(x: 21, y: 13))
                path.move(to: CGPoint(x: 6, y: 9))
                path.addLine(to: CGPoint(x: 6, y: 6))
                path.addLine(to: CGPoint(x: 11, y: 6))
                path.addLine(to: CGPoint(x: 11, y: 9))
                path.move(to: CGPoint(x: 5, y: 18))
                path.addLine(to: CGPoint(x: 5, y: 21))
                path.move(to: CGPoint(x: 19, y: 18))
                path.addLine(to: CGPoint(x: 19, y: 21))
            }]
        case .food:
            return [
                presetPath { path in
                    path.move(to: CGPoint(x: 6, y: 3))
                    path.addLine(to: CGPoint(x: 6, y: 11))
                    path.addCurve(
                        to: CGPoint(x: 10, y: 11),
                        control1: CGPoint(x: 6, y: 14),
                        control2: CGPoint(x: 10, y: 14)
                    )
                    path.addLine(to: CGPoint(x: 10, y: 3))
                    path.move(to: CGPoint(x: 8, y: 11))
                    path.addLine(to: CGPoint(x: 8, y: 21))
                },
                presetPath { path in
                    path.move(to: CGPoint(x: 17, y: 3))
                    path.addCurve(
                        to: CGPoint(x: 15, y: 9),
                        control1: CGPoint(x: 15.5, y: 5),
                        control2: CGPoint(x: 15, y: 7)
                    )
                    path.addCurve(
                        to: CGPoint(x: 19, y: 9),
                        control1: CGPoint(x: 15, y: 11),
                        control2: CGPoint(x: 19, y: 11)
                    )
                    path.addCurve(
                        to: CGPoint(x: 17, y: 3),
                        control1: CGPoint(x: 19, y: 7),
                        control2: CGPoint(x: 18.5, y: 5)
                    )
                    path.addLine(to: CGPoint(x: 17, y: 21))
                },
            ]
        case .shopping:
            return [presetPath { path in
                path.addRoundedRect(
                    in: CGRect(x: 4, y: 8, width: 16, height: 13),
                    cornerSize: CGSize(width: 2, height: 2)
                )
                path.move(to: CGPoint(x: 8, y: 8))
                path.addCurve(
                    to: CGPoint(x: 16, y: 8),
                    control1: CGPoint(x: 8, y: 3),
                    control2: CGPoint(x: 16, y: 3)
                )
                path.move(to: CGPoint(x: 4, y: 12))
                path.addLine(to: CGPoint(x: 20, y: 12))
            }]
        case .gettingAround:
            return [presetPath { path in
                path.addRoundedRect(
                    in: CGRect(x: 4, y: 4, width: 16, height: 13),
                    cornerSize: CGSize(width: 3, height: 3)
                )
                path.move(to: CGPoint(x: 4, y: 11))
                path.addLine(to: CGPoint(x: 20, y: 11))
                path.move(to: CGPoint(x: 8, y: 21))
                path.addLine(to: CGPoint(x: 10, y: 17))
                path.move(to: CGPoint(x: 16, y: 21))
                path.addLine(to: CGPoint(x: 14, y: 17))
                path.move(to: CGPoint(x: 8, y: 8))
                path.addLine(to: CGPoint(x: 10, y: 8))
                path.move(to: CGPoint(x: 14, y: 8))
                path.addLine(to: CGPoint(x: 16, y: 8))
            }]
        case .healthFitness:
            return [presetPath { path in
                path.addEllipse(in: CGRect(x: 9, y: 2, width: 4, height: 4))
                path.move(to: CGPoint(x: 11, y: 7))
                path.addLine(to: CGPoint(x: 8, y: 12))
                path.addLine(to: CGPoint(x: 4, y: 12))
                path.move(to: CGPoint(x: 8, y: 12))
                path.addLine(to: CGPoint(x: 12, y: 14))
                path.addLine(to: CGPoint(x: 16, y: 11))
                path.move(to: CGPoint(x: 12, y: 14))
                path.addLine(to: CGPoint(x: 10, y: 21))
                path.move(to: CGPoint(x: 12, y: 14))
                path.addLine(to: CGPoint(x: 18, y: 21))
            }]
        case .leisure:
            return [presetPath { path in
                path.addRoundedRect(
                    in: CGRect(x: 3, y: 5, width: 18, height: 13),
                    cornerSize: CGSize(width: 2, height: 2)
                )
                path.move(to: CGPoint(x: 8, y: 21))
                path.addLine(to: CGPoint(x: 16, y: 21))
                path.move(to: CGPoint(x: 12, y: 18))
                path.addLine(to: CGPoint(x: 12, y: 21))
            }]
        case .tech:
            return [presetPath { path in
                path.addRoundedRect(
                    in: CGRect(x: 3, y: 4, width: 18, height: 13),
                    cornerSize: CGSize(width: 2, height: 2)
                )
                path.move(to: CGPoint(x: 8, y: 21))
                path.addLine(to: CGPoint(x: 16, y: 21))
                path.move(to: CGPoint(x: 12, y: 17))
                path.addLine(to: CGPoint(x: 12, y: 21))
            }]
        case .weather:
            return [presetPath { path in
                path.addEllipse(in: CGRect(x: 5, y: 4, width: 6, height: 6))
                path.move(to: CGPoint(x: 11, y: 18))
                path.addLine(to: CGPoint(x: 18, y: 18))
                path.addCurve(
                    to: CGPoint(x: 18, y: 11),
                    control1: CGPoint(x: 22, y: 18),
                    control2: CGPoint(x: 22, y: 11)
                )
                path.addCurve(
                    to: CGPoint(x: 10, y: 11),
                    control1: CGPoint(x: 17, y: 8),
                    control2: CGPoint(x: 12, y: 8)
                )
                path.addCurve(
                    to: CGPoint(x: 11, y: 18),
                    control1: CGPoint(x: 6, y: 11),
                    control2: CGPoint(x: 6, y: 18)
                )
            }]
        case .social:
            return [presetPath { path in
                path.addRoundedRect(
                    in: CGRect(x: 3, y: 5, width: 12, height: 10),
                    cornerSize: CGSize(width: 3, height: 3)
                )
                path.move(to: CGPoint(x: 7, y: 15))
                path.addLine(to: CGPoint(x: 6, y: 19))
                path.addLine(to: CGPoint(x: 10, y: 15))
                path.addRoundedRect(
                    in: CGRect(x: 11, y: 9, width: 10, height: 8),
                    cornerSize: CGSize(width: 3, height: 3)
                )
                path.move(to: CGPoint(x: 17, y: 17))
                path.addLine(to: CGPoint(x: 18, y: 20))
            }]
        case .other:
            return [presetPath { path in
                path.addRoundedRect(
                    in: CGRect(x: 4, y: 5, width: 16, height: 14),
                    cornerSize: CGSize(width: 2, height: 2)
                )
                path.move(to: CGPoint(x: 8, y: 10))
                path.addLine(to: CGPoint(x: 16, y: 10))
                path.move(to: CGPoint(x: 8, y: 14))
                path.addLine(to: CGPoint(x: 13, y: 14))
            }]
        }
    }
}

private func presetPath(_ build: (inout Path) -> Void) -> Path {
    var path = Path()
    build(&path)
    return path
}

#if DEBUG
#Preview("Hero preset art · matrix") {
    ScrollView {
        VStack(spacing: AppTheme.Space.paddingPage) {
            ForEach(SceneCategory.allCases, id: \.self) { category in
                CategoryPresetArtView(category: category)
                    .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
            }
        }
        .padding(AppTheme.Space.paddingPage)
    }
    .background(AppTheme.Color.pageBg)
}
#endif
