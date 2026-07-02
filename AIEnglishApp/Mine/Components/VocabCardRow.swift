import SwiftUI

// 词汇本词卡：英文词条为主标题，中文释义弱化显示
struct VocabCardRow: View {
    let vocab: VocabMaterial

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingS) {
                Text(vocab.word)
                    .font(.body.bold())
                Text(vocab.phonetic)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                Text(vocab.pos)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }

            Text(vocab.definition)
                .font(.footnote)
                .foregroundStyle(AppTheme.Color.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(vocab.exampleEn)
                    .font(.footnote.italic())
                Text(vocab.exampleZh)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Color.textSecondary)
            }
        }
        .padding(AppTheme.Space.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.card))
    }
}
