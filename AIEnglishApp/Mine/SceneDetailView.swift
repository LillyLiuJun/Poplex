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
                    // TODO: connect practice module
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
