import SwiftUI

/// Tab2 已解锁分类的唯一 Hero 卡：顶部呈现与 featured 同源的照片或预设图，底部呈现一条可开口的话题。
struct Tab2HeroCard: View {
    let category: Tab2CategoryData
    let onTalk: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private var moreCount: Int { max(0, category.momentCount - 1) }

    var body: some View {
        Button(action: onTalk) {
            cardContent
        }
        .buttonStyle(HeroCardPressStyle())
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            topArt
            bottomContent
                .offset(y: AppTheme.Tab2Hero.Layout.artTextOverlap)
                .padding(.bottom, AppTheme.Tab2Hero.Layout.artTextOverlap)
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.Color.warmGlassSurface)
        .compositingGroup()
        .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
        .shadow(
            color: AppTheme.Shadow.cardColor,
            radius: AppTheme.Tab2Hero.Layout.cardShadowRadius,
            x: 0,
            y: AppTheme.Tab2Hero.Layout.cardShadowY
        )
    }

    // MARK: - 顶部图像（featured 无图时不能借用分类的其他照片，避免图文错配）

    @ViewBuilder
    private var topArt: some View {
        let label = category.englishLabel
        let pops = PopsLabel.format(category.wordCount)

        if category.heroPhotos.isEmpty || category.featured?.imageUrl == nil {
            CategoryPresetArtView(
                category: sceneCategory,
                categoryLabel: label,
                popsText: pops,
                moreCount: moreCount
            )
        } else {
            HeroCollageView(
                photos: category.heroPhotos,
                categoryLabel: label,
                popsText: pops
            )
        }
    }

    // MARK: - 文字区

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let featured = category.featured {
                featuredContent(featured)
            } else {
                fallbackWords
            }

            Spacer(minLength: AppTheme.Space.paddingM)

            HStack {
                Spacer(minLength: 0)
                ctaPill
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingCard)
        .padding(.bottom, AppTheme.Space.paddingCard)
        .frame(
            minHeight: AppTheme.Tab2Hero.Layout.textMinimumHeight,
            alignment: .topLeading
        )
    }

    @ViewBuilder
    private func featuredContent(_ featured: Tab2FeaturedMoment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(primaryText(for: featured))
                .font(AppTheme.Font.cardSentence)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let footnote = footnoteText(for: featured), !footnote.isEmpty {
                Text(footnote)
                    .font(AppTheme.Font.chineseFaint)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppTheme.Space.paddingS)
            }

            metaRow(for: featured)
                .padding(.top, AppTheme.Space.paddingXS)
        }
    }

    @ViewBuilder
    private func metaRow(for featured: Tab2FeaturedMoment) -> some View {
        let sceneDetail = Self.validatedTargetSceneDetail(featured.sceneDetail)

        if sceneDetail != nil || moreCount > 0 {
            HStack(spacing: AppTheme.Tab2Hero.Layout.metaContentGap) {
                if let sceneDetail {
                    Text(sceneDetail)
                        .font(AppTheme.Font.tab2HeroMeta)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(
                            maxWidth: AppTheme.Tab2Hero.Layout.sceneDetailMaximumWidth,
                            alignment: .leading
                        )
                        // 外层按自身理想宽度参与 HStack；短标签不再预占 175pt，
                        // 长标签仍由上面的 maxWidth 截到规格上限。
                        .fixedSize(horizontal: true, vertical: false)
                }

                if sceneDetail != nil && moreCount > 0 {
                    Text("·")
                        .font(AppTheme.Font.tab2HeroMeta)
                        .foregroundStyle(AppTheme.Color.neutralFaint)
                }

                if moreCount > 0 {
                    Text("+\(moreCount) more moments")
                        .font(AppTheme.Font.tab2HeroMeta)
                        .foregroundStyle(AppTheme.Color.neutralFaint)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func primaryText(for featured: Tab2FeaturedMoment) -> String {
        switch mode(featured) {
        case .a:
            return "\u{201C}\(featured.userOriginal ?? "")\u{201D}"
        case .b, .c:
            return featured.targetExpression ?? ""
        case .d:
            return ""
        }
    }

    private func footnoteText(for featured: Tab2FeaturedMoment) -> String? {
        switch mode(featured) {
        case .a, .c:
            return featured.nativeMeaning
        case .b:
            return featured.userOriginal
        case .d:
            return nil
        }
    }

    // MARK: - 模式 D：最近入账的三个词

    @ViewBuilder
    private var fallbackWords: some View {
        let words = Array(category.previewWords.prefix(3))

        if !words.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(words.indices, id: \.self) { index in
                    Tab2HeroPreviewWordRow(word: words[index])
                        .frame(height: AppTheme.Tab2Hero.Layout.wordRowHeight)
                }
            }
        }
    }

    private var ctaPill: some View {
        HStack(spacing: AppTheme.Tab2Hero.Layout.ctaContentGap) {
            Text("Start talking")
            Image(systemName: "arrow.right")
                .imageScale(.small)
        }
        .font(AppTheme.Font.tab2HeroCTA)
        .foregroundStyle(AppTheme.Color.tab2HeroCTAOnColor)
        .padding(.horizontal, AppTheme.Tab2Hero.Layout.ctaHorizontalInset)
        .frame(height: AppTheme.Tab2Hero.Layout.ctaHeight)
        .background(
            AppTheme.Color.textPrimary,
            in: RoundedRectangle(
                cornerRadius: AppTheme.Tab2Hero.Layout.ctaCornerRadius,
                style: .continuous
            )
        )
    }

    // MARK: - 模式判据（沿用既有 (user_original, input_lang) 规则）

    enum FeaturedMode { case a, b, c, d }

    static func featuredMode(userOriginal: String?, inputLang: String?, hasFeatured: Bool) -> FeaturedMode {
        guard hasFeatured else { return .d }
        if let original = userOriginal, !original.isEmpty {
            return inputLang == "target" ? .a : .b
        }
        return .c
    }

    private func mode(_ featured: Tab2FeaturedMoment) -> FeaturedMode {
        Self.featuredMode(
            userOriginal: featured.userOriginal,
            inputLang: featured.inputLang,
            hasFeatured: true
        )
    }

    /// 与当前 English-as-target 配置绑定；未来允许更换目标语言时，只需替换这一处脚本校验。
    private nonisolated static func validatedTargetSceneDetail(_ candidate: String) -> String? {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.unicodeScalars.first,
              isASCIILetter(first),
              trimmed.unicodeScalars.allSatisfy(isValidTargetSceneDetailScalar)
        else {
            return nil
        }
        return trimmed
    }

    private nonisolated static func isValidTargetSceneDetailScalar(_ scalar: UnicodeScalar) -> Bool {
        isASCIILetter(scalar)
            || scalar.properties.isWhitespace
            || scalar == "'"
            || scalar == "-"
    }

    private nonisolated static func isASCIILetter(_ scalar: UnicodeScalar) -> Bool {
        (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
    }
}

private struct Tab2HeroPreviewWordRow: View {
    let word: Tab2PreviewWord

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Tab2Hero.Layout.wordRowGap) {
            Text(word.displayForm ?? word.lemma)
                .font(AppTheme.Font.tab2HeroWord)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .lineLimit(1)

            Text(word.pos ?? "")
                .font(AppTheme.Font.tab2HeroWordPartOfSpeech)
                .foregroundStyle(AppTheme.Color.neutralFaint)
                .lineLimit(1)

            Text(word.nativeMeaning ?? "")
                .font(AppTheme.Font.tab2HeroWordMeaning)
                .foregroundStyle(AppTheme.Color.textMuted)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct HeroCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AppTheme.Tab2Hero.Motion.pressedScale : 1)
            .animation(
                .spring(
                    response: AppTheme.Tab2Hero.Motion.pressResponse,
                    dampingFraction: AppTheme.Tab2Hero.Motion.pressDamping
                ),
                value: configuration.isPressed
            )
    }
}

#if DEBUG
private extension Tab2CategoryData {
    static func mock(
        category: String,
        featured: Tab2FeaturedMoment?,
        heroPhotos: [Tab2HeroPhoto],
        momentCount: Int,
        previewWords: [Tab2PreviewWord] = []
    ) -> Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: category,
            wordCount: 42,
            unlocked: true,
            lastMaterialAt: Date(),
            subScenes: [],
            previewWords: previewWords,
            momentCount: momentCount,
            featured: featured,
            heroPhotos: heroPhotos
        )
    }
}

private func mockPhoto(_ seed: Int, featured: Bool = false) -> Tab2HeroPhoto {
    Tab2HeroPhoto(
        materialId: "m\(seed)",
        imageUrl: "https://picsum.photos/seed/\(seed)/400/300",
        isFeatured: featured
    )
}

private func mockFeatured(
    scene: String,
    userOriginal: String?,
    target: String?,
    native: String?,
    inputLang: String?,
    image: String? = nil,
    occ: Int = 1
) -> Tab2FeaturedMoment {
    Tab2FeaturedMoment(
        sceneDetail: scene,
        occurrenceCount: occ,
        materialId: "mf",
        userOriginal: userOriginal,
        targetExpression: target,
        nativeMeaning: native,
        imageUrl: image,
        inputLang: inputLang,
        sourceDirection: "express",
        sourceGranularity: "sentence",
        createdAt: Date(),
        spokenCount: 0
    )
}

#Preview("Tab2 Hero · visual matrix") {
    ScrollView {
        VStack(spacing: AppTheme.Space.paddingPage) {
            // A · 3 张拼图 · 短主句 / 单行母语
            Tab2HeroCard(category: .mock(
                category: "饮食",
                featured: mockFeatured(
                    scene: "Cooking dinner",
                    userOriginal: "Dinner is ready.",
                    target: nil,
                    native: "晚饭做好了。",
                    inputLang: "target",
                    image: "https://picsum.photos/seed/11/400/300"
                ),
                heroPhotos: [mockPhoto(11, featured: true), mockPhoto(12), mockPhoto(13)],
                momentCount: 4
            ), onTalk: {})

            // B · 2 张拼图 · 两行主句 / 两行母语
            Tab2HeroCard(category: .mock(
                category: "工作与学业",
                featured: mockFeatured(
                    scene: "Standup meeting",
                    userOriginal: "他们问我时间线时我大脑一片空白，完全不知道该怎么回答。",
                    target: "I totally blanked when they asked me for the timeline in the standup meeting.",
                    native: nil,
                    inputLang: "native",
                    image: "https://picsum.photos/seed/21/400/300"
                ),
                heroPhotos: [mockPhoto(21, featured: true), mockPhoto(22)],
                momentCount: 6
            ), onTalk: {})

            // C · 1 张拼图 · 超长主句与母语均截为两行
            Tab2HeroCard(category: .mock(
                category: "日常起居",
                featured: mockFeatured(
                    scene: "Fixing a device",
                    userOriginal: nil,
                    target: "I spent the whole afternoon trying to fix the old device, but every setting seemed to make the problem even stranger than before.",
                    native: "我整个下午都在试着修那台旧设备，但每调一个设置，问题好像都变得比之前更奇怪。",
                    inputLang: nil,
                    image: "https://picsum.photos/seed/31/400/300"
                ),
                heroPhotos: [mockPhoto(31, featured: true)],
                momentCount: 2
            ), onTalk: {})

            // featured 无图但分类有三张照片：必须走预设图；中文 scene_detail 也会被前端兜底隐藏。
            Tab2HeroCard(category: .mock(
                category: "家庭与人际",
                featured: mockFeatured(
                    scene: "帮妈妈弄手机",
                    userOriginal: "今天帮我妈弄手机",
                    target: "I helped my mum with her phone today.",
                    native: nil,
                    inputLang: "native"
                ),
                heroPhotos: [mockPhoto(41), mockPhoto(42), mockPhoto(43)],
                momentCount: 1000
            ), onTalk: {})

            // D · 预设图 · 三行词、词性和释义
            Tab2HeroCard(category: .mock(
                category: "科技数码",
                featured: nil,
                heroPhotos: [],
                momentCount: 0,
                previewWords: [
                    Tab2PreviewWord(lemma: "back up", displayForm: "back up", pos: "v.", nativeMeaning: "备份"),
                    Tab2PreviewWord(lemma: "glitch", displayForm: "glitch", pos: "n.", nativeMeaning: "小故障"),
                    Tab2PreviewWord(lemma: "firmware", displayForm: "firmware", pos: "n.", nativeMeaning: "设备固件与系统软件"),
                ]
            ), onTalk: {})
        }
        .padding(.vertical, AppTheme.Space.paddingSection)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }
    .background(AppTheme.Color.pageBg)
}
#endif
