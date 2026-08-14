import SwiftUI

/// Tab2 已解锁分类卡（设计方案 §2–§7）。所有已解锁分类共用本组件（原 Tab2CategoryRow 已并入）。
/// 结构：顶部拼图/预设图（分类级氛围）+ 底部单条 featured moment（同源）+ 右下角 CTA。
/// 底部按 (user_original, input_lang) 分四种模式（§4.2）：
///   A 你说过的英语（引号+衬线）· B 想说没说出（衬线主角+母语注脚，无引号）
///   C 你拍下的场景（衬线主角+来源标记，无引号）· D 攒下的词（chips 兜底）
struct Tab2HeroCard: View {
    let category: Tab2CategoryData
    let isFirstUnlock: Bool
    let onTalk: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }

    // 底部固定高度：各模式对齐，列表滚动不跳动（§2.3）
    private let bottomHeight: CGFloat = 172

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onTalk()
        } label: {
            cardContent
        }
        .buttonStyle(HeroCardPressStyle())
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            topArt
            bottomContent
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.glassContainer))
        .background {
            RoundedRectangle(cornerRadius: AppTheme.Radius.glassContainer)
                .fill(AppTheme.Color.warmGlassSurface)
        }
        .shadow(color: AppTheme.Shadow.cardColor, radius: 12, x: 0, y: 4)
    }

    // MARK: - 顶部（§6.3：判定源是 hero_photos 是否为空）

    @ViewBuilder
    private var topArt: some View {
        let label = category.englishLabel
        let pops  = PopsLabel.format(category.wordCount)
        // +N：除底部正在看的这条 featured，分类还剩几个 moment（§9.3）
        let moreCount = max(0, category.momentCount - 1)

        if category.heroPhotos.isEmpty {
            CategoryPresetArtView(
                category: sceneCategory, categoryLabel: label,
                popsText: pops, moreCount: moreCount
            )
        } else {
            HeroCollageView(
                photos: category.heroPhotos, categoryLabel: label,
                popsText: pops, moreCount: moreCount
            )
        }
    }

    // MARK: - 底部内容（meta + 主角 + CTA）

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
                if let f = category.featured {
                    metaRow(f)
                    featuredLead(f)
                } else {
                    fallbackWords   // 模式 D
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            Spacer(minLength: AppTheme.Space.paddingM)

            HStack {
                Spacer()
                ctaPill
            }
        }
        .padding(.horizontal, AppTheme.Space.paddingCard)
        .padding(.vertical, AppTheme.Space.paddingM)
        .frame(height: bottomHeight)
    }

    // MARK: - Meta 行（§5）：scene · [📷 from your photo] · [seen N×] · time

    @ViewBuilder
    private func metaRow(_ f: Tab2FeaturedMoment) -> some View {
        HStack(spacing: 5) {
            Text(f.sceneDetail)
                .font(AppTheme.Font.pos)
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineLimit(1)

            if mode(f) == .c {
                metaDot
                HStack(spacing: 3) {
                    Image(systemName: "camera")
                    Text("from your photo")
                }
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textSecondary)
            }
            if let t = f.createdAt {
                metaDot
                Text(Self.relativeTime(t))
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }
            Spacer(minLength: 0)
        }
    }

    private var metaDot: some View {
        Text("·")
            .font(AppTheme.Font.pos)
            .foregroundStyle(AppTheme.Color.neutralFaint)
    }

    // MARK: - 主角句（模式 A / B / C）

    @ViewBuilder
    private func featuredLead(_ f: Tab2FeaturedMoment) -> some View {
        switch mode(f) {
        case .a:
            // 主角 = 用户英文原话（引号 = 目标语言字面产出，§4.1）；母语翻译作注脚
            leadStack(primary: "\u{201C}\(f.userOriginal ?? "")\u{201D}", footnote: f.nativeMeaning)
        case .b:
            // 主角 = target（无引号）；用户母语原话作注脚
            leadStack(primary: f.targetExpression ?? "", footnote: f.userOriginal)
        case .c:
            // 主角 = target（无引号，来源标记在 meta 行）；母语翻译作注脚
            leadStack(primary: f.targetExpression ?? "", footnote: f.nativeMeaning)
        case .d:
            EmptyView()   // 由 fallbackWords 承载
        }
    }

    // 主角句（英文，衬线）+ 母语注脚（muted）。四模式统一：英文在上、母语在下。
    @ViewBuilder
    private func leadStack(primary: String, footnote: String?) -> some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
            Text(primary)
                .font(AppTheme.Font.cardSentence)
                .foregroundStyle(AppTheme.Color.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let note = footnote, !note.isEmpty {
                Text(note)
                    .font(AppTheme.Font.chineseFaint)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - 模式 D（词 chips 兜底，§4.6）

    @ViewBuilder
    private var fallbackWords: some View {
        let words = Array(category.previewWords.prefix(6))
        if !words.isEmpty {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
                Text("Your collected pops")
                    .font(AppTheme.Font.chineseBody)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                FlowLayout(spacing: AppTheme.Space.paddingS) {
                    ForEach(words, id: \.self) { w in
                        Text(w)
                            .font(AppTheme.Font.iconBadgeLetter)   // 衬线，呼应品牌
                            .foregroundStyle(AppTheme.Color.textSecondary)   // 克制中性色，不用品牌橙
                            .padding(.horizontal, AppTheme.Space.paddingM)
                            .padding(.vertical, AppTheme.Space.paddingS)
                            .background(AppTheme.Color.pageBg, in: Capsule())
                            .overlay(Capsule().stroke(AppTheme.Color.border, lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - CTA（深色实心 pill，参考 Duolingo「Start lesson」样式）

    private var ctaPill: some View {
        HStack(spacing: AppTheme.Space.paddingS) {
            Text("Start talking")
            Image(systemName: "arrow.right")
                .imageScale(.small)
        }
        .font(AppTheme.Font.ctaLabel)
        .foregroundStyle(.white)
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingM)
        .background(AppTheme.Color.textPrimary, in: Capsule())
    }

    // MARK: - 模式判据（§4.2：用 (user_original, input_lang) 组合，不能只看 input_lang）

    enum FeaturedMode { case a, b, c, d }

    /// 纯逻辑判据（可单测）：
    /// 无 featured → D；有母语原话 → target 记 A、其余(native/other) 记 B；无原话(纯图片) → C。
    static func featuredMode(userOriginal: String?, inputLang: String?, hasFeatured: Bool) -> FeaturedMode {
        guard hasFeatured else { return .d }
        if let o = userOriginal, !o.isEmpty {
            // input_lang='other'（第三语言）按非目标语言处理，落 B（无引号）
            return inputLang == "target" ? .a : .b
        }
        return .c   // user_original 为空 = 纯图片
    }

    private func mode(_ f: Tab2FeaturedMoment) -> FeaturedMode {
        Self.featuredMode(userOriginal: f.userOriginal, inputLang: f.inputLang, hasFeatured: true)
    }

    // MARK: - 相对时间（§5.4：粗粒度，不到小时）

    static func relativeTime(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: now)
        ).day ?? 0
        switch days {
        case ..<1:    return "today"
        case 1:       return "yesterday"
        case 2...27:  return "\(days) days ago"
        case 28...59: return "last month"
        default:      return "earlier"
        }
    }
}

// MARK: - 极简 Flow 布局（chips 按行打包，不裁半行，§4.6）

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW == .infinity ? x : maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}

// MARK: - Press style

private struct HeroCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview mock（展示四模式 × 拼图/预设的各种卡片样式）

#if DEBUG
private extension Tab2CategoryData {
    static func mock(
        category: String, featured: Tab2FeaturedMoment?, heroPhotos: [Tab2HeroPhoto],
        momentCount: Int, previewWords: [String] = []
    ) -> Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: category, wordCount: 42, unlocked: true,
            lastMaterialAt: Date(), subScenes: [], previewWords: previewWords,
            momentCount: momentCount, featured: featured, heroPhotos: heroPhotos
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
    scene: String, userOriginal: String?, target: String?, native: String?,
    inputLang: String?, image: String? = nil, occ: Int = 1
) -> Tab2FeaturedMoment {
    Tab2FeaturedMoment(
        sceneDetail: scene, occurrenceCount: occ, materialId: "mf",
        userOriginal: userOriginal, targetExpression: target, nativeMeaning: native,
        imageUrl: image, inputLang: inputLang, sourceDirection: "express",
        sourceGranularity: "sentence", createdAt: Date().addingTimeInterval(-4 * 86400),
        spokenCount: 0
    )
}

#Preview("Hero 卡 · 四模式") {
    ScrollView {
        VStack(spacing: 22) {
            // 模式 A：英文原话（引号）+ 3 张拼图（c3）
            Tab2HeroCard(category: .mock(
                category: "饮食",
                featured: mockFeatured(
                    scene: "Cooking dinner",
                    userOriginal: "The sauce came out way too salty tonight.",
                    target: nil, native: "今晚酱汁太咸了。", inputLang: "target", occ: 4),
                heroPhotos: [mockPhoto(11, featured: true), mockPhoto(12), mockPhoto(13)],
                momentCount: 4
            ), isFirstUnlock: false, onTalk: {}).frame(width: 350)

            // 模式 B：中文原话（无引号 + 母语注脚）+ 预设图（无照片）
            Tab2HeroCard(category: .mock(
                category: "工作与学业",
                featured: mockFeatured(
                    scene: "Standup meeting",
                    userOriginal: "他们问我时间线时我大脑一片空白",
                    target: "I totally blanked when they asked me for the timeline.",
                    native: nil, inputLang: "native", occ: 5),
                heroPhotos: [], momentCount: 5
            ), isFirstUnlock: false, onTalk: {}).frame(width: 350)

            // 模式 C：纯图片（from your photo）+ 单图（c1）
            Tab2HeroCard(category: .mock(
                category: "饮食",
                featured: mockFeatured(
                    scene: "Cooking dinner", userOriginal: nil,
                    target: "The kitchen smells wonderful tonight.",
                    native: "今晚厨房飘着好闻的香气。", inputLang: nil,
                    image: "https://picsum.photos/seed/21/400/300"),
                heroPhotos: [mockPhoto(21, featured: true)],
                momentCount: 1
            ), isFirstUnlock: false, onTalk: {}).frame(width: 350)

            // 模式 D：无 featured（全查词）+ 预设图 + 词 chips
            Tab2HeroCard(category: .mock(
                category: "科技数码", featured: nil, heroPhotos: [], momentCount: 0,
                previewWords: ["back up", "glitch", "firmware", "sync", "latency", "crash"]
            ), isFirstUnlock: false, onTalk: {}).frame(width: 350)

            // 拼图变体：5 张（c5）
            Tab2HeroCard(category: .mock(
                category: "休闲娱乐",
                featured: mockFeatured(
                    scene: "Watching sports", userOriginal: nil,
                    target: "The stadium was absolutely electric tonight.",
                    native: "今晚球场气氛热烈。", inputLang: nil,
                    image: "https://picsum.photos/seed/31/400/300"),
                heroPhotos: [mockPhoto(31, featured: true), mockPhoto(32), mockPhoto(33),
                             mockPhoto(34), mockPhoto(35)],
                momentCount: 8
            ), isFirstUnlock: false, onTalk: {}).frame(width: 350)
        }
        .padding(.vertical, 30)
    }
    .frame(maxWidth: .infinity)
    .background(AppTheme.Color.pageBg)
}
#endif
