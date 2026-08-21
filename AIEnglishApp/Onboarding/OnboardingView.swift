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

/// 把「先保住唯一照片，再完成 onboarding」收敛成可注入、可单测的同步边界。
/// 远端同步仍沿用原来的 fire-and-forget；只有本地 pending 持久化是离开前硬门槛。
struct OnboardingCompletionCoordinator {
    let pendingRetryStore: PendingRetryStore
    let defaults: UserDefaults
    let setSyncPending: () -> Void
    let startRemoteSync: () -> Void

    @discardableResult
    func complete(viewModel: OnboardingViewModel, onComplete: () -> Void) -> Bool {
        do {
            if viewModel.hasUnconfirmedPhotoGeneration {
                guard let image = viewModel.selectedImage,
                      let requestId = viewModel.currentRequestId else {
                    throw AIServiceError.requestFailed
                }
                try pendingRetryStore.savePhoto(image, requestId: requestId)
            } else if viewModel.offlineFailureOccurred,
                      let card = viewModel.selectedCard,
                      !viewModel.presetSavedToServer {
                // 预设卡与照片共用同一套 request ID 生命周期：currentRequestId
                // 在 startWithCard 时生成，落库失败时随待重试记录一起持久化。
                guard let requestId = viewModel.currentRequestId else {
                    throw AIServiceError.requestFailed
                }
                pendingRetryStore.savePreset(cardId: card.id, imageName: card.imageName, requestId: requestId)
            }
        } catch {
            // 沿用现有常驻 generic 失败态；不新增文案，不允许写完成标记或离开。
            viewModel.errorKind = .generic
            return false
        }

        defaults.set(Date().timeIntervalSince1970, forKey: "onboarding_completed_at")

        // Preset card: build [userBubble(asset image) + aiCard] so Tab1 shows image + description.
        // Own photo: server already has the record or is represented by pending retry metadata.
        if let card = viewModel.selectedCard,
           let result = viewModel.generationResult,
           !viewModel.presetSavedToServer {
            let image = UIImage(named: card.imageName)
            OnboardingSeedStore.shared.entries = [
                .userBubble(text: "Describe this image", image: image, imageStableKey: card.imageName),
                .aiCard(result)
            ]
            // 幂等键随 seed 一起交接：弱网下服务器其实已落库（1.5s 竞速误判失败）时，
            // loadHistory 据此与服务端记录去重，避免首屏重复卡。
            OnboardingSeedStore.shared.requestId = viewModel.currentRequestId
        }

        setSyncPending()
        startRemoteSync()
        onComplete()
        return true
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
        OnboardingCompletionCoordinator(
            pendingRetryStore: .shared,
            defaults: .standard,
            setSyncPending: { ProfileService.setOnboardingSyncPending(true) },
            startRemoteSync: {
                Task {
                    do { try await ProfileService.markOnboardingComplete() }
                    catch { print("[Onboarding] ERROR remote sync failed: \(error)") }
                }
            }
        ).complete(viewModel: viewModel, onComplete: onComplete)
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
