import SwiftUI

/// Tab2 已解锁分类的唯一 Hero 卡（刀 4b 按规格 v3 重建，刀 6 按视觉稿 v11 重排，
/// 刀 6b 按视觉稿 v12 胶囊化 + 空态 v1）。
///
/// 结构（v12 + 空态 v1，2026-09-22 视觉回归 main 基线 §2.4/§2.5 更新图上标签材质）：
/// - 顶部 = 第一条**有效**活动的封面照片（无 → 类别预设图）；图上左上角一行
///   （.toprow）两颗标签：类别 chip（{类别英文名} 11.5/600，§二①）+
///   理由胶囊 opill（§二②：hot/quiet 两态同一位置、同一文案，不再变色——
///   文案已经把状态说完，颜色不重复说第二遍）。两者均无托底胶囊，裸文字 +
///   shadow，可读性靠照片层顶部 scrim 压出来（main 基线做法）。预设图
///   （photoCover == nil）是浅底 → 两颗标签换单色深字、无 shadow（空态 v1
///   .onlight：深色投影是给不可控照片准备的，浅底上不需要）
/// - 卡身 = 「Recent activities」区内小标题（11/600 无衬线大写，v12 .seclab）→
///   活动胶囊组（15pt Charter、固定两行槽高、一行一颗胶囊、+N more 无底尾随，
///   v12 .achips）→ 脚行（左 47 words 13px muted 表格数字、右 Start talking
///   CTA 右对齐，v12 .footrow）
/// - 活动数为 0（或全部候选被挡）→ 小标题保留，胶囊组换成一行
///   「Only words so far」（13px 无衬线 muted、单行自然高度，空态 v1 .onlywords）：
///   占位不是两行槽——槽是为「多颗胶囊可扫视比较」存在的，只有一行字就按
///   文本自然高度走，卡片比有内容时矮一点，矮得有理由（空态 v1 规则表）
/// - CTA 仍弹 Coming soon（本轮不动）；CTA 底改 v12 .cta 的 --btn #17120C
///   （interactive），字改 #FCF8F3（textOnChip）
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
    /// 图上标签走浅底深字一套的判定：无封面 = 预设浅底图（#F3EDE6）——深色
    /// 半透明托底是给不可控照片准备的，浅底上会突兀（空态 v1 .onlight）。
    /// 空态必无封面，但反过来不成立：有活动却无封面同样落在预设浅底上，
    /// 判定跟图走、不跟活动走，两类浅底保持一致。
    private var onLightArt: Bool { display.photoCover == nil }

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
                }
            bottomContent
                .offset(y: AppTheme.Tab2Hero.Layout.artTextOverlap)
                .padding(.bottom, AppTheme.Tab2Hero.Layout.artTextOverlap)
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

    /// 图上左上角一行（v12 .toprow）：类别 chip + 理由胶囊，裸文字 + shadow
    /// （2026-09-22 视觉回归 main 基线 §2.4，无托底胶囊）。
    private var photoTopRow: some View {
        HStack(spacing: 8) {
            categoryChip
            reasonPill
        }
    }

    /// 类别标签（§二①）。v12 起不再带词数段（词数随 .footrow 移到卡身脚行左端）。
    /// 2026-09-22 视觉回归 main 基线（§2.4）：去掉托底胶囊，改裸文字 + shadow——
    /// main 没有任何图上标签托底，可读性靠照片层顶部 scrim（`HeroCollageView`）压出来；
    /// 预设浅底上无 shadow（浅底不需要）。
    private var categoryChip: some View {
        Text(category.englishLabel)
            .font(AppTheme.Font.tab2HeroChipCategory)
            .foregroundStyle(onLightArt
                             ? AppTheme.Color.tab2HeroPresetLabel
                             : AppTheme.Color.tab2HeroPhotoOverlayText)
            .lineLimit(1)
            .shadow(
                color: photoTextShadowColor,
                radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                x: 0,
                y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
            )
    }

    /// 理由胶囊（刀 6b v12 .opill）。2026-09-22 视觉回归 main 基线（§2.4 去托底 +
    /// §2.5 去 hot/quiet 变色）：`Tab2CardLabels.reasonLine` 的文案已经把状态说完了
    /// （hot → "Added 3 times today"，quiet → "Nothing new in 2 weeks"），再用颜色
    /// 染一遍是同一信息说两次——两态改共用同一套配色（取原 quiet 值），托底圆点一并
    /// 去掉。`onLightArt` 判定仍保留：用户照片颜色不可控，不区分底色会在亮照片上丢字。
    private var reasonPill: some View {
        let state = Tab2CardLabels.reasonPillState(
            lastMaterialAt: category.lastMaterialAt,
            newMaterialCount: category.newMaterialCount
        )
        return Text(state.text)
            .font(AppTheme.Font.tab2ReasonPill)
            .foregroundStyle(onLightArt
                             ? AppTheme.Color.tab2ReasonPillOnLightText
                             : AppTheme.Color.tab2ReasonPillOnPhotoText)
            .lineLimit(1)
            .shadow(
                color: photoTextShadowColor,
                radius: AppTheme.Tab2Hero.Layout.photoOverlayShadowRadius,
                x: 0,
                y: AppTheme.Tab2Hero.Layout.photoOverlayShadowY
            )
    }

    /// 图上标签投影色：照片底用近黑 50% 投影保可读性；预设浅底不需要投影
    /// （main HeroTopOverlay 的 `.preset` 分支 shadow 透明度为 0）。
    private var photoTextShadowColor: Color {
        onLightArt
            ? AppTheme.Color.tab2HeroPhotoOverlayShadow.opacity(AppTheme.Tab2Hero.Opacity.transparent)
            : AppTheme.Color.tab2HeroPhotoOverlayShadow.opacity(AppTheme.Tab2Hero.Opacity.photoTextShadow)
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

    /// 「Recent activities」区内小标题（v12 .seclab：11/600 无衬线大写、字距 .09em）
    /// + 内容。有活动 → 胶囊组；无活动（activityCount = 0 或全部被挡）→ 标题保留、
    /// 一行「Only words so far」占位（空态 v1 .onlywords：单行自然高度，不占两行槽）。
    /// 标题与内容间距同 9（.seclab 下距 9 对两种内容通用）。
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
                Tab2OnlyWordsLine()
            }
        }
    }

    /// 脚行（v12 .footrow）：左词数 13px muted 表格数字，右 CTA。
    private var footRow: some View {
        HStack(alignment: .center, spacing: AppTheme.Space.paddingS) {
            Text(Tab2CardLabels.words(category.wordCount))
                .font(AppTheme.Font.tab2HeroFootrowWords)
                .foregroundStyle(AppTheme.Color.textMuted)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)

            Spacer(minLength: 0)

            ctaPill
        }
    }

    private var ctaPill: some View {
        HStack(spacing: AppTheme.Tab2Hero.Layout.ctaContentGap) {
            Text("Start talking")
            Image(systemName: "arrow.right")
                .imageScale(.small)
        }
        .font(AppTheme.Font.tab2HeroCTA)
        .foregroundStyle(AppTheme.Color.textOnChip)
        .padding(.horizontal, AppTheme.Tab2Hero.Layout.ctaHorizontalInset)
        .frame(height: AppTheme.Tab2Hero.Layout.ctaHeight)
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
