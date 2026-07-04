import SwiftUI

struct SceneDetailView: View {
    let material: Material
    var onDelete: (() -> Void)? = nil

    var body: some View {
        if case .scene(let scene) = material.rawContent {
            DetailContent(material: material, scene: scene, onDelete: onDelete)
        }
    }
}

private struct DetailContent: View {
    let material: Material
    let scene: SceneMaterial
    var onDelete: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                // 来源图片（仅图片素材有）；用路径当缓存 key 避免重签 URL 触发重新下载
                if let signedUrl = scene.sourceImageUrl, let imagePath = scene.sourceImagePath {
                    CachedRemoteImage(
                        signedUrl: signedUrl,
                        stableKey: imagePath,
                        placeholder: RoundedRectangle(cornerRadius: AppTheme.Radius.card)
                            .fill(AppTheme.Color.cardBg)
                            .overlay(Image(systemName: "photo").font(.largeTitle).foregroundStyle(AppTheme.Color.textSecondary))
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                }

                // 情境标签 + 时间
                HStack {
                    if let cat = material.sceneCategory {
                        Label(cat, systemImage: "tag")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                    }
                    Spacer()
                    Text(material.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                }

                Divider()

                // 英文 native 表达（主视觉）
                Text(scene.nativeEnglish)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)

                // 中文原文（弱化）
                Text(scene.chineseOriginal)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Color.textSecondary)

                // 重点词组
                if !scene.keyPhrases.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
                        ForEach(scene.keyPhrases, id: \.phrase) { kp in
                            HStack(alignment: .top, spacing: AppTheme.Space.paddingS) {
                                Text(kp.phrase)
                                    .font(.callout.bold())
                                    .foregroundStyle(AppTheme.Color.textAccent)
                                Text(kp.note)
                                    .font(.callout)
                                    .foregroundStyle(AppTheme.Color.textSecondary)
                            }
                        }
                    }
                }

                Divider()

                // 开始练习 CTA（练习模块后续 Slice 接入，此处先占位）
                Button {
                    Analytics.track("practice_button_tapped", properties: ["material_id": material.id.uuidString])
                } label: {
                    Label("Start Practice", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Space.paddingCard)
                        .background(AppTheme.Color.textAccent)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                }
            }
            .padding(AppTheme.Space.paddingPage)
        }
        .navigationTitle("Scene Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Analytics.track("scene_card_tapped", properties: [
                "material_id": material.id.uuidString,
                "scene_category": material.sceneCategory ?? "uncategorized"
            ])
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    onDelete?()
                    dismiss()
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }
}
