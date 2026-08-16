import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case screen1, screen2, screen4
}

/// 只裁横向、向下留出余量不裁的矩形：三页并排横滑仍需要在左右边界处硬切掉相邻页，
/// 但底边要延伸出屏幕，让内容能贯穿到物理屏底而不是在安全区下沿被切断。
private struct HorizontalClipRect: Shape {
    var extraBottom: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height + extraBottom))
    }
}

struct OnboardingView: View {
    @State private var step: OnboardingStep = .screen1
    @State private var viewModel = OnboardingViewModel()
    var onComplete: () -> Void

    private var index: Int { step.rawValue }  // screen1=0, screen2=1, screen4=2

    var body: some View {
        ZStack(alignment: .bottom) {
            OnboardingAuraBackground()
            
            // Offset-based paging: all pages sit side by side in one HStack and
            // we slide the whole strip left/right. No insert/remove transitions,
            // so direction is always correct and pages never overlap or ghost.
            GeometryReader { geo in
                HStack(spacing: 0) {
                    OnboardingScreen1View(isActive: step == .screen1, onForward: advance)
                        .frame(width: geo.size.width, height: geo.size.height)

                    OnboardingScreen2View(isActive: step == .screen2, onBack: back, onForward: advance)
                        .frame(width: geo.size.width, height: geo.size.height)

                    OnboardingCaptureView(
                        viewModel: viewModel,
                        isActive: step == .screen4,
                        onBack: back,
                        onComplete: completeOnboarding
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(width: geo.size.width, alignment: .leading)
                .offset(x: -CGFloat(index) * geo.size.width)
                .animation(.easeInOut(duration: 0.35), value: step)
            }
            // 只裁横向（隐藏并排偏移出的相邻页），向下留出大量余量不裁——
            // 让各页内容能贯穿到物理屏底，而不是在安全区下沿被齐刷刷切断。
            .clipShape(HorizontalClipRect(extraBottom: 400))
        }
    }

    private func advance() {
        let cases = OnboardingStep.allCases
        guard let idx = cases.firstIndex(of: step), idx + 1 < cases.count else { return }
        step = cases[idx + 1]
    }

    private func back() {
        let cases = OnboardingStep.allCases
        guard let idx = cases.firstIndex(of: step), idx > 0 else { return }
        step = cases[idx - 1]
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "onboarding_completed_at")
        // Preset card: build [userBubble(asset image) + aiCard] so Tab1 shows image + description.
        // Own photo: server already has the record; leave seed empty, loadHistory() handles it.
        // 已成功落库的预设卡不再注入 seed——服务端记录会被 loadHistory 拉到，再注入就重复了。
        if let card = viewModel.selectedCard, let result = viewModel.generationResult,
           !viewModel.presetSavedToServer {
            let image = UIImage(named: card.imageName)
            OnboardingSeedStore.shared.entries = [
                .userBubble(text: "Describe this image", image: image, imageStableKey: card.imageName),
                .aiCard(result)
            ]
        }
        // 断网离开：写待重试记录（预设卡未落库 / 照片未生成），Tab1 展示并可 Retry。
        // 仅断网档写——被拒同图重试必再被拒、其它档罕见，MVP 只覆盖断网场景。
        // 用粘性标记而非瞬时 errorKind：网络恢复会清掉 errorKind（toast 下线），
        // 若离开时仍按 errorKind 判断，照片会在「恢复后、离开前」的窗口内丢失。
        if viewModel.offlineFailureOccurred {
            // 不变式防御：已落库的预设卡不写待重试记录（当前不可达，防未来加「原地重试」时回归）。
            if let card = viewModel.selectedCard, !viewModel.presetSavedToServer {
                PendingRetryStore.shared.savePreset(cardId: card.id, imageName: card.imageName)
            } else if let image = viewModel.selectedImage, viewModel.generationResult == nil {
                try? PendingRetryStore.shared.savePhoto(image)
            }
        }
        // 先记账再销账：远端打标成功（markOnboardingComplete 成功分支）才清待办。
        // 这样即使下面的 Task 来不及执行（如点完立刻杀 app）或断网失败，
        // 待办仍在，下次启动自动补发——不依赖打标 Task 是否真正跑到。
        ProfileService.setOnboardingSyncPending(true)
        Task {
            do { try await ProfileService.markOnboardingComplete() }
            catch { print("[Onboarding] ERROR remote sync failed: \(error)") }
        }
        onComplete()
    }
}

// MARK: - Horizontal swipe helper

extension View {
    /// Detects horizontal swipes. `onLeft` = swipe finger left (advance),
    /// `onRight` = swipe finger right (back). Uses simultaneousGesture so it
    /// coexists with buttons (taps don't move) and ScrollViews (vertical drags
    /// are ignored via the horizontal guard).
    ///
    /// `ignoredFrames`: rects (in this view's coordinate space) where the paging
    /// gesture must NOT fire — e.g. a horizontal sample carousel. A swipe that
    /// *starts* inside one of these rects belongs to the ScrollView, otherwise
    /// scrolling the samples would also flip the page.
    func onHorizontalSwipe(
        threshold: CGFloat = 60,
        ignoredFrames: @escaping () -> [CGRect] = { [] },
        onLeft: @escaping () -> Void = {},
        onRight: @escaping () -> Void = {}
    ) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let start = value.startLocation
                    guard !ignoredFrames().contains(where: { $0.contains(start) }) else { return }
                    let w = value.translation.width
                    let h = value.translation.height
                    guard abs(w) > abs(h) else { return }
                    if w <= -threshold { onLeft() }
                    else if w >= threshold { onRight() }
                }
        )
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
