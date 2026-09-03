import SwiftUI

/// Tab2 列表底部的随动暖光收尾装饰（Bottom Aura Footer）。
///
/// 视觉设计准则（§3.02）：
/// 1. **随动收尾而非全页固定**：作为 Tab2 ScrollView 内容容器的底层背景收尾（`.background(alignment: .bottom)`），
///    随列表滚动，绝对置于卡片图层下方，避免覆盖卡片正文。
/// 2. **克制温润参数**：恢复到克制档参数（`endRadius: 220`, `opacity: 0.22`, `offset: 80`），
///    仅在滑到底部时露出一缕晨曦微光作为视觉收束。
/// 3. **非线性长尾渐变**：采用 8 段逼近非线性缓出 stops，防止色阶断层。
struct BottomAuraFooter: View {
    var body: some View {
        WarmAuraGlow(
            stops: Gradient.warmAuraStops(opacities: [0.22, 0.21, 0.19, 0.16, 0.11, 0.06, 0.03, 0.01]),
            endRadius: 220,
            offsetY: 80
        )
    }
}

#Preview {
    ZStack {
        AppTheme.Color.pageBg.ignoresSafeArea()
        VStack {
            Spacer()
            BottomAuraFooter()
        }
    }
}
