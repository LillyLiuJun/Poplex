import SwiftUI

/// 设置区 sheet 的顶部柔化层：**同色渐隐**，不是模糊。
///
/// 为什么不复用 Tab1 的 `TopBarProgressiveMask`：它用的是 `.ultraThinMaterial`，
/// 而 material 除了模糊还会自带一层偏冷的半透明白。Tab1 那条带子底下是状态栏
/// 和滚动内容，冷调混在一起看不出来；这里底下只有一片平坦的暖纸底
/// （`pageBg`，H 24–30° 的暖灰），模糊一片纯色等于什么都没模糊，
/// **只剩那层冷白盖在暖纸上** —— 于是顶部出现一条比页面更冷、更灰的横带，
/// 边界还正好压在 sheet 顶边上。那就是「硬」的来源：色温断层，不是渐变陡。
///
/// 改用 `pageBg` 自身做渐隐后，颜色与页面完全同源，不存在色差可看；
/// 内容是被"同色纸"盖住而不是被磨毛，顶边自然消失在背景里。
///
/// 曲线也换了：原来是「满浓度平台 → 突然拐弯下降」。人眼对**斜率突变**极其敏感
/// （马赫带效应），那个拐点会被读成一条线，哪怕两侧亮度差很小。
/// 这里用多段逼近的缓出曲线，全程没有平台、没有拐点。
struct SheetTopScrim: View {
    private let base = AppTheme.Color.pageBg

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: base,                location: 0.00), // sheet 顶边：完全不透，内容在这儿彻底消失
                .init(color: base.opacity(0.97),  location: 0.28),
                .init(color: base.opacity(0.88),  location: 0.46),
                .init(color: base.opacity(0.72),  location: 0.60),
                .init(color: base.opacity(0.50),  location: 0.72),
                .init(color: base.opacity(0.29),  location: 0.83),
                .init(color: base.opacity(0.13),  location: 0.92),
                .init(color: base.opacity(0.04),  location: 0.97),
                .init(color: .clear,              location: 1.00), // 落到内容第一行，干净归零
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(.container, edges: .top)
    }
}
