import SwiftUI

/// Tab2「More to talk about」列表行（刀 4b 按规格 v3 重建，刀 6 按视觉稿 v11 重排，
/// 刀 6b 按视觉稿 v12 胶囊化）。
///
/// 行内容按数据自行判定，无需外部传参。刀 6 层级反转（§三）：
/// - 帽行（.rtop）：类别名 12px/600 textSecondary 降为帽子（15→12——12 个类别名
///   每个用户都一样）；时间 11.5px neutralFaint 升到帽行右端（原在第三行）
/// - 活动胶囊组（.rchips）：13pt Charter、固定两行槽高、一行一颗胶囊、
///   +N more 无底尾随（§三④/刀 6b v12）。行内最大声部——活动名是这一页唯一
///   能证明「系统认识我」的东西。次数上标已随 v12 删除（只参与后端排序）
/// - 词数行（.rwords）：12px textMuted 独占末行（原在首行右端）
/// - lastMaterialAt = null → 时间不渲染（帽行只剩类别名）；无有效活动（空态 v1 B2）→
///   胶囊组与固定 60pt 槽、行高下限一并收掉，原位放一行「Only words so far」
///   （与 Hero 同一句、同一档样式，.onlywords 上距 7），词数行保留其下
///   （.rwords.tight 上距 6）——行就是矮的，与「高的行有内容」对比是有意设计
///
/// 缩略图取第一条**有效**活动的封面（被挡 = 整条不渲染 = 不参与取图），
/// 无 → 类别预设图（§五：平底 + 线性图标）。折叠/取图口径见 `Tab2ActivityDisplay`。
struct Tab2ActivityRow: View {
    let category: Tab2CategoryData
    let onTap: () -> Void

    private var sceneCategory: SceneCategory { SceneCategory.from(category.sceneCategory) }
    private var display: Tab2ActivityDisplay {
        Tab2ActivityDisplay.compute(category: category)
    }

    var body: some View {
        Button(action: onTap) {
            rowContent
        }
        .buttonStyle(Tab2ActivityRowPressStyle())
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
                hatRow
                    .padding(.trailing, AppTheme.Tab2MoreRow.Layout.hatRowTrailingInset)

                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        if display.valid.isEmpty {
                            // 空态 v1 B2：原位一行 Only words so far（与 Hero 同句同档），
                            // 词数行保留其下、上距收紧（说明行与词数行说的是同一件事）。
                            Tab2OnlyWordsLine()
                                .padding(.top, AppTheme.Tab2MoreRow.Layout.categoryToActivity)
                            wordsLine
                                .padding(.top, AppTheme.Tab2MoreRow.Layout.emptyLineToWords)
                        } else {
                            activityBlock
                                .padding(.top, AppTheme.Tab2MoreRow.Layout.categoryToActivity)
                            wordsLine
                                .padding(.top, AppTheme.Tab2MoreRow.Layout.activityToWords)
                        }
                    }
                    .padding(.trailing, AppTheme.Tab2MoreRow.Layout.contentTrailingInset)

                    arrow
                        .padding(.trailing, AppTheme.Tab2MoreRow.Layout.arrowTrailingInset)
                }
            }
            .padding(.top, AppTheme.Tab2MoreRow.Layout.contentTopInset)
            .padding(.bottom, AppTheme.Tab2MoreRow.Layout.contentBottomInset)
            .padding(.leading, AppTheme.Tab2MoreRow.Layout.contentLeadingInset)
        }
        // minHeight，不是 height：默认字号下内容天然就是这个高度，行会稳稳停在
        // 这——多数用户看到的观感等同固定行高。字号调大到内容超出这个下限时，
        // minHeight 自然放行长高，不裁文字；不需要按字号档位另外分支判断。
        // 空态行不设下限：胶囊组与 60pt 槽一并收掉，「行就是矮的」本身是设计
        // （空态 v1：高的行有内容、矮的行只有词，两种行高混排不乱）。
        .frame(minHeight: display.valid.isEmpty ? 0 : AppTheme.Tab2MoreRow.Layout.rowHeight)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Color.warmGlassSurface)
        .compositingGroup()
        // 圆角与 Hero 卡同档（large 20）：推荐行与 hero 是同一族「可聊的话题」，
        // 只有大小之分、没有species之分。此前用 medium(16) 会让两者读作两类东西。
        .clipShape(.rect(cornerRadius: AppTheme.Radius.large))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
        }
        .cardShadow()
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
        if let cover = display.photoCover {
            photoThumbnail(cover: cover)
        } else {
            RowPresetThumb(category: sceneCategory)
        }
    }

    private func photoThumbnail(cover: Tab2Activity.Cover) -> some View {
        CachedRemoteImage(
            // photoCover 已过滤掉 imageUrl 为空/nil 的 cover（Tab2ActivityDisplay.compute），
            // 这里的 ?? "" 只是让类型对上，实际走不到。
            signedUrl: cover.imageUrl ?? "",
            stableKey: cover.stableImageKey ?? cover.imageUrl ?? "",
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

    // MARK: - 帽行（类别帽 + 时间，§三①②）

    private var hatRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            // 句首大写而非全大写——与理由胶囊同款排印（v11）。类别名是 12 个
            // 用户都一样的常数，降到帽子声部，textSecondary。
            Text(category.englishLabel)
                .font(AppTheme.Font.tab2MoreRowCategory)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: AppTheme.Space.paddingS)

            if let timeline = timelineText {
                Text(timeline)
                    .font(AppTheme.Font.tab2MoreRowTimeline)
                    .foregroundStyle(AppTheme.Color.neutralFaint)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
        }
    }

    // MARK: - 活动胶囊组与词数行

    /// 活动胶囊组（§三④ + 刀 6b v12 .rchips）：13pt Charter、固定两行槽高、
    /// 一行一颗胶囊、+N more 无底尾随。显示条数与 +N 在拿到宽度后按让位规则
    /// 拟合（Tab2ActivityCapsuleGroup）。
    private var activityBlock: some View {
        Tab2ActivityCapsuleGroup(
            activities: display.valid,
            activityCount: category.activityCount,
            blockedCount: display.blockedCount,
            metrics: Tab2ActivityCapsuleMetrics.more(),
            nameFont: AppTheme.Font.tab2MoreRowCapsuleName,
            moreFont: AppTheme.Font.tab2MoreRowCapsuleMore
        )
        .equatable()
    }

    /// 词数行（§三③）：12px textMuted，独占末行（原在首行右端）。
    private var wordsLine: some View {
        Text(Tab2CardLabels.words(category.wordCount))
            .font(AppTheme.Font.tab2MoreRowMeta)
            .foregroundStyle(AppTheme.Color.textMuted)
            .monospacedDigit()
            .lineLimit(1)
    }

    private var timelineText: String? {
        Tab2CardLabels.timeLine(lastMaterialAt: category.lastMaterialAt)
    }
}

/// 与 HeroCardPressStyle 同一套按压配方（§5 行的按压反馈与 hero 手感一致）。
private struct Tab2ActivityRowPressStyle: ButtonStyle {
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
        activityCount: Int,
        activities: [Tab2Activity] = [],
        lastMaterialAt: Date? = nil
    ) -> Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: category,
            wordCount: wordCount,
            unlocked: true,
            lastMaterialAt: lastMaterialAt,
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
            Tab2Activity.Cover(materialId: "mock-\(scene)", imageUrl: $0)
        }
    )
}

/// 目检清单（刀 6b 视觉稿 v12）：
/// ① normal · 照片缩略图 · 类别帽 12/600 + 时间在帽行右端 · 两行胶囊组（13pt 衬线
///    米底胶囊、次数不渲染、+N more 无底尾随）· 词数行 12px muted 末行
/// ② normal · 无 cover 活动 → 预设图（平底 + 图标 26）· 胶囊组 + 时间
/// ③ 脏活动名：被挡的不渲染、计入 +N 口径（activity_count − 已显示 − 被挡）
/// ④ 无活动（空态 v1 B2）：帽行 + 一行 Only words so far + 词数行（tight 上距），
///    胶囊组与 60pt 槽、行高下限一并收掉——行就是矮的
/// ⑤ lastMaterialAt = null → 帽行右端无时间
#Preview("Tab2 Activity Row · visual matrix") {
    ScrollView {
        VStack(spacing: AppTheme.Space.paddingM) {
            // ①
            Tab2ActivityRow(
                category: .mock(
                    category: "饮食",
                    activityCount: 9,
                    activities: [
                        mockActivity(scene: "Cooking dinner", occurrenceCount: 3,
                                     image: "https://picsum.photos/seed/71/400/300"),
                        mockActivity(scene: "Brewing coffee", occurrenceCount: 2),
                        mockActivity(scene: "Grocery runs"),
                    ],
                    lastMaterialAt: Date()
                ),
                onTap: {}
            )
            // ②
            Tab2ActivityRow(
                category: .mock(
                    category: "工作与学业",
                    activityCount: 6,
                    activities: [
                        mockActivity(scene: "Meetings"),
                        mockActivity(scene: "Deadlines"),
                    ],
                    lastMaterialAt: Calendar.current.date(byAdding: .day, value: -3, to: Date())
                ),
                onTap: {}
            )
            // ③ 第一条被挡（中文），第三条顶上来；activity_count 5 − 显示 − 被挡 1 = +N
            Tab2ActivityRow(
                category: .mock(
                    category: "家庭与人际",
                    activityCount: 5,
                    activities: [
                        mockActivity(scene: "帮妈妈弄手机"),
                        mockActivity(scene: "Family dinner", occurrenceCount: 4),
                        mockActivity(scene: "Weekend calls"),
                    ],
                    lastMaterialAt: Calendar.current.date(byAdding: .day, value: -1, to: Date())
                ),
                onTap: {}
            )
            // ④ noActivities：只有帽行 + 词数行
            Tab2ActivityRow(
                category: .mock(
                    category: "科技数码",
                    wordCount: 24,
                    activityCount: 0,
                    lastMaterialAt: Calendar.current.date(byAdding: .day, value: -9, to: Date())
                ),
                onTap: {}
            )
            // ⑤ lastMaterialAt = null → 帽行右端无时间（纯查词且无素材）
            Tab2ActivityRow(
                category: .mock(
                    category: "购物",
                    wordCount: 24,
                    activityCount: 0
                ),
                onTap: {}
            )
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingSection)
    }
    .background(AppTheme.Color.pageBg)
}
#endif
