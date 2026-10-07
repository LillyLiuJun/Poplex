import SwiftUI

/// Tab2 Hero 卡没有可信照片时的类别预设图（2026-10-04 方案 A「色阶实心」定稿，
/// 设计稿 `design/tab2_preset_12_categories.html`）。
///
/// 构图规则（12 个类别同一套）：
/// - 底：primary300 纯色，无渐变、光晕、阴影
/// - 主物体：右侧一个被画面右 / 下边裁掉的大浅色形（primary100），内部细节只用
///   2pt primary400 线
/// - 细条：左侧固定位置一根 7pt 宽的 primary800 实心细长物，伸出底边
/// - 辅物：一个 primary700 实心小物，放在主物体上
/// - 左上角留空给图上标签（类别名 + 理由，由 `Tab2HeroCard` 在外层叠加）
///
/// 画布高固定 150、左对齐不缩放：设计稿按 361 宽画，更宽的卡片在右侧多露出一点
/// 主物体，更窄的多裁一点，构图不变形。
struct CategoryPresetArtView: View {
    let category: SceneCategory

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(AppTheme.Color.tab2PresetArtBackground))
            PresetArtwork.draw(category, in: context)
        }
        .frame(height: AppTheme.Tab2Hero.Layout.artHeight)
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}

// MARK: - 共享绘制

/// Hero 预设图与 More 行内缩略图（`RowPresetThumb`）共用的唯一绘制入口——
/// 12 张插画只有这里一处真相，缩略图从同一画面裁出，两处永远一致。
///
/// 坐标是插画自身的绘图坐标（同 SVG path 数据），不是界面间距，故留在本文件而非
/// Theme；颜色全部走 `AppTheme.Color.tab2PresetArt*` 语义 token。
enum PresetArtwork {
    static func draw(_ category: SceneCategory, in context: GraphicsContext) {
        let pen = PresetPen(context: context)
        switch category {
        case .food:          drawFood(pen)
        case .workStudy:     drawWorkStudy(pen)
        case .homeFamily:    drawHomeFamily(pen)
        case .dailyRoutines: drawDailyRoutine(pen)
        case .shopping:      drawShopping(pen)
        case .gettingAround: drawTravel(pen)
        case .healthFitness: drawHealth(pen)
        case .leisure:       drawHobbies(pen)
        case .tech:          drawTech(pen)
        case .weather:       drawWeather(pen)
        case .social:        drawSocial(pen)
        case .other:         drawOther(pen)
        }
    }

    // 餐盘 · 叉子 · 勺子
    private static func drawFood(_ pen: PresetPen) {
        pen.circle(262, 102, 90, .surface)
        pen.strokeCircle(262, 102, 64, .detail, width: 2)
        for x in [132.0, 137, 142, 147] {
            pen.rect(x, 40, 3, 26, radius: 1.5, .accent)
        }
        pen.fill(.accent) { p in
            p.move(to: CGPoint(x: 131.5, y: 63))
            p.addLine(to: CGPoint(x: 150.5, y: 63))
            p.addLine(to: CGPoint(x: 150.5, y: 66))
            p.addCurve(to: CGPoint(x: 143.5, y: 80),
                       control1: CGPoint(x: 150.5, y: 75), control2: CGPoint(x: 146.5, y: 79))
            p.addLine(to: CGPoint(x: 138.5, y: 80))
            p.addCurve(to: CGPoint(x: 131.5, y: 66),
                       control1: CGPoint(x: 135.5, y: 79), control2: CGPoint(x: 131.5, y: 75))
            p.closeSubpath()
        }
        pen.rect(137.5, 76, 7, 160, radius: 3.5, .accent)
        pen.rotated(-32, around: CGPoint(x: 268, y: 96)) { pen in
            pen.ellipse(268, 62, 14, 20, .secondary)
            pen.rect(265, 78, 6, 74, radius: 3, .secondary)
        }
    }

    // 横线纸 · 铅笔 · 便利贴
    private static func drawWorkStudy(_ pen: PresetPen) {
        pen.rotated(-6, around: CGPoint(x: 290, y: 110)) { pen in
            pen.rect(192, 30, 200, 200, radius: 6, .surface)
            for y in stride(from: 66.0, through: 146, by: 20) {
                pen.line(from: (214, y), to: (374, y), .detail, width: 2)
            }
        }
        pen.polygon([(137.5, 52), (141, 36), (144.5, 52)], .accent)
        pen.rect(137.5, 54, 7, 180, radius: 1.5, .accent)
        pen.rotated(9, around: CGPoint(x: 259, y: 77)) { pen in
            pen.rect(236, 54, 46, 46, radius: 3, .secondary)
        }
    }

    // 房子 · 钥匙 · 窗
    private static func drawHomeFamily(_ pen: PresetPen) {
        let roof = Path { p in
            p.move(to: CGPoint(x: 180, y: 78))
            p.addLine(to: CGPoint(x: 281, y: 26))
            p.addLine(to: CGPoint(x: 382, y: 78))
            p.closeSubpath()
        }
        pen.fill(roof, .surface)
        pen.stroke(roof, .surface, width: 6, join: .round)
        pen.rect(196, 76, 170, 160, radius: 0, .surface)
        pen.line(from: (196, 79), to: (366, 79), .detail, width: 2)
        pen.stroke(.detail, width: 2) { p in
            p.move(to: CGPoint(x: 222, y: 236))
            p.addLine(to: CGPoint(x: 222, y: 124))
            p.addRelativeArc(center: CGPoint(x: 240, y: 124), radius: 18,
                             startAngle: .degrees(180), delta: .degrees(180))
            p.addLine(to: CGPoint(x: 258, y: 236))
        }
        pen.rect(296, 100, 42, 42, radius: 3, .secondary)
        pen.line(from: (317, 100), to: (317, 142), .surface, width: 3, cap: .butt)
        pen.line(from: (296, 121), to: (338, 121), .surface, width: 3, cap: .butt)
        pen.circle(141, 50, 12, .accent)
        pen.rect(137.5, 58, 7, 180, radius: 0, .accent)
        pen.rect(144, 98, 8, 5, radius: 1, .accent)
        pen.rect(144, 108, 6, 5, radius: 1, .accent)
        pen.circle(141, 48, 4.5, .background)
    }

    // 钟面 · 牙刷 · 指针
    private static func drawDailyRoutine(_ pen: PresetPen) {
        pen.circle(266, 104, 88, .surface)
        pen.line(from: (266, 26), to: (266, 38), .detail, width: 2.5)
        pen.line(from: (344, 104), to: (332, 104), .detail, width: 2.5)
        pen.line(from: (266, 182), to: (266, 170), .detail, width: 2.5)
        pen.line(from: (188, 104), to: (200, 104), .detail, width: 2.5)
        pen.line(from: (266, 104), to: (242, 68), .secondary, width: 9)
        pen.line(from: (266, 104), to: (322, 84), .secondary, width: 6)
        pen.circle(266, 104, 7.5, .secondary)
        pen.rect(137.5, 34, 7, 200, radius: 3.5, .accent)
        for y in [37.0, 42.5, 48, 53.5] {
            pen.rect(144, y, 6, 3, radius: 1, .accent)
        }
    }

    // 购物袋 · 衣架钩 · 价签
    private static func drawShopping(_ pen: PresetPen) {
        pen.rotated(-5, around: CGPoint(x: 280, y: 110)) { pen in
            pen.stroke(.surface, width: 7) { p in
                p.move(to: CGPoint(x: 240, y: 66))
                p.addCurve(to: CGPoint(x: 314, y: 66),
                           control1: CGPoint(x: 240, y: 22), control2: CGPoint(x: 314, y: 22))
            }
            pen.rect(200, 62, 154, 180, radius: 6, .surface)
            pen.line(from: (200, 84), to: (354, 84), .detail, width: 2, cap: .butt)
        }
        pen.rotated(14, around: CGPoint(x: 300, y: 116)) { pen in
            pen.fill(.secondary) { p in
                p.move(to: CGPoint(x: 284, y: 100))
                p.addLine(to: CGPoint(x: 326, y: 100))
                p.addQuadCurve(to: CGPoint(x: 330, y: 104), control: CGPoint(x: 330, y: 100))
                p.addLine(to: CGPoint(x: 330, y: 130))
                p.addQuadCurve(to: CGPoint(x: 326, y: 134), control: CGPoint(x: 330, y: 134))
                p.addLine(to: CGPoint(x: 284, y: 134))
                p.addLine(to: CGPoint(x: 270, y: 117))
                p.closeSubpath()
            }
            pen.circle(284, 117, 3.5, .surface)
        }
        pen.stroke(.accent, width: 4) { p in
            p.move(to: CGPoint(x: 141, y: 60))
            p.addLine(to: CGPoint(x: 141, y: 52))
            p.addCurve(to: CGPoint(x: 150, y: 38),
                       control1: CGPoint(x: 141, y: 48), control2: CGPoint(x: 150, y: 46))
            p.addRelativeArc(center: CGPoint(x: 141, y: 38), radius: 9,
                             startAngle: .degrees(0), delta: .degrees(-180))
        }
        pen.rect(137.5, 58, 7, 180, radius: 2, .accent)
    }

    // 地图 · 路牌 · 定位针
    private static func drawTravel(_ pen: PresetPen) {
        pen.rotated(-6, around: CGPoint(x: 290, y: 110)) { pen in
            pen.rect(196, 36, 190, 200, radius: 4, .surface)
            pen.line(from: (259, 36), to: (259, 236), .detail, width: 2, cap: .butt)
            pen.line(from: (322, 36), to: (322, 236), .detail, width: 2, cap: .butt)
            pen.stroke(.detail, width: 2.5, dash: [6, 6]) { p in
                p.move(to: CGPoint(x: 214, y: 160))
                p.addCurve(to: CGPoint(x: 288, y: 112),
                           control1: CGPoint(x: 240, y: 130), control2: CGPoint(x: 270, y: 146))
                p.addCurve(to: CGPoint(x: 372, y: 70),
                           control1: CGPoint(x: 306, y: 78), control2: CGPoint(x: 330, y: 80))
            }
        }
        pen.fill(.secondary) { p in
            p.move(to: CGPoint(x: 300, y: 108))
            p.addCurve(to: CGPoint(x: 282, y: 76),
                       control1: CGPoint(x: 288, y: 94), control2: CGPoint(x: 282, y: 84))
            p.addRelativeArc(center: CGPoint(x: 300, y: 76), radius: 18,
                             startAngle: .degrees(180), delta: .degrees(180))
            p.addCurve(to: CGPoint(x: 300, y: 108),
                       control1: CGPoint(x: 318, y: 84), control2: CGPoint(x: 312, y: 94))
            p.closeSubpath()
        }
        pen.circle(300, 76, 6, .surface)
        pen.rect(137.5, 50, 7, 190, radius: 0, .accent)
        pen.polygon([(127, 36), (153, 36), (161, 44), (153, 52), (127, 52)], .accent)
    }

    // 瑜伽垫 · 球拍 · 水瓶
    private static func drawHealth(_ pen: PresetPen) {
        pen.rotated(-8, around: CGPoint(x: 290, y: 110)) { pen in
            pen.rect(196, 52, 210, 190, radius: 10, .surface)
            pen.line(from: (214, 74), to: (390, 74), .detail, width: 2)
            pen.line(from: (214, 96), to: (390, 96), .detail, width: 2)
        }
        pen.rotated(12, around: CGPoint(x: 300, y: 110)) { pen in
            pen.rect(287, 88, 28, 60, radius: 8, .secondary)
            pen.rect(293, 77, 16, 13, radius: 2.5, .secondary)
        }
        pen.rect(137.5, 80, 7, 160, radius: 2, .accent)
        pen.polygon([(138, 76), (144, 76), (145.5, 82), (136.5, 82)], .accent)
        pen.stroke(Path(ellipseIn: CGRect(x: 127.5, y: 39, width: 27, height: 38)),
                   .accent, width: 4.5)
    }

    // 翻开的书 · 画笔 · 耳机
    private static func drawHobbies(_ pen: PresetPen) {
        pen.fill(.surface) { p in
            p.move(to: CGPoint(x: 196, y: 70))
            p.addQuadCurve(to: CGPoint(x: 300, y: 72), control: CGPoint(x: 258, y: 52))
            p.addLine(to: CGPoint(x: 300, y: 240))
            p.addLine(to: CGPoint(x: 196, y: 240))
            p.closeSubpath()
        }
        pen.fill(.surface) { p in
            p.move(to: CGPoint(x: 300, y: 72))
            p.addQuadCurve(to: CGPoint(x: 406, y: 70), control: CGPoint(x: 342, y: 52))
            p.addLine(to: CGPoint(x: 406, y: 240))
            p.addLine(to: CGPoint(x: 300, y: 240))
            p.closeSubpath()
        }
        pen.line(from: (300, 72), to: (300, 240), .detail, width: 2)
        pen.line(from: (214, 94), to: (280, 94), .detail, width: 2)
        pen.line(from: (214, 110), to: (280, 110), .detail, width: 2)
        pen.line(from: (214, 126), to: (268, 126), .detail, width: 2)
        pen.line(from: (214, 142), to: (280, 142), .detail, width: 2)
        pen.stroke(.secondary, width: 6) { p in
            p.addRelativeArc(center: CGPoint(x: 348, y: 128), radius: 26,
                             startAngle: .degrees(180), delta: .degrees(180))
        }
        pen.rect(315, 120, 15, 26, radius: 6, .secondary)
        pen.rect(366, 120, 15, 26, radius: 6, .secondary)
        pen.fill(.accent) { p in
            p.move(to: CGPoint(x: 141, y: 30))
            p.addCurve(to: CGPoint(x: 146, y: 54),
                       control1: CGPoint(x: 146, y: 38), control2: CGPoint(x: 147, y: 46))
            p.addLine(to: CGPoint(x: 136, y: 54))
            p.addCurve(to: CGPoint(x: 141, y: 30),
                       control1: CGPoint(x: 135, y: 46), control2: CGPoint(x: 136, y: 38))
            p.closeSubpath()
        }
        pen.rect(136, 55, 10, 12, radius: 1.5, .accent)
        pen.rect(137.5, 66, 7, 180, radius: 2, .accent)
    }

    // 手机 · 数据线 · 通知气泡
    private static func drawTech(_ pen: PresetPen) {
        pen.rotated(8, around: CGPoint(x: 280, y: 110)) { pen in
            pen.rect(220, 34, 122, 230, radius: 22, .surface)
            pen.stroke(Path(roundedRect: CGRect(x: 230, y: 46, width: 102, height: 210),
                            cornerRadius: 14),
                       .detail, width: 2)
            pen.rect(242, 68, 78, 26, radius: 13, .secondary)
            pen.rect(242, 102, 52, 8, radius: 4, .detail)
            pen.rect(242, 118, 64, 8, radius: 4, .detail)
        }
        pen.rect(138, 28, 6, 9, radius: 1, .accent)
        pen.rect(134.5, 36, 13, 24, radius: 3, .accent)
        pen.rect(137.5, 58, 7, 190, radius: 0, .accent)
    }

    // 云 · 雨伞 · 太阳
    private static func drawWeather(_ pen: PresetPen) {
        pen.circle(352, 50, 26, .secondary)
        pen.circle(232, 122, 40, .surface)
        pen.circle(284, 94, 58, .surface)
        pen.circle(344, 116, 44, .surface)
        pen.rect(232, 116, 150, 130, radius: 0, .surface)
        pen.stroke(.detail, width: 2) { p in
            p.move(to: CGPoint(x: 254, y: 116))
            p.addQuadCurve(to: CGPoint(x: 296, y: 84), control: CGPoint(x: 262, y: 84))
        }
        pen.rect(139.5, 26, 3, 8, radius: 1.5, .accent)
        pen.fill(.accent) { p in
            p.move(to: CGPoint(x: 115, y: 58))
            p.addCurve(to: CGPoint(x: 141, y: 32),
                       control1: CGPoint(x: 115, y: 42), control2: CGPoint(x: 127, y: 32))
            p.addCurve(to: CGPoint(x: 167, y: 58),
                       control1: CGPoint(x: 155, y: 32), control2: CGPoint(x: 167, y: 42))
            // 伞沿四段扇贝
            for (from, to) in [(167.0, 154.0), (154, 141), (141, 128), (128, 115)] {
                p.addCurve(to: CGPoint(x: to, y: 58),
                           control1: CGPoint(x: from - 4, y: 54), control2: CGPoint(x: to + 4, y: 54))
            }
            p.closeSubpath()
        }
        pen.rect(137.5, 56, 7, 190, radius: 0, .accent)
    }

    // 对话气泡 · 小花 · 心
    private static func drawSocial(_ pen: PresetPen) {
        pen.rect(200, 30, 200, 106, radius: 34, .surface)
        pen.polygon([(236, 130), (220, 166), (270, 130)], .surface)
        pen.line(from: (228, 62), to: (352, 62), .detail, width: 2)
        pen.line(from: (228, 84), to: (318, 84), .detail, width: 2)
        pen.fill(.secondary) { p in
            p.move(to: CGPoint(x: 346, y: 120))
            p.addCurve(to: CGPoint(x: 324, y: 94),
                       control1: CGPoint(x: 332, y: 110), control2: CGPoint(x: 324, y: 103))
            p.addRelativeArc(center: CGPoint(x: 335, y: 92), radius: 11.18,
                             startAngle: .degrees(169.7), delta: .degrees(180))
            p.addRelativeArc(center: CGPoint(x: 357, y: 92), radius: 11.18,
                             startAngle: .degrees(190.3), delta: .degrees(180))
            p.addCurve(to: CGPoint(x: 346, y: 120),
                       control1: CGPoint(x: 368, y: 103), control2: CGPoint(x: 360, y: 110))
            p.closeSubpath()
        }
        for (x, y) in [(141.0, 35.0), (149.6, 41.2), (146.3, 51.3), (135.7, 51.3), (132.4, 41.2)] {
            pen.circle(x, y, 6.5, .accent)
        }
        pen.rect(137.5, 56, 7, 190, radius: 0, .accent)
        pen.fill(.accent) { p in
            p.move(to: CGPoint(x: 144.5, y: 96))
            p.addCurve(to: CGPoint(x: 165.5, y: 92),
                       control1: CGPoint(x: 153.5, y: 87), control2: CGPoint(x: 162.5, y: 88))
            p.addCurve(to: CGPoint(x: 144.5, y: 99),
                       control1: CGPoint(x: 159.5, y: 99), control2: CGPoint(x: 151.5, y: 101))
            p.closeSubpath()
        }
        pen.circle(141, 44, 3.5, .background)
    }

    // 点阵卡片 · 星光棒 · 星
    private static func drawOther(_ pen: PresetPen) {
        pen.rotated(-7, around: CGPoint(x: 290, y: 110)) { pen in
            pen.rect(200, 38, 190, 200, radius: 18, .surface)
            for x in stride(from: 222.0, to: 382, by: 20) {
                for y in stride(from: 60.0, to: 190, by: 20) {
                    pen.circle(x, y, 1.8, .detail)
                }
            }
        }
        pen.sparkle(300, 88, radius: 24, .secondary)
        pen.rect(137.5, 60, 7, 190, radius: 2, .accent)
        pen.sparkle(141, 44, radius: 14, .accent)
    }
}

// MARK: - 绘制小工具

/// 插画的五种着色角色，各自映射到一个语义 token。
enum PresetInk {
    case background, surface, detail, secondary, accent

    var color: Color {
        switch self {
        case .background: AppTheme.Color.tab2PresetArtBackground
        case .surface:    AppTheme.Color.tab2PresetArtSurface
        case .detail:     AppTheme.Color.tab2PresetArtDetail
        case .secondary:  AppTheme.Color.tab2PresetArtSecondary
        case .accent:     AppTheme.Color.tab2PresetArtAccent
        }
    }
}

/// 对 GraphicsContext 的薄封装：把 SVG 设计稿里的 rect / circle / line / rotate
/// 一一对应成方法，让上面 12 段绘制代码能逐行对照设计稿。
struct PresetPen {
    let context: GraphicsContext

    func fill(_ path: Path, _ ink: PresetInk) {
        context.fill(path, with: .color(ink.color))
    }

    func fill(_ ink: PresetInk, _ build: (inout Path) -> Void) {
        fill(Path(build), ink)
    }

    func stroke(_ path: Path, _ ink: PresetInk, width: CGFloat,
                cap: CGLineCap = .round, join: CGLineJoin = .miter, dash: [CGFloat] = []) {
        context.stroke(path, with: .color(ink.color),
                       style: StrokeStyle(lineWidth: width, lineCap: cap, lineJoin: join, dash: dash))
    }

    func stroke(_ ink: PresetInk, width: CGFloat, dash: [CGFloat] = [], _ build: (inout Path) -> Void) {
        stroke(Path(build), ink, width: width, dash: dash)
    }

    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat, _ ink: PresetInk) {
        fill(Path(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: radius), ink)
    }

    func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ ink: PresetInk) {
        ellipse(cx, cy, r, r, ink)
    }

    func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ ink: PresetInk) {
        fill(Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)), ink)
    }

    func strokeCircle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ ink: PresetInk, width: CGFloat) {
        stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), ink, width: width)
    }

    func line(from a: (CGFloat, CGFloat), to b: (CGFloat, CGFloat), _ ink: PresetInk,
              width: CGFloat, cap: CGLineCap = .round) {
        let path = Path { p in
            p.move(to: CGPoint(x: a.0, y: a.1))
            p.addLine(to: CGPoint(x: b.0, y: b.1))
        }
        stroke(path, ink, width: width, cap: cap)
    }

    func polygon(_ points: [(CGFloat, CGFloat)], _ ink: PresetInk) {
        fill(ink) { p in
            p.addLines(points.map { CGPoint(x: $0.0, y: $0.1) })
            p.closeSubpath()
        }
    }

    /// 四角星：四条凹弧连成，控制点取半径的 1/8 与 1/4（与设计稿一致）。
    func sparkle(_ cx: CGFloat, _ cy: CGFloat, radius r: CGFloat, _ ink: PresetInk) {
        let a = r / 8, b = r / 4
        fill(ink) { p in
            p.move(to: CGPoint(x: cx, y: cy - r))
            p.addCurve(to: CGPoint(x: cx + r, y: cy),
                       control1: CGPoint(x: cx + a, y: cy - b), control2: CGPoint(x: cx + b, y: cy - a))
            p.addCurve(to: CGPoint(x: cx, y: cy + r),
                       control1: CGPoint(x: cx + b, y: cy + a), control2: CGPoint(x: cx + a, y: cy + b))
            p.addCurve(to: CGPoint(x: cx - r, y: cy),
                       control1: CGPoint(x: cx - a, y: cy + b), control2: CGPoint(x: cx - b, y: cy + a))
            p.addCurve(to: CGPoint(x: cx, y: cy - r),
                       control1: CGPoint(x: cx - b, y: cy - a), control2: CGPoint(x: cx - a, y: cy - b))
            p.closeSubpath()
        }
    }

    /// 绕 `center` 旋转 `degrees` 度后绘制（等同 SVG `rotate(a cx cy)`）。
    func rotated(_ degrees: Double, around center: CGPoint, _ draw: (PresetPen) -> Void) {
        var rotatedContext = context
        rotatedContext.translateBy(x: center.x, y: center.y)
        rotatedContext.rotate(by: .degrees(degrees))
        rotatedContext.translateBy(x: -center.x, y: -center.y)
        draw(PresetPen(context: rotatedContext))
    }
}

#if DEBUG
#Preview("Hero preset art · 12 categories") {
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
