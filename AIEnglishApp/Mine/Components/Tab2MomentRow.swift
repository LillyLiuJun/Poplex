import SwiftUI

/// Tab2「More to talk about」列表行（§5）。
/// 行状态由数据自行判定，无需外部传参：有 featured → 常规行；
/// 无 featured → 纯查词行（主句位改「词 + 释义」，meta 位写 No moment yet）。
/// 「已聊过」机制已按产品决定删除——所有行一律按未聊过呈现。
struct Tab2MomentRow: View {
    let category: Tab2CategoryData
    let onTap: () -> Void

    private var isWordsOnly: Bool { category.featured == nil }

    var body: some View {
        Button(action: onTap) {
            rowContent
        }
        .buttonStyle(Tab2MomentRowPressStyle())
    }

    // MARK: - 行骨架

    private var rowContent: some View {
        HStack(spacing: 0) {
            // Color.clear 是唯一真正参与 HStack 高度决策的子视图——它对高度没有
            // 主张，永远原样接受被分配到的尺寸。真正的缩略图内容用 .overlay 叠加，
            // overlay 的内容不参与父视图尺寸计算，只是拿到最终尺寸后画上去。
            // 这不是装饰性写法：真机上竖长截图（如 9:19.5 的手机整屏截图）一旦
            // 直接参与布局，CachedRemoteImage 里 Image.resizable().scaledToFill()
            // 在宽度已被锁定、高度未定的中间层会用图片自身长宽比反推出一个远超
            // 文字内容所需的高度，把整行撑高——五行图片长宽比不同，行高就跟着
            // 各不相同（2026-09-01 真机复现）。
            Color.clear
                .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth)
                .overlay(thumbnail)
                .clipped()
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                categoryRow
                mainSlot
                    .padding(.top, AppTheme.Tab2MoreRow.Layout.categoryToSentence)
                // metaRow 内部按 moreCount == 0 自行决定要不要渲染、要不要带
                // sentenceToMeta 的顶部间距——放在这里会让空行也占掉那段 padding。
                metaRow
            }
            // 卡片内边距复用 Space.paddingCard（三稿把它从 12 提到跟这个既有
            // token 同值），不新开一个只值 16 的组件私有 token。
            .padding(.top, AppTheme.Space.paddingCard)
            .padding(.bottom, AppTheme.Space.paddingCard)
            .padding(.leading, AppTheme.Space.paddingCard)
            .padding(.trailing, AppTheme.Space.paddingS)

            arrow
                .padding(.trailing, AppTheme.Space.paddingCard)
        }
        // minHeight，不是 height：默认字号下内容天然就是这个高度，行会稳稳停在
        // 这——多数用户看到的观感等同固定行高。字号调大到内容超出这个下限时，
        // minHeight 自然放行长高，不裁文字；不需要按字号档位另外分支判断。
        .frame(minHeight: AppTheme.Tab2MoreRow.Layout.rowHeight)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Color.warmGlassSurface)
        .compositingGroup()
        .clipShape(.rect(cornerRadius: AppTheme.Radius.medium))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
        }
        .cardShadow()
        .opacity(isWordsOnly ? AppTheme.Tab2MoreRow.Opacity.wordsOnlyRow : 1)
    }

    /// 行上不放引号——引号是 hero 卡的特权（§5.2）。
    private var arrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: AppTheme.Tab2MoreRow.Layout.arrowGlyph, weight: .medium))
            .foregroundStyle(AppTheme.Color.textMuted)
            .accessibilityHidden(true)
    }

    // MARK: - 缩略图

    @ViewBuilder
    private var thumbnail: some View {
        if isWordsOnly {
            RowPresetThumb(category: sceneCategory, variant: .faint)
        } else if let imageUrl = category.featured?.imageUrl, !imageUrl.isEmpty {
            photoThumbnail(url: imageUrl)
        } else {
            RowPresetThumb(category: sceneCategory, variant: .regular)
        }
    }

    private var sceneCategory: SceneCategory {
        SceneCategory.from(category.sceneCategory)
    }

    private func photoThumbnail(url: String) -> some View {
        CachedRemoteImage(
            signedUrl: url,
            stableKey: category.featured?.stableImageKey ?? url,
            placeholder: { placeholder }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .saturation(AppTheme.Tab2MoreRow.ImageTreatment.photoSaturation)
        .overlay(photoTone)
    }

    /// 行内照片调色只有暖橙 multiply 一层（§5.3）——不加 hero 的暖纸 soft-light：
    /// 行内缩略图小，需要更强的暖橙来压住照片，soft-light 提亮反而稀释。
    private var photoTone: some View {
        Rectangle()
            .fill(AppTheme.Color.tab2MoreRowPhotoToneWarm)
            .blendMode(.multiply)
            .opacity(AppTheme.Tab2MoreRow.Opacity.photoToneWarm)
            .allowsHitTesting(false)
    }

    private var placeholder: some View {
        Rectangle().fill(AppTheme.Color.imagePlaceholderBg)
    }

    // MARK: - 分类行

    private var categoryRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // 句首大写而非全大写——有意与 hero 拉开（hero 上同一字段仍全大写），
            // 越靠近推荐位越响，行上退到元数据声部里就该安静下来（§5 二稿）。
            Text(category.englishLabel)
                .font(AppTheme.Font.tab2MoreRowMetadata)
                .foregroundStyle(AppTheme.Color.textMuted)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(PopsLabel.format(category.wordCount))
                .font(AppTheme.Font.tab2MoreRowMetadata)
                .monospacedDigit()
                .foregroundStyle(AppTheme.Color.textMuted)
                .layoutPriority(1)
        }
    }

    // MARK: - 主句区（固定两行高度）

    @ViewBuilder
    private var mainSlot: some View {
        if isWordsOnly {
            wordsLine
        } else {
            sentence
        }
    }

    private var sentence: some View {
        Text(primaryText)
            .font(AppTheme.Font.tab2MoreRowSentence)
            .foregroundStyle(AppTheme.Color.textPrimary)
            .lineLimit(2)
            .truncationMode(.tail)
            // 「行高约 1.45 倍」的设计意图落地成 lineSpacing——SwiftUI 没有行高
            // 倍数，只有加法式 lineSpacing，且不随 Dynamic Type 缩放。
            .lineSpacing(AppTheme.Tab2MoreRow.Typography.sentenceLineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            // minHeight：默认字号下两行（含 lineSpacing）的自然高度，Dynamic Type
            // 放大后两行会更高，槽位要跟着长而不是把第二行切掉。
            .frame(minHeight: AppTheme.Tab2MoreRow.Layout.sentenceSlotHeight, alignment: .topLeading)
    }

    /// 模式判据完全复用 hero（同一个分类下的 featured 语义必须一致）。
    /// mode a 行上显示 user_original（不带引号）。
    private var primaryText: String {
        guard let featured = category.featured else { return "" }
        switch Tab2HeroCard.featuredMode(
            userOriginal: featured.userOriginal,
            inputLang: featured.inputLang,
            hasFeatured: true
        ) {
        case .a:
            return featured.userOriginal ?? ""
        case .b, .c:
            return featured.targetExpression ?? ""
        case .d:
            return ""
        }
    }

    /// 纯查词行：只放 preview_words 前 2 个，词 + 释义以「·」分隔（§5.5）。
    /// 无衬线——衬线是「用户产生的内容」的标记，词表用衬线是形式撒谎。
    private var wordsLine: some View {
        let words = Array(category.previewWords.prefix(2))

        return HStack(alignment: .firstTextBaseline, spacing: AppTheme.Tab2MoreRow.Layout.wordGap) {
            if let first = words.first {
                wordPair(first)
            }
            if words.count > 1 {
                Text("·")
                    .font(AppTheme.Font.tab2MoreRowWordMeaning)
                    .foregroundStyle(AppTheme.Color.neutralFaint)
                wordPair(words[1])
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: AppTheme.Tab2MoreRow.Layout.sentenceSlotHeight, alignment: .topLeading)
    }

    private func wordPair(_ word: Tab2PreviewWord) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Tab2MoreRow.Layout.wordGap) {
            Text(word.displayForm ?? word.lemma)
                .font(AppTheme.Font.tab2MoreRowWord)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
            // 不加 fixedSize(horizontal: true)：行内文字必须可压缩截断，
            // 超长词（如长短语）锁成硬宽度会把整行乃至整页撑宽。

            if let meaning = word.nativeMeaning, !meaning.isEmpty {
                Text(meaning)
                    .font(AppTheme.Font.tab2MoreRowWordMeaning)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    // MARK: - meta 行

    // 只保留 +N moments，不再渲染 scene_detail——两处省略号挤在一行、
    // 被截断的 scene_detail 信息量为零却占满宽度。Hero 卡保留完整的
    // scene_detail · +N more moments 不变，两处信息层数拉开
    // （Hero 六层 / More 三层），More 不再是「缩小版 Hero」。
    @ViewBuilder
    private var metaRow: some View {
        if isWordsOnly {
            Text("No moment yet")
                .font(AppTheme.Font.tab2MoreRowMetadata)
                .foregroundStyle(AppTheme.Color.textMuted)
                .lineLimit(1)
                .padding(.top, AppTheme.Tab2MoreRow.Layout.sentenceToMeta)
        } else {
            let moreCount = max(0, category.momentCount - 1)
            if moreCount > 0 {
                Text("+\(moreCount) more moments")
                    .font(AppTheme.Font.tab2MoreRowMetadata)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .lineLimit(1)
                    .padding(.top, AppTheme.Tab2MoreRow.Layout.sentenceToMeta)
            }
            // moreCount == 0 时整行不渲染（不留空行，卡片自然变矮）——
            // padding 也必须一起省掉，否则空 view 仍会占掉这段 top padding。
        }
    }
}

/// 与 HeroCardPressStyle 同一套按压配方（§5 行的按压反馈与 hero 手感一致）。
private struct Tab2MomentRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AppTheme.Tab2MoreRow.Motion.pressedScale : 1)
            .animation(
                .spring(
                    response: AppTheme.Tab2MoreRow.Motion.pressResponse,
                    dampingFraction: AppTheme.Tab2MoreRow.Motion.pressDamping
                ),
                value: configuration.isPressed
            )
    }
}

#if DEBUG
private extension Tab2CategoryData {
    static func mock(
        category: String,
        wordCount: Int = 41,
        momentCount: Int,
        featured: Tab2FeaturedMoment?,
        previewWords: [Tab2PreviewWord] = []
    ) -> Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: category,
            wordCount: wordCount,
            unlocked: true,
            lastMaterialAt: nil,
            subScenes: [],
            previewWords: previewWords,
            momentCount: momentCount,
            featured: featured,
            heroPhotos: []
        )
    }
}

private func mockFeatured(
    scene: String,
    userOriginal: String?,
    target: String?,
    inputLang: String?,
    image: String? = nil
) -> Tab2FeaturedMoment {
    Tab2FeaturedMoment(
        sceneDetail: scene,
        occurrenceCount: 1,
        materialId: "mock",
        userOriginal: userOriginal,
        targetExpression: target,
        nativeMeaning: nil,
        imageUrl: image,
        inputLang: inputLang,
        sourceDirection: "express",
        sourceGranularity: "sentence",
        createdAt: nil,
        spokenCount: 0
    )
}

/// 目检清单（§5 完成标准）：
/// ① normal · 照片 · 主句短（1 行留白）· meta 三位数 +999 moments 完整未截
/// ② normal · 预设图 · 主句正好两行 · meta 常规（+5 moments）
/// ③ normal · 照片 · 主句超长 → 2 行 + 省略号
/// ④ normal · momentCount == 1（moreCount == 0）→ meta 整行不渲染，卡片自然变矮，
///   不留空行
/// ⑤ wordsOnly · 2 个词 · pops 照常显示
/// ⑥ wordsOnly · 1 个词
/// ⑦ wordsOnly · 0 个词 → 主句位留空，只剩 No moment yet
#Preview("Tab2 Moment Row · visual matrix") {
    ScrollView {
        VStack(spacing: AppTheme.Space.paddingM) {
            // ①
            Tab2MomentRow(
                category: .mock(
                    category: "饮食",
                    momentCount: 1000,
                    featured: mockFeatured(
                        scene: "Cooking dinner for my friends",
                        userOriginal: "Dinner is ready.",
                        target: nil,
                        inputLang: "target",
                        image: "https://picsum.photos/seed/71/400/300"
                    )
                ),
                onTap: {}
            )
            // ②
            Tab2MomentRow(
                category: .mock(
                    category: "工作与学业",
                    momentCount: 6,
                    featured: mockFeatured(
                        scene: "Meetings",
                        userOriginal: nil,
                        target: "I totally blanked when they asked for the timeline.",
                        inputLang: nil
                    )
                ),
                onTap: {}
            )
            // ③
            Tab2MomentRow(
                category: .mock(
                    category: "科技数码",
                    momentCount: 2,
                    featured: mockFeatured(
                        scene: "Tech support",
                        userOriginal: nil,
                        target: "The meeting ran way over because everyone had a different idea about the timeline, and by the time we finished the whiteboard was completely covered in notes and arrows and half-erased diagrams.",
                        inputLang: nil,
                        image: "https://picsum.photos/seed/72/400/300"
                    )
                ),
                onTap: {}
            )
            // ④ momentCount == 1 → moreCount == 0 → meta 整行不渲染
            Tab2MomentRow(
                category: .mock(
                    category: "家庭与人际",
                    momentCount: 1,
                    featured: mockFeatured(
                        scene: "帮妈妈弄手机",
                        userOriginal: nil,
                        target: "I spent an hour showing my mom how to use her phone.",
                        inputLang: nil
                    )
                ),
                onTap: {}
            )
            // ⑤
            Tab2MomentRow(
                category: .mock(
                    category: "科技数码",
                    wordCount: 24,
                    momentCount: 0,
                    featured: nil,
                    previewWords: [
                        Tab2PreviewWord(lemma: "back up", displayForm: "back up", pos: "v.", nativeMeaning: "备份"),
                        Tab2PreviewWord(lemma: "glitch", displayForm: "glitch", pos: "n.", nativeMeaning: "小故障"),
                    ]
                ),
                onTap: {}
            )
            // ⑥
            Tab2MomentRow(
                category: .mock(
                    category: "饮食",
                    wordCount: 8,
                    momentCount: 0,
                    featured: nil,
                    previewWords: [
                        Tab2PreviewWord(lemma: "takeout", displayForm: "takeout", pos: "n.", nativeMeaning: "外卖"),
                    ]
                ),
                onTap: {}
            )
            // ⑦
            Tab2MomentRow(
                category: .mock(
                    category: "运动健康",
                    wordCount: 3,
                    momentCount: 0,
                    featured: nil
                ),
                onTap: {}
            )
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingSection)
    }
    .background(AppTheme.Color.pageBg)
}

/// 两态并排（同一份数据）：确认 wordsOnly 的视觉权重弱于 normal。
#Preview("Tab2 Moment Row · 2 states") {
    VStack(spacing: AppTheme.Space.paddingM) {
        Tab2MomentRow(
            category: .mock(
                category: "科技数码",
                momentCount: 6,
                featured: mockFeatured(
                    scene: "Standup meeting",
                    userOriginal: nil,
                    target: "I totally blanked when they asked for the timeline.",
                    inputLang: nil,
                    image: "https://picsum.photos/seed/74/400/300"
                ),
                previewWords: [
                    Tab2PreviewWord(lemma: "back up", displayForm: "back up", pos: "v.", nativeMeaning: "备份"),
                    Tab2PreviewWord(lemma: "glitch", displayForm: "glitch", pos: "n.", nativeMeaning: "小故障"),
                ]
            ),
            onTap: {}
        )
        Tab2MomentRow(
            category: .mock(
                category: "科技数码",
                momentCount: 0,
                featured: nil,
                previewWords: [
                    Tab2PreviewWord(lemma: "back up", displayForm: "back up", pos: "v.", nativeMeaning: "备份"),
                    Tab2PreviewWord(lemma: "glitch", displayForm: "glitch", pos: "n.", nativeMeaning: "小故障"),
                ]
            ),
            onTap: {}
        )
    }
    .padding(.horizontal, AppTheme.Space.paddingPage)
    .padding(.vertical, AppTheme.Space.paddingSection)
    .background(AppTheme.Color.pageBg)
}
#endif
