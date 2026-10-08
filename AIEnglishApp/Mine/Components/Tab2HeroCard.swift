import SwiftUI

/// Tab2 已解锁分类的唯一 Hero 卡（刀 4b 按规格 v3 重建，刀 6 按视觉稿 v11 重排，
/// 刀 6b 按视觉稿 v12 胶囊化 + 空态 v1）。
///
/// 结构（v12 + 空态 v1，2026-09-22 视觉回归 main 基线 §2.4/§2.5 更新图上标签材质）：
/// - 顶部 = 第一条**有效**活动的封面照片（无 → 类别预设图）；图上左上角一行
///   （.toprow）两颗标签：类别名（13/400，§二①）+
///   理由胶囊 opill（§二②：hot/quiet 两态同一位置、同一文案，不再变色——
///   文案已经把状态说完，颜色不重复说第二遍）。两者均无托底胶囊，裸文字 +
///   shadow，可读性靠照片层顶部 scrim 压出来（main 基线做法）。
///   封面标签颜色：照片底 = 纯白字 + 柔焦微阴影；预设底（浅杏色）= 深棕字、无阴影（2026-10-06 起分流，见 Tab2HeroCoverLabels）。
///   已知取舍：预设底理由行 72% 深棕约 3.6:1（类别名 6.6:1），PM 看过真机渲染后接受。
///   排布（并排 / 大字号放不下换两行）在 Tab2HeroCoverLabels。
/// - 卡身 = 「Recent activities」区内小标题（11/600 无衬线大写，v12 .seclab）→
///   活动胶囊组（15pt Charter、固定两行槽高、一行一颗胶囊、+N more 无底尾随，
///   v12 .achips）→ 脚行（左 47 words 13px muted 表格数字、右 Start talking
///   CTA 右对齐，v12 .footrow）
/// - 活动数为 0（或全部候选被挡）→ 小标题保留，胶囊组换成一行
///   「Only words so far」（13px 无衬线 muted、单行自然高度，空态 v1 .onlywords）：
///   占位不是两行槽——槽是为「多颗胶囊可扫视比较」存在的，只有一行字就按
///   文本自然高度走，卡片比有内容时矮一点，矮得有理由（空态 v1 规则表）
/// - CTA 仍弹 Coming soon（本轮不动）；CTA 底改 v12 .cta 的 --btn #17120C
///   （interactive），字改 #FBF8F5（textOnChip）
///
/// Hero 由 MineView 进入页面时求值一次传入（一次浏览之内不换），
/// 本卡内没有任何选取逻辑。折叠/取图口径见 `Tab2ActivityDisplay`。
struct Tab2HeroCard: View {
    let category: Tab2CategoryData
    let onTalk: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private var display: Tab2ActivityDisplay {
        Tab2ActivityDisplay.compute(category: category)
    }
    /// 是否用预设艺术图（没有可信照片）：只用于控制卡身与艺术图的几何间距（预设图为 primary300 实底、
    /// 底边硬边无渐变，不做卡身上叠）；文字颜色另由 onPresetArt 传给 Tab2HeroCoverLabels。
    private var usesPresetArt: Bool { Self.usesPresetArt(display) }

    /// 没有可信照片就用预设图——封面字色（深棕 / 白字）也跟着它走，单测锁定这条接线。
    static func usesPresetArt(_ display: Tab2ActivityDisplay) -> Bool { display.photoCover == nil }
    /// 卡身上叠进图片的距离：照片底部有淡出渐变，卡身可以上叠；预设图是
    /// primary300 实底、底边是硬边，上叠会让小标题贴着色块（只剩约 2pt），故不叠。
    private var artTextOverlap: CGFloat {
        usesPresetArt ? 0 : AppTheme.Tab2Hero.Layout.artTextOverlap
    }

    var body: some View {
        Button(action: onTalk) {
            cardContent
        }
        .buttonStyle(HeroCardPressStyle())
        .fixedSize(horizontal: false, vertical: true)
    }

    private var cardContent: some View {
        VStack(spacing: 0) {
            topArt
                .overlay(alignment: .topLeading) {
                    photoTopRow
                        .padding(.top, AppTheme.Tab2Hero.Layout.chipTopLeading)
                        .padding(.leading, AppTheme.Tab2Hero.Layout.chipTopLeading)
                        // 右侧留同样的边距：一行并排时文字不会贴到卡片右缘，放不下就换成两行。
                        .padding(.trailing, AppTheme.Tab2Hero.Layout.chipTopLeading)
                }
            bottomContent
                .offset(y: artTextOverlap)
                .padding(.bottom, artTextOverlap)
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.Color.warmGlassSurface)
        .compositingGroup()
        .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
        }
        .cardShadow()
    }

    // MARK: - 顶部图（规格 v3「图片取值」：只用第一条有效活动的封面，null → 预设图）

    @ViewBuilder
    private var topArt: some View {
        if let cover = display.photoCover {
            Tab2HeroPhotoArt(cover: cover)
        } else {
            CategoryPresetArtView(category: sceneCategory)
        }
    }

    /// 图上左上角一行（v12 .toprow）：类别名 + 理由，裸文字 + shadow，无托底胶囊。
    /// 排布（并排 / 放不下换两行）、颜色与阴影都在 `Tab2HeroCoverLabels`。
    private var photoTopRow: some View {
        Tab2HeroCoverLabels(categoryName: category.englishLabel, reasonText: coverReasonText, onPresetArt: usesPresetArt)
    }

    /// 封面理由文案。lastMaterialAt 为空时理由就是 "Only words so far"，与卡身空态说明行
    /// （Tab2OnlyWordsSlot）是同一句话，同一张卡上会说两遍；封面不显示，说明行由卡身负责。
    private var coverReasonText: String? {
        let state = Tab2CardLabels.reasonPillState(
            lastMaterialAt: category.lastMaterialAt,
            newMaterialCount: category.newMaterialCount
        )
        return state.text == Tab2CardLabels.onlyWordsSoFar ? nil : state.text
    }

    // MARK: - 卡身文字区（v12 .hbody 16/18/18）

    private var bottomContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            activitySection
                .padding(.top, AppTheme.Tab2Hero.Layout.bodyTopInset)

            footRow
                .padding(.top, AppTheme.Tab2Hero.Layout.activityToCTA)
        }
        .padding(.horizontal, AppTheme.Tab2Hero.Layout.bodyHorizontalInset)
        .padding(.bottom, AppTheme.Tab2Hero.Layout.bodyBottomInset)
    }

    /// 「Recent activities」区内小标题（11/600 无衬线大写、字距 .09em、textMuted）
    /// + 内容。有活动 → 胶囊组；无活动（activityCount = 0 或全部被挡）→ 标题保留、
    /// Tab2OnlyWordsSlot 占位（保持 52pt 两行槽高，与正常态卡片高度 100% 恒定）。
    /// 标题与内容间距（.seclab 下距 sectionLabelToCapsules 对两种内容通用）。
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Tab2Hero.Layout.sectionLabelToCapsules) {
            Text("Recent activities")
                .font(AppTheme.Font.tab2HeroActivitySectionLabel)
                .tracking(AppTheme.Tab2Hero.Layout.sectionLabelTracking)
                .textCase(.uppercase)
                .foregroundStyle(AppTheme.Color.textMuted)

            if display.showsActivities {
                Tab2ActivityCapsuleGroup(
                    activities: display.valid,
                    activityCount: category.activityCount,
                    blockedCount: display.blockedCount,
                    metrics: Tab2ActivityCapsuleMetrics.hero(),
                    nameFont: AppTheme.Font.tab2HeroCapsuleName,
                    moreFont: AppTheme.Font.tab2HeroCapsuleMore
                )
                .equatable()
            } else {
                Tab2OnlyWordsSlot(metrics: Tab2ActivityCapsuleMetrics.hero())
            }
        }
    }

    /// 脚行（v12 .footrow）：左词数 13px muted 表格数字，右 CTA。
    /// 一行放得下就并排（这一支与改前完全一致，含固定高度的 CTA）；放不下（大字号）改成上下两行：
    /// 词数在上、CTA 在下靠右，CTA 的文字不再被挤成 "···"，药丸高度也允许随文字增高。
    private var footRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AppTheme.Space.paddingS) {
                wordsLabel
                Spacer(minLength: 0)
                ctaPill(growsWithText: false)
            }
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
                wordsLabel
                ctaPill(growsWithText: true)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var wordsLabel: some View {
        Text(Tab2CardLabels.words(category.wordCount))
            .font(AppTheme.Font.tab2HeroFootrowWords)
            .foregroundStyle(AppTheme.Color.textMuted)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
    }

    /// growsWithText = false：固定高度（默认字号，与改前一致）；true：最小高度，文字变高时药丸跟着长。
    private func ctaPill(growsWithText: Bool) -> some View {
        let label = HStack(spacing: AppTheme.Tab2Hero.Layout.ctaContentGap) {
            Text("Start talking")
            Image(systemName: "arrow.right")
                .imageScale(.small)
        }
        .font(AppTheme.Font.tab2HeroCTA)
        .foregroundStyle(AppTheme.Color.textOnChip)
        .padding(.horizontal, AppTheme.Tab2Hero.Layout.ctaHorizontalInset)
        return Group {
            if growsWithText {
                label.frame(minHeight: AppTheme.Tab2Hero.Layout.ctaHeight)
            } else {
                label.frame(height: AppTheme.Tab2Hero.Layout.ctaHeight)
            }
        }
        .background(
            AppTheme.Color.interactive,
            in: RoundedRectangle(
                cornerRadius: AppTheme.Tab2Hero.Layout.ctaCornerRadius,
                style: .continuous
            )
        )
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
        wordCount: Int = 42,
        activityCount: Int,
        activities: [Tab2Activity] = [],
        lastMaterialAt: Date? = nil,
        newMaterialCount: Int = 0
    ) -> Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: category,
            wordCount: wordCount,
            unlocked: true,
            lastMaterialAt: lastMaterialAt,
            newMaterialCount: newMaterialCount,
            activityCount: activityCount,
            activities: activities
        )
    }
}

private func mockActivity(
    scene: String,
    occurrenceCount: Int = 1,
    image: String? = nil
) -> Tab2Activity {
    Tab2Activity(
        sceneDetail: scene,
        occurrenceCount: occurrenceCount,
        cover: image.map {
            Tab2Activity.Cover(materialId: "mf", imageUrl: $0)
        }
    )
}

/// 目检清单（刀 6b 视觉稿 v12，2026-09-22 视觉回归 main 基线更新①②描述）：
/// ① 全量：晨曦暖光照片封面 + 图上 chip（仅类别名，裸字+投影）+ 理由胶囊 hot 态
///    （同一套配色，不再变色）+ Recent activities 小标题 + 胶囊组（15pt 衬线米底、
///    次数不渲染）+ 脚行（47 words 左 / Start talking 右）
/// ② 无图：晨曦暖光预设图（双光晕 + 手绘图标 + 橙点）+ 图上 chip + 理由胶囊 quiet 态
///    （单色深字、无投影）+ 胶囊组 + 脚行
/// ③ 脏活动名：被挡的活动不渲染，后面的有效活动顶上，+N 按 activity_count − 已显示 − 被挡
/// ④ 无活动（空态 v1）：预设浅底 + 图上 onlight 标签（浅底深字）+ 标题保留
///    + 一行 Only words so far（自然高度、不占两行槽）+ 脚行
/// ⑤ 理由折行防御：lastMaterialAt 昨天但 newMaterialCount ≥ 1 → 走 Nothing new since yesterday
#Preview("Tab2 Hero · visual matrix") {
    ScrollView {
        VStack(spacing: AppTheme.Space.paddingPage) {
            // ①
            Tab2HeroCard(category: .mock(
                category: "日常起居",
                activityCount: 7,
                activities: [
                    mockActivity(scene: "Fixing a device", occurrenceCount: 3,
                                 image: "https://picsum.photos/seed/31/400/300"),
                    mockActivity(scene: "Morning coffee", occurrenceCount: 2),
                    mockActivity(scene: "Watering plants"),
                    mockActivity(scene: "Walking the dog"),
                    mockActivity(scene: "Weekend cleaning"),
                ],
                lastMaterialAt: Date(),
                newMaterialCount: 3
            ), onTalk: {})

            // ②
            Tab2HeroCard(category: .mock(
                category: "科技数码",
                activityCount: 3,
                activities: [
                    mockActivity(scene: "Reading tech news"),
                    mockActivity(scene: "Charging devices"),
                    mockActivity(scene: "App updates"),
                ],
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -4, to: Date())
            ), onTalk: {})

            // ③ 第二条被挡（中文），第三条顶上来；activity_count 6 − 显示 − 被挡 1 = +N
            Tab2HeroCard(category: .mock(
                category: "工作与学业",
                activityCount: 6,
                activities: [
                    mockActivity(scene: "Meetings", occurrenceCount: 4),
                    mockActivity(scene: "开会做记录"),
                    mockActivity(scene: "Deadlines"),
                    mockActivity(scene: "Emails"),
                ],
                lastMaterialAt: Date()
            ), onTalk: {})

            // ④ 空态（空态 v1）：无 activity → 预设浅底 + onlight 标签
            // （quiet Nothing new in 5 days，同设计稿示例）+ 标题 + 一行 Only words so far
            Tab2HeroCard(category: .mock(
                category: "日常起居",
                wordCount: 47,
                activityCount: 0,
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -5, to: Date())
            ), onTalk: {})

            // ⑤ 防御：跨午夜缓存旧响应
            Tab2HeroCard(category: .mock(
                category: "家庭与人际",
                activityCount: 2,
                activities: [
                    mockActivity(scene: "Family dinner"),
                    mockActivity(scene: "Weekend calls"),
                ],
                lastMaterialAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                newMaterialCount: 2
            ), onTalk: {})
        }
        .padding(.vertical, AppTheme.Space.paddingSection)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }
    .background(AppTheme.Color.pageBg)
}
#endif
