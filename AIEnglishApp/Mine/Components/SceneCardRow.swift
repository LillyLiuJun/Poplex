import SwiftUI

// Tab2 场景卡片列表行：英文优先，中文弱化显示；有来源图片时左侧显示缩略图
// TODO(Realtime): Realtime 推送的新素材 payload 只含 source_image_path，无 source_image_url。
//   实现 Realtime 订阅时，收到带图片路径的素材需单独请求签名 URL，不能复用批量接口的结果。
struct SceneCardRow: View {
    let materialId: UUID
    let scene: SceneMaterial

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Space.paddingCard) {
            if let signedUrl = scene.sourceImageUrl, let imagePath = scene.sourceImagePath {
                // 用 imagePath（稳定值）当缓存 key，而非 signedUrl（每次重签都变）
                CachedRemoteImage(
                    signedUrl: signedUrl,
                    stableKey: imagePath,
                    placeholder: Color(AppTheme.Color.cardBg)
                        .overlay(Image(systemName: "photo").foregroundStyle(AppTheme.Color.textSecondary))
                )
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card / 2))
            }

            VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
                Text(scene.nativeEnglish)
                    .font(.body.bold())
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if !scene.chineseOriginal.isEmpty {
                    Text(scene.chineseOriginal)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }

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
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }
}
