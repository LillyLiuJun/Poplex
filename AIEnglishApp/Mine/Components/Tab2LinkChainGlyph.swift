import SwiftUI

/// 词条类型图标 · 短语 / 搭配 / 句型：开口链环（自绘，2026-10-06 方案 S1）。
///
/// 为什么不用 SF Symbol `link`：它在 14pt 常规字重下是同组里最大（15.2pt）的一个，两环交叠的
/// 中间一块线条挤在一起，中心区域被线条占满约 37%（放大镜 17%、书本 5%），在一排细线条图标里
/// 显得突兀。降字重（thin 只有同组一半粗）会让笔触风格和其他图标对不上，所以保持线宽、简化图形：
/// 两段开口环对咬，只在中间搭一小段。线宽 1.2pt 与放大镜 / 书本一致；可见尺寸约 13.5pt。
///
/// 坐标是插画自身的绘图坐标（14×14 盒、圆弧已转成三次贝塞尔），不是界面间距，故留在本文件而非
/// Theme；颜色走语义 token。与引语线（`quoteBlock`）一样是自绘图标，不随 Dynamic Type 缩放。
struct Tab2LinkChainGlyph: Shape {
    /// 描边宽（pt，对应 14pt 图标盒）。与放大镜 / 书本的系统笔触同档，勿随意改。
    static let strokeWidth: CGFloat = 1.2

    func path(in rect: CGRect) -> Path {
        var p = Path()
        // 上段
        p.move(to: CGPoint(x: 5.776, y: 7.612))
        p.addCurve(to: CGPoint(x: 8.008, y: 8.832),
                   control1: CGPoint(x: 6.308, y: 8.323), control2: CGPoint(x: 7.123, y: 8.768))
        p.addCurve(to: CGPoint(x: 10.391, y: 7.943),
                   control1: CGPoint(x: 8.894, y: 8.895), control2: CGPoint(x: 9.763, y: 8.571))
        p.addLine(to: CGPoint(x: 12.227, y: 6.107))
        p.addCurve(to: CGPoint(x: 12.190, y: 1.817),
                   control1: CGPoint(x: 13.387, y: 4.906), control2: CGPoint(x: 13.370, y: 2.997))
        p.addCurve(to: CGPoint(x: 7.900, y: 1.780),
                   control1: CGPoint(x: 11.010, y: 0.637), control2: CGPoint(x: 9.101, y: 0.620))
        p.addLine(to: CGPoint(x: 6.847, y: 2.826))
        // 下段
        p.move(to: CGPoint(x: 8.225, y: 6.388))
        p.addCurve(to: CGPoint(x: 5.993, y: 5.169),
                   control1: CGPoint(x: 7.693, y: 5.677), control2: CGPoint(x: 6.878, y: 5.232))
        p.addCurve(to: CGPoint(x: 3.610, y: 6.058),
                   control1: CGPoint(x: 5.107, y: 5.106), control2: CGPoint(x: 4.237, y: 5.430))
        p.addLine(to: CGPoint(x: 1.774, y: 7.894))
        p.addCurve(to: CGPoint(x: 1.811, y: 12.184),
                   control1: CGPoint(x: 0.614, y: 9.095), control2: CGPoint(x: 0.631, y: 11.003))
        p.addCurve(to: CGPoint(x: 6.101, y: 12.221),
                   control1: CGPoint(x: 2.991, y: 13.364), control2: CGPoint(x: 4.900, y: 13.381))
        p.addLine(to: CGPoint(x: 7.147, y: 11.175))
        return p.applying(CGAffineTransform(scaleX: rect.width / 14, y: rect.height / 14))
    }
}

/// 带统一描边样式的链环图标视图（14×14，调用方不用再重复写描边参数）。
struct Tab2LinkChainGlyphView: View {
    var color: Color = AppTheme.Color.textMuted

    var body: some View {
        Tab2LinkChainGlyph()
            .stroke(color, style: StrokeStyle(lineWidth: Tab2LinkChainGlyph.strokeWidth, lineCap: .round, lineJoin: .round))
            .frame(width: AppTheme.Size.entryBadgeGlyph, height: AppTheme.Size.entryBadgeGlyph)
    }
}
