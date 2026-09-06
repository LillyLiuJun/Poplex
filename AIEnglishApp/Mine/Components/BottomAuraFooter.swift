import SwiftUI

/// Tab2 列表底部的随动晨曦地平线微光收尾装饰（Bottom Aura Footer）。
///
/// 视觉设计准则：
/// 1. **随动收尾而非全页固定**：作为 Tab2 ScrollView 内容容器的底层背景收尾（`.background(alignment: .bottom)`），
///    随列表滚动，绝对置于卡片图层下方，避免覆盖卡片正文。
/// 2. **单层平滑各向同性**：底层调用共享原语 `WarmAuraGlow()` 等比椭圆压制模型（Circle + scaleEffect），
///    从源头消灭旧版“正圆径向渐变遭扁椭圆硬截断”造成的内外双层光圈假象。
/// 3. **3D 低调静音收束**：下沉为地平线托盘（宽 320、扁平压制高 102、offsetY: 60、峰值 0.11、blur 20），温润托底，不抢上方卡片视线。
struct BottomAuraFooter: View {
    var body: some View {
        WarmAuraGlow()
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
