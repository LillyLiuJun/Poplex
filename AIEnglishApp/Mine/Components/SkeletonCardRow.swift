import SwiftUI

struct SkeletonCardRow: View {
    @State private var shimmerX: CGFloat = -200

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            // 英文标题：两行，第二行略短
            SkeletonLine(height: 15)
            SkeletonLine(height: 15, widthRatio: 0.65)

            // 中文原文：一行，更细更短
            SkeletonLine(height: 12, widthRatio: 0.5)
                .padding(.top, 2)

            // Key phrase 胶囊
            HStack(spacing: AppTheme.Space.paddingXS) {
                SkeletonPill(width: 76)
                SkeletonPill(width: 60)
            }
            .padding(.top, 4)
        }
        .padding(AppTheme.Space.paddingCard)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .overlay(alignment: .leading) {
            // 从左到右扫过的亮带
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.45), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 120)
                .offset(x: shimmerX)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
        .onAppear {
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                shimmerX = 500
            }
        }
    }
}

private struct SkeletonLine: View {
    let height: CGFloat
    var widthRatio: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: height / 2)
                .fill(Color.primary.opacity(0.1))
                .frame(width: geo.size.width * widthRatio, height: height)
        }
        .frame(height: height)
    }
}

private struct SkeletonPill: View {
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.primary.opacity(0.1))
            .frame(width: width, height: 24)
    }
}
