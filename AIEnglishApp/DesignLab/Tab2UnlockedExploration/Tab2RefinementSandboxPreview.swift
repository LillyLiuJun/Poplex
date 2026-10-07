#if DEBUG
import SwiftUI
import UIKit

// MARK: - Tab2 解锁页细节打磨沙箱 (全部方案平铺直出 · 零点击切换)
//
// 🎯 本沙箱针对用户的两个微调需求，将【当前基线】与【全部优化方案】全部平铺陈列，无需点击任何菜单即可一眼对比！
//
// 📌 需求 1 平铺梯度 (Words 胶囊字体)：
//    1. 【当前基线】：12pt Medium (500) · 偏粗偏黑，墨团感
//    2. 【方案 1-A】：12pt Regular (400) · 笔画 1:1 光学同宽
//    3. 【方案 1-B】：11.5pt Regular (400) · 尺寸微缩半号
//    4. 【方案 1-C ⭐ 新增极细】：12pt Light (300) · 极细无衬线，腕表刻度感，空灵通透
//    5. 【方案 1-D ⭐ 新增超轻】：11.5pt Light (300) · 极细 + 微缩，羽量级辅助事实
//
// 📌 需求 2 平铺梯度 (More 卡片分类标签与 Activity 间距)：
//    1. 【当前基线】：间距 7.0pt · 卡片高 119pt · 略显粘连局促
//    2. 【方案 2-A ⭐ 黄金推荐】：间距 9.5pt · 卡片高 119pt (零高度惩罚！) · 舒展透气
//    3. 【方案 2-B】：间距 11.0pt · 卡片高 119pt (零高度惩罚！) · 三段式界限分明
//    4. 【方案 2-C】：间距 13.0pt · 卡片高 ~121pt (放行长高 2pt) · 大呼吸留白

struct Tab2RefinementSandboxPreviewView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {

                // 顶端总导读
                headerBanner

                // ─────────────────────────────────────────────
                // 模块 1：需求 1 全部字体方案直接平铺 (5 档粗细梯度)
                // ─────────────────────────────────────────────
                demand1AllSchemesFlatSection

                // ─────────────────────────────────────────────
                // 模块 2：需求 2 全部间距卡片直接平铺 (4 档真实卡片)
                // ─────────────────────────────────────────────
                demand2AllCardsFlatSection

                // ─────────────────────────────────────────────
                // 模块 3：整屏完整联合对比平铺 (横向滑动即看整页呼应)
                // ─────────────────────────────────────────────
                fullScreenComboFlatSection

                Spacer(minLength: 60)
            }
            .padding(.vertical, 20)
        }
        .background(AppTheme.Color.pageBg.ignoresSafeArea())
    }

    // MARK: - 顶端导读标题

    private var headerBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(AppTheme.Color.brandStrong).frame(width: 8, height: 8)
                Text("Tab2 解锁页 · 两个新需求【全方案平铺对比展厅】")
                    .font(AppTheme.Font.sectionLabel)
                    .foregroundStyle(AppTheme.Color.textPrimary)
            }

            Text("无需点击切换，全部基线与优化方案整齐平铺，上下滚动即可一眼感知粗细与间距变化。")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Color.textSecondary)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    // MARK: - 模块 1：需求 1 Words 胶囊 5 档粗细梯度平铺

    private var demand1AllSchemesFlatSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                badge: "需求 1 全景平铺",
                title: "Words 胶囊字体粗细梯度 (从粗到极细)",
                subtitle: "左侧分类标题已采用 13pt Regular 纤细风格，右侧 Words 胶囊由 Medium 500 递减至 Light 300"
            )
            .padding(.horizontal, AppTheme.Space.paddingPage)

            VStack(spacing: 12) {
                // 1. 基线 (Medium 500)
                wordsPillRowCard(
                    tag: "【当前基线】",
                    title: "12pt Medium (500)",
                    note: "线上现状：右侧墨团感偏重，压过左侧分类名",
                    isHighlight: false,
                    fontSize: 12,
                    weight: .medium
                )

                // 2. 方案 1-A (Regular 400)
                wordsPillRowCard(
                    tag: "【方案 1-A】",
                    title: "12pt Regular (400)",
                    note: "左右 1:1 光学同频笔触，自然温润匀质",
                    isHighlight: false,
                    fontSize: 12,
                    weight: .regular
                )

                // 3. 方案 1-B (11.5pt Regular 400)
                wordsPillRowCard(
                    tag: "【方案 1-B】",
                    title: "11.5pt Regular (400)",
                    note: "尺寸微降半号，次级事实感更强，突出主分类",
                    isHighlight: false,
                    fontSize: 11.5,
                    weight: .regular
                )

                // 4. 方案 1-C (12pt Light 300) ⭐ 强烈推荐！
                wordsPillRowCard(
                    tag: "【方案 1-C ⭐ 新增极细】",
                    title: "12pt Light (300) 极细无衬线",
                    note: "比 Regular 再细一档！优雅极细刻度感，彻底消除胶囊重量，如手账精致批注",
                    isHighlight: true,
                    fontSize: 12,
                    weight: .light
                )

                // 5. 方案 1-D (11.5pt Light 300)
                wordsPillRowCard(
                    tag: "【方案 1-D ⭐ 新增超轻】",
                    title: "11.5pt Light (300) 超轻羽量",
                    note: "微缩字号 + 极细字重，体量感最小，完全化为静默注脚",
                    isHighlight: true,
                    fontSize: 11.5,
                    weight: .light
                )
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    private func wordsPillRowCard(
        tag: String,
        title: String,
        note: String,
        isHighlight: Bool,
        fontSize: CGFloat,
        weight: Font.Weight
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tag)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isHighlight ? AppTheme.Color.brandStrong : AppTheme.Color.textSecondary)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Spacer()

                Text(weightLabel(weight))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(isHighlight ? AppTheme.Color.brandStrong : AppTheme.Color.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isHighlight ? AppTheme.Color.brandStrong.opacity(0.12) : AppTheme.Color.tab2ActivityChipBg, in: Capsule())
            }

            // 真实分类进度行呈现
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .frame(width: 20, height: 20)

                Text("Social & Feelings")
                    .font(AppTheme.Font.tab2TopicLabel) // 13pt Regular
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Spacer()

                // Words 胶囊渲染本体
                HStack(spacing: 4) {
                    Text("16 words")
                        .font(.system(size: fontSize, weight: weight))
                        .monospacedDigit()
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 7.5))
                        .foregroundStyle(AppTheme.Color.textMuted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
                .overlay(Capsule().strokeBorder(AppTheme.Color.tab2ProgressPillBorder, lineWidth: 0.5))
            }
            .padding(.vertical, 4)

            Text(note)
                .font(.system(size: 10.5))
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .padding(12)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isHighlight ? AppTheme.Color.brandStrong.opacity(0.4) : AppTheme.Color.cardBorder, lineWidth: isHighlight ? 1.2 : 0.5)
        )
    }

    private func weightLabel(_ w: Font.Weight) -> String {
        switch w {
        case .medium: return "Weight: Medium (500)"
        case .regular: return "Weight: Regular (400)"
        case .light: return "Weight: Light (300)"
        default: return "Weight"
        }
    }

    // MARK: - 模块 2：需求 2 卡片间距 4 档真实卡片全部平铺

    private var demand2AllCardsFlatSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                badge: "需求 2 全景平铺",
                title: "More 卡片间距与高度实测 (4 档完整卡片)",
                subtitle: "分类标签到 Activity 胶囊的垂直间距放宽实测：9.5pt 与 11.0pt 均完美保持 119pt 总高不变！"
            )
            .padding(.horizontal, AppTheme.Space.paddingPage)

            VStack(spacing: 18) {
                // 卡片 1: 基线 7.0pt
                flatCardItem(
                    tag: "【当前基线】",
                    spacingTitle: "间距 7.0pt · 容器高 119pt",
                    desc: "现状：分类名 (Food & Drink) 距离胶囊较近，视觉有粘连顶压感",
                    spacing: 7.0,
                    isHighlight: false,
                    heightBadge: "总高: 119pt (基线)"
                )

                // 卡片 2: 方案 2-A 9.5pt ⭐ 黄金推荐
                flatCardItem(
                    tag: "【方案 2-A ⭐ 黄金推荐】",
                    spacingTitle: "间距 9.5pt · 容器高 119pt (零高度惩罚！)",
                    desc: "增加 2.5pt 消除顶压感，利用内部 5pt 余量，卡片外框尺寸毫厘未变！",
                    spacing: 9.5,
                    isHighlight: true,
                    heightBadge: "总高: 119pt (不变)"
                )

                // 卡片 3: 方案 2-B 11.0pt
                flatCardItem(
                    tag: "【方案 2-B 临界分明】",
                    spacingTitle: "间距 11.0pt · 容器高 119pt (零高度惩罚！)",
                    desc: "增加 4.0pt，三段式结构（标题帽 / 胶囊群 / 词数注脚）界限极为清晰，卡片同样不增高！",
                    spacing: 11.0,
                    isHighlight: false,
                    heightBadge: "总高: 119pt (不变)"
                )

                // 卡片 4: 方案 2-C 13.0pt
                flatCardItem(
                    tag: "【方案 2-C 宽松舒展】",
                    spacingTitle: "间距 13.0pt · 容器高 ~121pt (微增 2pt)",
                    desc: "上下留白十分开阔，内容稍高突破 119pt，卡片轻度放行至 121pt",
                    spacing: 13.0,
                    isHighlight: false,
                    heightBadge: "总高: 121pt (增 2pt)"
                )
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    private func flatCardItem(
        tag: String,
        spacingTitle: String,
        desc: String,
        spacing: CGFloat,
        isHighlight: Bool,
        heightBadge: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tag)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isHighlight ? AppTheme.Color.brandStrong : AppTheme.Color.textSecondary)

                Text(spacingTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.Color.textPrimary)

                Spacer()

                Text(heightBadge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isHighlight ? Color.green.opacity(0.9) : AppTheme.Color.textMuted)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isHighlight ? Color.green.opacity(0.12) : AppTheme.Color.tab2ActivityChipBg, in: Capsule())
            }

            // 真实生产卡片组件
            CustomActivityCard(
                category: SandboxMockStore.foodCategory,
                categoryToActivitySpacing: spacing
            )

            Text(desc)
                .font(.system(size: 10.5))
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .padding(10)
        .background(isHighlight ? AppTheme.Color.brandStrong.opacity(0.03) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - 模块 3：整屏联合对比平铺 (横向滑动即看整页呼应)

    private var fullScreenComboFlatSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                badge: "整页联动平铺",
                title: "横向并排滑动 · 3 套组合全屏连带感受",
                subtitle: "左右滑动即可直接对比整页在不同组合下的上下呼吸节奏与视觉重量"
            )
            .padding(.horizontal, AppTheme.Space.paddingPage)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 16) {
                    // 组合 1：当前基线整页
                    fullPagePhoneMockup(
                        title: "组合 1 · 当前基线",
                        subtitle: "Words 12pt Medium (500) + 间距 7.0pt",
                        wordsWeight: .medium,
                        wordsSize: 12,
                        spacing: 7.0,
                        isHighlight: false
                    )

                    // 组合 2：推荐极细方案组合 ⭐
                    fullPagePhoneMockup(
                        title: "组合 2 · 极细轻灵 ⭐ (强烈推荐)",
                        subtitle: "Words 12pt Light (300) + 间距 9.5pt",
                        wordsWeight: .light,
                        wordsSize: 12,
                        spacing: 9.5,
                        isHighlight: true
                    )

                    // 组合 3：经典等宽同频组合
                    fullPagePhoneMockup(
                        title: "组合 3 · 匀质同频",
                        subtitle: "Words 12pt Regular (400) + 间距 9.5pt",
                        wordsWeight: .regular,
                        wordsSize: 12,
                        spacing: 9.5,
                        isHighlight: false
                    )
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.vertical, 8)
            }
        }
    }

    // 单个完整 iPhone 视口
    private func fullPagePhoneMockup(
        title: String,
        subtitle: String,
        wordsWeight: Font.Weight,
        wordsSize: CGFloat,
        spacing: CGFloat,
        isHighlight: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(isHighlight ? AppTheme.Color.brandStrong : AppTheme.Color.textPrimary)
                Spacer()
            }

            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.Color.textSecondary)

            // 内部滚动页面视口
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Color.clear.frame(height: 8)

                    // 1. Talk about today
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Talk about today")
                            .font(AppTheme.Font.sectionTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        Tab2HeroCard(
                            category: SandboxMockStore.heroCategory,
                            onTalk: {}
                        )
                    }

                    // 2. More to talk about (应用指定间距)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("More to talk about")
                            .font(AppTheme.Font.sectionTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        CustomActivityCard(
                            category: SandboxMockStore.foodCategory,
                            categoryToActivitySpacing: spacing
                        )
                    }

                    // 3. Topics in progress (应用指定 Words 字体)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Topics in progress")
                            .font(AppTheme.Font.sectionTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)

                        VStack(spacing: 0) {
                            simulatedProgressRow(
                                title: "Social & Feelings",
                                icon: "bubble.left.and.bubble.right",
                                count: 16,
                                size: wordsSize,
                                weight: wordsWeight
                            )
                            simulatedProgressRow(
                                title: "Health & Fitness",
                                icon: "figure.run",
                                count: 12,
                                size: wordsSize,
                                weight: wordsWeight
                            )
                        }
                        .padding(.vertical, AppTheme.Space.paddingS)
                        .surfaceCard(cornerRadius: AppTheme.Radius.large)
                    }

                    // 4. More topics to explore (落地后的 H-25 方案)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("More topics to explore")
                            .font(AppTheme.Font.sectionTitleSerif)
                            .foregroundStyle(AppTheme.Color.textPrimary)
                            .padding(.bottom, AppTheme.Tab2ExploreTopics.Layout.titleToTags)

                        Tab2MoreTopicsSection(
                            topics: [.homeFamily, .weather, .other, .homeFamily, .weather, .other]
                        )
                    }

                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 14)
            }
            .frame(width: 330, height: 640)
            .background(AppTheme.Color.pageBg)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isHighlight ? AppTheme.Color.brandStrong.opacity(0.6) : AppTheme.Color.cardBorder, lineWidth: isHighlight ? 1.5 : 0.8)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 8, y: 3)
        }
    }

    private func simulatedProgressRow(
        title: String,
        icon: String,
        count: Int,
        size: CGFloat,
        weight: Font.Weight
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: AppTheme.Size.categoryIconGlyph, weight: .regular))
                .foregroundStyle(AppTheme.Color.textMuted)
                .frame(width: AppTheme.Size.categoryBadge, height: AppTheme.Size.categoryBadge)

            Text(title)
                .font(AppTheme.Font.tab2TopicLabel) // 13pt Regular
                .foregroundStyle(AppTheme.Color.textPrimary)

            Spacer()

            HStack(spacing: AppTheme.Size.pillHSpacing) {
                Text(Tab2CardLabels.words(count))
                    .font(.system(size: size, weight: weight))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.Color.textSecondary)

                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: AppTheme.Size.expandArrow))
                    .foregroundStyle(AppTheme.Color.textMuted)
            }
            .padding(.horizontal, AppTheme.Size.pillHPad)
            .padding(.vertical, AppTheme.Size.pillVPad)
            .background(AppTheme.Color.tab2ProgressPillBg, in: Capsule())
            .overlay(Capsule().strokeBorder(AppTheme.Color.tab2ProgressPillBorder, lineWidth: 0.5))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func sectionHeader(badge: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(badge)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.Color.brandStrong)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.Color.brandStrong.opacity(0.12), in: Capsule())

                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppTheme.Color.textPrimary)
            }

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.Color.textSecondary)
        }
    }
}

// MARK: - 可变间距与高度实测的 CustomActivityCard (100% 生产像素级)

private struct CustomActivityCard: View {
    let category: Tab2CategoryData
    let categoryToActivitySpacing: CGFloat

    private var display: Tab2ActivityDisplay {
        Tab2ActivityDisplay.compute(category: category)
    }

    var body: some View {
        HStack(spacing: 0) {
            // 76pt 缩略图
            Color.clear
                .frame(width: AppTheme.Tab2MoreRow.Layout.thumbnailWidth)
                .overlay {
                    if let cover = category.activities.first?.cover, let url = cover.imageUrl {
                        CachedRemoteImage(
                            signedUrl: url,
                            stableKey: url,
                            placeholder: { Rectangle().fill(AppTheme.Color.imagePlaceholderBg) }
                        )
                        .clipped()
                        .saturation(AppTheme.Tab2MoreRow.ImageTreatment.photoSaturation)
                        .overlay(
                            Rectangle()
                                .fill(AppTheme.Color.tab2MoreRowPhotoToneWarm)
                                .blendMode(.multiply)
                                .opacity(AppTheme.Tab2MoreRow.Opacity.photoToneWarm)
                        )
                    } else {
                        Rectangle().fill(AppTheme.Color.imagePlaceholderBg)
                    }
                }
                .clipped()

            // 右侧内容区
            VStack(alignment: .leading, spacing: 0) {
                // 帽行 (分类名 + 时间)
                HStack(alignment: .firstTextBaseline) {
                    Text(category.englishLabel)
                        .font(AppTheme.Font.tab2MoreRowCategory)
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Spacer()

                    Text("Yesterday")
                        .font(AppTheme.Font.tab2MoreRowTimeline)
                        .foregroundStyle(AppTheme.Color.neutralFaint)
                }
                .padding(.trailing, AppTheme.Tab2MoreRow.Layout.hatRowTrailingInset)

                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 🌟 动态间距测试点
                        activityBlock
                            .padding(.top, categoryToActivitySpacing)

                        Text(Tab2CardLabels.words(category.wordCount))
                            .font(AppTheme.Font.tab2MoreRowMeta)
                            .foregroundStyle(AppTheme.Color.textMuted)
                            .monospacedDigit()
                            .padding(.top, AppTheme.Tab2MoreRow.Layout.activityToWords)
                    }
                    .padding(.trailing, AppTheme.Tab2MoreRow.Layout.contentTrailingInset)

                    Image(systemName: "arrow.right")
                        .font(.system(size: AppTheme.Tab2MoreRow.Layout.arrowGlyph, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .padding(.trailing, AppTheme.Tab2MoreRow.Layout.arrowTrailingInset)
                }
            }
            .padding(.top, AppTheme.Tab2MoreRow.Layout.contentTopInset)
            .padding(.bottom, AppTheme.Tab2MoreRow.Layout.contentBottomInset)
            .padding(.leading, AppTheme.Tab2MoreRow.Layout.contentLeadingInset)
        }
        .frame(minHeight: AppTheme.Tab2MoreRow.Layout.rowHeight) // 119pt
        .background(AppTheme.Color.warmGlassSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.large))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.large)
                .strokeBorder(AppTheme.Color.cardBorder, lineWidth: 0.5)
        )
        .overlay(alignment: .topTrailing) {
            // 右上角浮动高度标尺
            Text("间距 \(String(format: "%.1f", categoryToActivitySpacing))pt")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(AppTheme.Color.brandStrong)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.Color.brandStrong.opacity(0.12), in: Capsule())
                .padding(8)
        }
        .cardShadow()
    }

    private var activityBlock: some View {
        Tab2ActivityCapsuleGroup(
            activities: display.valid,
            activityCount: category.activityCount,
            blockedCount: display.blockedCount,
            metrics: Tab2ActivityCapsuleMetrics.more(),
            nameFont: AppTheme.Font.tab2MoreRowCapsuleName,
            moreFont: AppTheme.Font.tab2MoreRowCapsuleMore
        )
    }
}

// MARK: - 专属 Mock 数据

private enum SandboxMockStore {
    static var heroCategory: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: "Daily Routine",
            wordCount: 47,
            unlocked: true,
            notSpokenCount: 47,
            lastTalkedAt: nil,
            lastMaterialAt: Date(),
            newMaterialCount: 3,
            activityCount: 4,
            activities: [
                Tab2Activity(
                    sceneDetail: "Morning espresso at boutique cafe",
                    occurrenceCount: 3,
                    cover: Tab2Activity.Cover(
                        materialId: "m-hero-sb-1",
                        imageUrl: "https://images.unsplash.com/photo-1517256064527-09c73fc73e38?w=800&auto=format&fit=crop&q=80"
                    )
                ),
                Tab2Activity(sceneDetail: "Subway commute reading article", occurrenceCount: 2)
            ]
        )
    }

    static var foodCategory: Tab2CategoryData {
        Tab2CategoryData(
            sceneCategory: "Food & Drink",
            wordCount: 38,
            unlocked: true,
            notSpokenCount: 38,
            lastTalkedAt: nil,
            lastMaterialAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
            newMaterialCount: 2,
            activityCount: 5,
            activities: [
                Tab2Activity(
                    sceneDetail: "Dinner with old college friends",
                    occurrenceCount: 3,
                    cover: Tab2Activity.Cover(
                        materialId: "m-food-sb-1",
                        imageUrl: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400&auto=format&fit=crop&q=80"
                    )
                ),
                Tab2Activity(sceneDetail: "Baking banana bread", occurrenceCount: 2),
                Tab2Activity(sceneDetail: "Ordered iced latte", occurrenceCount: 1)
            ]
        )
    }
}

// MARK: - Xcode Canvas 预览入口

#Preview("全方案平铺展厅 · 零点击直接比对") {
    Tab2RefinementSandboxPreviewView()
}

#endif
