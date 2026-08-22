import SwiftUI

/// Onboarding 第二页：机制说明 —— 回答"它是怎么工作的"。
/// 结构 = 文案（怎么做）+ 「捕捉瞬间」视觉拼贴（照片 / 语音 / 打字，用真实的输入形态本身
/// 呈现三种输入，而非图标+文字清单）+ 单一 CTA。
///
/// 三张卡演的必须是**输入进行时**，不是已归档的素材：
/// - 照片卡：照片 + AI 读出来的那句话
/// - 语音卡：mic + 轻微起伏的波形 + 跑动的计时 + 正在转写的半句
/// - 文字卡：一张正在写的便签（悬浮卡材质 + 光标 + 具体时刻）
///
/// 三处示意文案统一用 `Font.onboardingCollageNote`（15/regular）+ `textSecondary`：
/// 它们是「让人认出这是什么输入」的示意，不是要读的内容——用 17pt 主色会让三张卡
/// 同时抢主标题的注意力，整页发重。
struct OnboardingScreen2View: View {
    var isActive: Bool = true
    var onBack: () -> Void
    var onForward: () -> Void

    @State private var appeared = false
    @State private var cursorVisible = true
    /// 波形是否在脉动。静止值 false = 满高，是正确的静态呈现（见 startAmbientMotion）。
    @State private var wavePulsing = false
    @State private var scrollOffset: CGFloat = 0
    /// 拼贴墨迹的实测包围盒（见 CollageInk）。种子值 = 上一版真机实测，
    /// 保证首帧不跳；真正生效的是运行时算出来的值。
    @State private var ink = CollageInk.seed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// 语音条声波的柱高（固定示意波形，16 根流畅起伏波形，两端对称收尾）。
    private let waveHeights: [CGFloat] = [7, 14, 22, 11, 19, 9, 16, 23, 12, 18, 14, 21, 10, 16, 11, 7]

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        // 标题顶部位置只由 onboardingHeaderTop 一个数决定（N-1 单一真源）。
                        textBlock
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                            .padding(.top, AppTheme.Size.onboardingHeaderTop)
                            .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.05)

                        // 标题组→拼贴墨迹上沿。容器已与墨迹对齐（见 capturedMomentsCollage），
                        // 这个数就是眼睛看到的距离。**不与 S3a 的 24 同档**，理由见 token 注释：
                        // S3a 接的是低对比虚线框，S2 接的是带照片的实心卡，重量不同、余量就不同。
                        Spacer().frame(height: AppTheme.Space.onboardingCollageTop)

                        capturedMomentsCollage(
                            availableWidth: geo.size.width - AppTheme.Space.paddingPage * 2
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, AppTheme.Space.paddingPage)

                        Spacer()
                    }
                    .padding(.bottom, AppTheme.Size.onboardingContentBottomClearance) // Give space for the absolute bottom button
                    .frame(minHeight: geo.size.height) // Full height
                    .onboardingScrollOffsetProbe()   // iOS 17 走 PreferenceKey 兜底，iOS 18+ 无副作用
                }
                .scrollBounceBehavior(.basedOnSize)
                .onboardingScrollOffsetTracking($scrollOffset)
            }

            // 顶部渐隐随滚动出现（F-4）：静止时标题完整，一滚才吃掉标题顶部。
            OnboardingTopFade(scrollOffset: scrollOffset)

            OnboardingBottomFade()

            OnboardingPrimaryButton(title: "Continue", action: onForward)
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.bottom, AppTheme.Size.onboardingContinueBottom)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.5)
        }
        .overlay(alignment: .topLeading) {
            OnboardingBackButton(action: onBack)
                .padding(.top, AppTheme.Size.onboardingBackInset)
                .padding(.leading, AppTheme.Size.onboardingBackLeading)
        }
        .contentShape(Rectangle())
        .onHorizontalSwipe(onLeft: onForward, onRight: onBack)
        // 三页并排渲染，onAppear 在 onboarding 一启动就会对三页同时触发——
        // 入场动画和氛围动画都必须挡在 isActive 后面，否则用户还没滑到过这一页，
        // 这里的 repeatForever 就已经在后台跑了。
        .onAppear {
            guard isActive else { return }
            triggerEntrance()
            startAmbientMotion()
        }
        .onChange(of: isActive) { _, active in
            if active {
                triggerEntrance()
                startAmbientMotion()
            } else {
                // 三页并排常驻挂载，离开这一页不会被卸载 —— 不主动停的话，
                // 光标 + 10 根波形柱共 11 条 repeatForever 会在后台一直跑。
                stopAmbientMotion()
            }
        }
    }

    private func triggerEntrance() {
        guard !appeared else { return }
        DispatchQueue.main.async {
            appeared = true
        }
    }

    /// 打字光标闪烁 + 语音波形起伏：延到下一帧翻转，配合 repeatForever 起搏。
    ///
    /// 两个 flag 的**静止值就是正确的呈现**（光标常亮、波形满高），动画是在此之上叠加的：
    /// 这样「没访问过」「reduceMotion」「已离开」三种不跑动画的情况，画面都自然是对的，
    /// 不需要任何补偿。上一版把波形的静止态设成 0.78 的压缩态，于是必须无条件把 flag
    /// 翻上去才不难看，反过来又堵死了「不 start」这条路 —— 极性反了，两个需求就打架。
    private func startAmbientMotion() {
        guard !reduceMotion else { return }
        DispatchQueue.main.async {
            cursorVisible = false
            wavePulsing = true
        }
    }

    /// 离开本页时收掉动画。必须用 disablesAnimations 的事务改回去 ——
    /// 直接赋值会被同一个 repeatForever 再次接管，等于没停。
    private func stopAmbientMotion() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            cursorVisible = true
            wavePulsing = false
        }
    }

    // MARK: - 文案区：标题 + 一句机制说明

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.onboardingTitleToLead) {
            Text("Share your context, in any format.")
                .font(AppTheme.Font.pageTitleSerif)
                .tracking(AppTheme.Typography.trackingDisplay)
                .foregroundStyle(AppTheme.Color.textPrimary)

            Text("Drop a photo, speak, or type. AI does the rest.")
                .font(AppTheme.Font.onboardingLeadSerif)
                .lineSpacing(AppTheme.Typography.lineBody)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 「捕捉瞬间」拼贴：三张真实输入形态，轻微倾斜叠放，错峰入场

    private func capturedMomentsCollage(availableWidth: CGFloat) -> some View {
        // 兜底缩放：墨迹一旦比可用宽度宽，整块等比缩到装得下为止。
        // 这一层和 dynamicTypeSize 是两道独立的防线，缺一不可：
        //   - dynamicTypeSize 管「字号别把卡撑大」，是因；
        //   - 这一层管「无论什么原因宽了，都不许画到页面外」，是果。
        // 只有前者时，任何一次改文案／换机型／未来某个 SwiftUI 行为变化，都可能让卡片
        // 越过页边 —— 而这一页是横滑分页的一屏，越界的部分会直接画到隔壁页上（真机实拍
        // 就是这个症状：S2 的卡片出现在 S3a 上）。等比缩放保住构图，比裁切或换行都合适。
        let fitScale = min(1, availableWidth / max(ink.size.width, 1))

        return ZStack {
            photoCard
                .collagePiece(.photo)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.16)

            voiceCard
                .collagePiece(.voice)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.28)

            textCard
                .collagePiece(.text)
                .onboardingEntrance(appeared: appeared, reduceMotion: reduceMotion, delay: 0.40)
        }
        // 容器 = 墨迹。三卡都靠 .offset 摆位，而 offset 不参与布局，ZStack 的自然高度只等于
        // 最大那张卡 —— 此前靠写死 400 撑出容器，容器与墨迹成了两套账：调间距调的是容器、
        // 眼睛看的是墨迹。CollageInk 在运行时按「各卡实测尺寸 + 旋转角 + offset」算出真实
        // 包围盒，容器取它的高、内容按它的中心回正。
        // 这样做而不是继续写死常数，是因为卡里现在有随 Dynamic Type 变长的句子——
        // 任何一版常数都会在下一次改文案时失效。
        //
        // 收集必须挂在 ZStack 上而不是各张卡上：preference 沿视图树向上合并，
        // 挂在卡上每张只看得见自己的尺寸，算出来的包围盒会缺另外两张。
        .onPreferenceChange(CollagePieceSizeKey.self) { sizes in
            guard let next = CollageInk.compute(from: sizes) else { return }
            if next != ink { ink = next }
        }
        .frame(width: ink.size.width, height: ink.size.height)
        .offset(x: -ink.center.x, y: -ink.center.y)
        // 等比缩放 + 按缩放后的尺寸占位（scaleEffect 只改渲染、不改布局，
        // 不补这一层 frame，下方内容会按未缩放的高度让位）。
        .scaleEffect(fitScale, anchor: .center)
        .frame(width: ink.size.width * fitScale, height: ink.size.height * fitScale)
        // 拼贴是一张**插图**，不是可读内容 —— 卡上那三行字是「让人认出这是什么输入」的
        // 构图元素。因此整块不参与 Dynamic Type。
        //
        // 不这么做会破版，而且是没法靠调数补救的那种：卡宽是定值、卡片靠固定 pt 的
        // .offset 摆位，字号一放大，卡只能往高里长、往宽里挤 —— 卡片互相盖住文字、
        // 便签卡（宽度按内容）直接顶出屏幕右缘。这正是「只允许叠边缘、不许压字」那条
        // 规则在大字号下必然失守的原因：规则是按默认字号的几何核对出来的。
        //
        // VoiceOver 不受此限制（它读的是文本本身，不看字号），所以可访问性没有倒退；
        // 真正需要放大阅读的信息在标题和副标里，那两处照常跟随 Dynamic Type。
        .dynamicTypeSize(DynamicTypeSize.large)
    }

    // MARK: 照片卡 —— 照片 + 你当时写下的那句话
    // 此前是居中斜体的 `morning coffee`：那读起来是文件名/标签，属于「素材归档」的语义，
    // 而这一页要说的是「你把一个时刻交给它」。改成左对齐的完整句子、正体、textPrimary。

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            // 取景窗上移 22：源图是竖图（768×1376），fill 到 224 宽后高 401，
            // 居中裁只留中间 150，正好切在她的发顶。把图往下推 22 = 取景窗上移 22，
            // 头顶留出余量。
            // 用「定尺容器 + overlay + clipped」而不是 frame(alignment: .top)：
            // 后者只能贴到最顶（露出天花板），这里要的是「中间偏上」而不是「最上」。
            Color.clear
                .frame(width: 224, height: 140)
                .overlay {
                    Image("onboarding_hero")
                        .resizable()
                        .scaledToFill()
                        .offset(y: 22)
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))

            // AI 看见这张照片时会说的话。放不下就在第二行截断带省略号——
            // 这里要的是「它读懂了」的观感，不是让人把整句读完。
            VStack(alignment: .leading, spacing: 2) {
                Text("A woman in a simple linen top")
                    .font(AppTheme.Font.onboardingCollageNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("sits across...")
                        .font(AppTheme.Font.onboardingCollageNote)
                        .foregroundStyle(AppTheme.Color.textSecondary)

                    Spacer(minLength: 8)

                    Text("Today · 8:02 AM")
                        .font(AppTheme.Font.pos)
                        .foregroundStyle(AppTheme.Color.textMuted)
                }
            }
            .frame(width: 224)
        }
        .padding(AppTheme.Space.paddingS)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .collageShadow()
    }

    // MARK: 语音卡 —— 正在录，不是回放
    // 此前是 play.fill + 静态波形 + 时长：那是「已经录好的一段」的回放控件，方向反了。
    // 现在：mic + 起伏波形 + 跑动的计时 + 正在转写的半句（与文字卡的光标同一种进行时语气）。

    private var voiceCard: some View {
        HStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(AppTheme.Color.brandStrong)
                    .frame(width: 30, height: 30)
                Image(systemName: "mic.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.Color.textOnChip)
            }

            Spacer(minLength: AppTheme.Space.paddingS)

            HStack(spacing: 3) {
                ForEach(Array(waveHeights.enumerated()), id: \.offset) { index, h in
                    Capsule()
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: 3, height: h)
                        .scaleEffect(y: wavePulsing ? 0.78 : 1.0, anchor: .center)
                        .animation(
                            reduceMotion ? nil :
                                .easeInOut(duration: 0.9)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.05),
                            value: wavePulsing
                        )
                }
            }
            .frame(height: 26)

            Spacer(minLength: AppTheme.Space.paddingS)

            Text("0:04 · 8:09 AM")
                .font(AppTheme.Font.pos)
                .monospacedDigit()
                .foregroundStyle(AppTheme.Color.textMuted)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, AppTheme.Space.paddingCard)
        .padding(.vertical, AppTheme.Space.paddingM)
        .frame(width: 270)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .collageShadow()
    }

    // MARK: 文字卡 —— 一张正在写的便签
    // 上一版把它做成了输入框材质（inputBg + 描边）并删掉了时间戳，理由是「时间戳 = 已发送
    // 的消息，与光标矛盾」。真机上看，输入框材质让它从拼贴里掉出来——三张卡是一堆随手摞着
    // 的碎片，其中一张长成控件就不成堆了。改回悬浮卡材质。
    //
    // 时间戳与光标的矛盾也因此消解：矛盾只存在于「聊天气泡」这个读法里。恢复成悬浮卡之后
    // 它读作便签（同 Apple Notes——正在编辑的笔记照样显示日期），时间戳是这条记录的时间，
    // 不是发送回执。时间戳因此保留，并从 `now` 换成具体时刻。
    //
    // 不写死具体日期（`Aug 18`）：示意图里的硬编码日期会随时间显得陈旧，而
    // 「Today · 时刻」既具体又不会过期。

    private var textCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Let's align on the details before")
                .font(AppTheme.Font.onboardingCollageNote)
                .foregroundStyle(AppTheme.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("diving into")
                    .font(AppTheme.Font.onboardingCollageNote)
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(AppTheme.Color.brandStrong)
                    .frame(width: 2, height: 15)
                    .opacity(cursorVisible ? 1 : 0)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.55).repeatForever(autoreverses: true),
                        value: cursorVisible
                    )

                Spacer(minLength: 8)

                Text("Today · 8:14 AM")
                    .font(AppTheme.Font.pos)
                    .foregroundStyle(AppTheme.Color.textMuted)
            }
        }
        // 宽度按内容收缩。⚠️ 这里必须用 fixedSize 而不是 frame(maxWidth:)——
        // SwiftUI 的 maxWidth 语义是「最多可以撑到」，带 maxWidth 的 frame 会接受父级
        // 提议的宽度并一直撑到上限，实测卡宽一点没变（仍是 232+32=264）。
        // fixedSize(horizontal:) 才是「取内容的理想宽度」。
        // 便签本来就该跟着写了多少字长，不是一条定长的槽；写死时它是三张里最宽的一张，
        // 而内容最少，左沿还是全堆最突出的点。
        .fixedSize(horizontal: true, vertical: false)
        .padding(AppTheme.Space.paddingCard)
        .background(AppTheme.Color.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.medium))
        .collageShadow()
    }
}

// MARK: - 拼贴墨迹的运行时测量

/// 三张卡在拼贴里的固定摆位（角度与相对容器中心的偏移）。
/// 只有这三组数是「构图」，其余（容器高、整体回正量）都由 CollageInk 算出来。
private enum CollagePieceKind: Int, CaseIterable {
    case photo, voice, text

    var angle: Double {
        switch self {
        case .photo: return -5
        case .voice: return 4
        case .text:  return -2
        }
    }

    // 摆位规则：**只允许卡与卡的边缘/内边距相叠，绝不允许盖住任何一行字。**
    // 上一版 voice y=36 时，语音卡的上沿落在照片卡注脚第二行上，把 "top sits acro…" 盖掉了
    // 一截 —— 叠放是为了读作「一堆碎片」，一旦吃掉文字就变成「挡住了」。
    //
    //
    // ── 横向 ──────────────────────────────────────────────────────────────────
    // 横向的账不能只看外框：外框居中 ≠ 视觉居中。照片是全页唯一的大色块，它偏哪边，
    // 眼睛就觉得整堆往哪边倒 —— 所以最重的照片卡要靠近中轴，左右两个极值交给**轻**的
    // 那两张卡去够。
    // ⚠️ offset **不等于**该带最终偏离中轴的量：容器会按墨迹包围盒再整体回正一次，
    //    所以带中心 = 中轴 + offset − 包围盒中心。上一版按 offset 直接推算，结果
    //    实测每带都比预期左 10。要算落点必须把这一步算进去。
    // 另一条经验：眼睛看的是**每一行**的位置，不是总账。曾经出现过「面积重心和外框
    // 中心都压在中轴上、但没有任何一行是居中的」——三张卡的带中心一左一右地锯齿摆动，
    // 读起来就是「不平衡」。收摆动会让整堆变窄，补偿办法是把卡加宽：卡越宽，同样的
    // 横向覆盖需要的 offset 越小。
    //
    //   photo  卡 240×222.6 / 旋转后 258×242.7  →  x −149.2 … 109.2，y −241.3 …   1.3
    //   voice  卡 264×82.3  / 旋转后 269×100.5  →  x −108.5 … 160.5，y    6.7 … 107.3
    //   text   卡 ≈278×70.3 / 旋转后 280×80.0   →  x −160.1 … 120.1，y  107.0 … 187.0
    // 居中后带中心：照片 180.8 / 语音 226.8 / 便签 180.8 —— **上下两张同轴、中间一张
    // 偏右**，读作一个稳定的错位，而不是「左→右→左」的锯齿（那一版最大摆动 36）。
    // 墨迹 ≈ 321×428，居中后左右各余 20.7；下沿约 674，距遮罩顶（688）约 14。
    // 上沿与 S3a 虚线框同线（标题组 +24）。
    // 照片改高度时 voice / text 必须同量上移，否则上下两对的相邻关系会不一致。
    // 整堆的宽只由「最左那张的左沿」和「最右那张的右沿」两点决定，夹在中间的卡再宽也不影响。
    // ⚠️ 改动任一张卡的内容或字号后，这三组数要重新按上面的方式核一遍——
    //    旋转会让四个角各自升降 8–9pt，光看卡高判断不了会不会压字。
    var offset: CGSize {
        switch self {
        case .photo: return CGSize(width: -20, height: -120)
        case .voice: return CGSize(width:  26, height:   57)
        case .text:  return CGSize(width: -20, height:  147)
        }
    }
}

/// 拼贴墨迹的包围盒：尺寸 + 中心相对容器中心的偏移。
struct CollageInk: Equatable {
    var size: CGSize
    var center: CGPoint

    /// 首帧种子（上一版真机实测值），避免测量落地前出现一帧的错位。
    static let seed = CollageInk(size: CGSize(width: 302, height: 396),
                                 center: CGPoint(x: -13, y: -17))
}

private struct CollagePieceSizeKey: PreferenceKey {
    static var defaultValue: [Int: CGSize] = [:]
    static func reduce(value: inout [Int: CGSize], nextValue: () -> [Int: CGSize]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private extension View {
    /// 摆位 + 上报未旋转尺寸。旋转是渲染变换、不改变布局尺寸，因此包围盒必须由
    /// 「尺寸 + 角度」解析算出，而不能指望 GeometryReader 直接给出旋转后的框。
    func collagePiece(_ kind: CollagePieceKind) -> some View {
        self
            .background(
                GeometryReader { geo in
                    Color.clear.preference(
                        key: CollagePieceSizeKey.self,
                        value: [kind.rawValue: geo.size]
                    )
                }
            )
            .rotationEffect(.degrees(kind.angle))
            .offset(x: kind.offset.width, y: kind.offset.height)
    }
}

extension CollageInk {
    /// 由各卡的未旋转尺寸解析出整堆墨迹的包围盒。
    /// 旋转后包围盒：w' = w·|cosθ| + h·|sinθ|，h' = w·|sinθ| + h·|cosθ|。
    static func compute(from sizes: [Int: CGSize]) -> CollageInk? {
        var minX = CGFloat.greatestFiniteMagnitude, maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        var found = false

        for kind in CollagePieceKind.allCases {
            guard let size = sizes[kind.rawValue], size.width > 0, size.height > 0 else { continue }
            found = true
            let radians = kind.angle * .pi / 180
            let c = abs(cos(radians)), s = abs(sin(radians))
            let halfW = (size.width * c + size.height * s) / 2
            let halfH = (size.width * s + size.height * c) / 2
            minX = min(minX, kind.offset.width - halfW)
            maxX = max(maxX, kind.offset.width + halfW)
            minY = min(minY, kind.offset.height - halfH)
            maxY = max(maxY, kind.offset.height + halfH)
        }

        guard found else { return nil }
        return CollageInk(
            size: CGSize(width: maxX - minX, height: maxY - minY),
            center: CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        )
    }
}

// 拼贴碎片共用的柔和悬浮阴影。
private extension View {
    func collageShadow() -> some View {
        shadow(color: AppTheme.Shadow.cardColor, radius: 16, x: 0, y: 8)
    }
}

#Preview {
    OnboardingScreen2View(onBack: {}, onForward: {})
}
