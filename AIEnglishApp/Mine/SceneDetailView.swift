import SwiftUI

struct SceneDetailView: View {
    let material: Material

    var body: some View {
        if case .scene(let scene) = material.rawContent {
            DetailContent(material: material, scene: scene)
        }
    }
}

private struct DetailContent: View {
    let material: Material
    let scene: SceneMaterial

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
                    Label("开始练习", systemImage: "mic.fill")
                        .frame(maxWidth: .infinity)
                        .padding(AppTheme.Space.paddingCard)
                        .background(AppTheme.Color.textAccent)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
                }
            }
            .padding(AppTheme.Space.paddingPage)
        }
        .navigationTitle("场景详情")
        .navigationBarTitleDisplayMode(.inline)
    }
}
