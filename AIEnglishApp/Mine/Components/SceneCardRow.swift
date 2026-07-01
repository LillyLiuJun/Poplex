import SwiftUI

// Tab2 场景卡片列表行：英文优先，中文弱化显示
struct SceneCardRow: View {
    let scene: SceneMaterial

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            Text(scene.nativeEnglish)
                .font(.body.bold())
                .foregroundStyle(AppTheme.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(scene.chineseOriginal)
                .font(.footnote)
                .foregroundStyle(AppTheme.Color.textSecondary)

            if !scene.keyPhrases.isEmpty {
                HStack(spacing: AppTheme.Space.paddingXS) {
                    ForEach(scene.keyPhrases.prefix(3), id: \.phrase) { kp in
                        Text(kp.phrase)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, AppTheme.Space.paddingS)
                            .padding(.vertical, 2)
                            .background(AppTheme.Color.textAccent.opacity(0.12))
                            .foregroundStyle(AppTheme.Color.textAccent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }
}
