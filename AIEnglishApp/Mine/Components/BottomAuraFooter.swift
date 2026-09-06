import SwiftUI

/// Tab2 列表底部的随动暖光收尾装饰（Bottom Aura Footer）。
///
/// 视觉设计准则（§3.02）：
/// 1. **随动收尾而非全页固定**：作为 Tab2 ScrollView 内容容器的底层背景收尾（`.background(alignment: .bottom)`），
///    随列表滚动，绝对置于卡片图层下方，避免覆盖卡片正文。
/// 2. **B 档收束微光参数**：采用 B 档紧凑参数（`endRadius: 150`, 峰值 `0.17`, `offsetY: 90`, 宽 320、高 170），
///    收进屏宽以内，横向衰减可见，仅在滑到底部时露出一缕晨曦微光作为视觉收束。
/// 3. **非线性长尾渐变**：采用 8 段逼近非线性缓出 stops，防止色阶断层。
struct BottomAuraFooter: View {
    var body: some View {
        WarmAuraGlow(
            stops: Gradient.warmAuraStops(opacities: [0.17, 0.16, 0.15, 0.12, 0.08, 0.05, 0.02, 0.01]),
            endRadius: 150,
            offsetY: 90,
            width: 320,
            height: 170
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
