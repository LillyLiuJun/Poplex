import SwiftUI

private enum MineRoute: Hashable {
    case conversation(sceneCategory: String)
}

struct MineView: View {
    var listResetToken: UUID = UUID()      // kept for RootTabContainer compat
    @Binding var swipeActionOpen: Bool
    @Binding var detailActive: Bool
    var topInset: CGFloat = 0
    /// Called when user taps "Capture something" in locked state — switches to Tab1
    var onSwitchToToday: (() -> Void)? = nil

    @State private var vm = Tab2HomeViewModel()
    @State private var path: [MineRoute] = []

    init(
        listResetToken: UUID = UUID(),
        swipeActionOpen: Binding<Bool> = .constant(false),
        detailActive: Binding<Bool> = .constant(false),
        topInset: CGFloat = 0,
        onSwitchToToday: (() -> Void)? = nil
    ) {
        self.listResetToken = listResetToken
        self._swipeActionOpen = swipeActionOpen
        self._detailActive = detailActive
        self.topInset = topInset
        self.onSwitchToToday = onSwitchToToday
    }

    var body: some View {
        NavigationStack(path: $path) {
            mainContent
                .toolbar(.hidden, for: .navigationBar)
                .task { await vm.load() }
                .onChange(of: listResetToken) { _, _ in
                    Task { await vm.load() }
                }
                .onChange(of: path) { _, newPath in
                    detailActive = !newPath.isEmpty
                }
                .onChange(of: vm.isPermanentlyUnlocked) { _, newValue in
                    if newValue {
                        withAnimation(AppTheme.Motion.tabSelection) {}
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    Color.clear.frame(height: topInset)
                }
                .toast(
                    message: Binding(get: { vm.toastMessage }, set: { vm.toastMessage = $0 }),
                    systemImage: "exclamationmark.triangle"
                )
                .navigationDestination(for: MineRoute.self) { route in
                    switch route {
                    case .conversation(let cat):
                        ConversationStubView(sceneCategory: cat)
                    }
                }
        }
    }

    // MARK: - State machine

    @ViewBuilder
    private var mainContent: some View {
        if vm.isLoading && vm.data == nil {
            skeletonView
        } else if vm.errorMessage != nil && vm.data == nil {
            ConnectionRetryView { Task { await vm.load() } }
        } else if vm.isPermanentlyUnlocked {
            Tab2UnlockedView(
                vm: vm,
                onTalk: { cat in path.append(.conversation(sceneCategory: cat)) }
            )
        } else {
            Tab2LockedView(
                vm: vm,
                onCapture: { onSwitchToToday?() }
            )
        }
    }

    private var skeletonView: some View {
        List {
            ForEach(0..<4, id: \.self) { _ in SkeletonCardRow() }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(
                    top: AppTheme.Space.paddingCard / 2,
                    leading: AppTheme.Space.paddingPage,
                    bottom: AppTheme.Space.paddingCard / 2,
                    trailing: AppTheme.Space.paddingPage
                ))
        }
        .listStyle(.plain)
    }
}

// MARK: - Locked view

private struct Tab2LockedView: View {
    let vm: Tab2HomeViewModel
    let onCapture: () -> Void

    private let inputTarget = 5
    private let wordTarget  = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingPage) {
                headerSection
                inputsSection
                areasSection
                captureButton
            }
            .padding(.vertical, AppTheme.Space.paddingPage)
        }
        .background(AppTheme.Color.pageBg)
    }

    // ── 待解锁 header ────────────────────────────────────────────────────
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
            Text("LOCKED")
                .font(AppTheme.Font.sectionLabel)
                .foregroundStyle(AppTheme.Color.textMuted)
                .padding(.horizontal, AppTheme.Space.paddingPage)

            RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                .fill(Color(.systemGray6))
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "lock")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(AppTheme.Color.textMuted)
                )
                .padding(.horizontal, AppTheme.Space.paddingPage)

            VStack(alignment: .leading, spacing: AppTheme.Space.paddingXS) {
                Text("Not open yet")
                    .font(AppTheme.Font.hero)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                hintText
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    // hint 分两段渲染，让 tab 名 "Capture" 加粗，区别于普通正文
    private var hintText: some View {
        Text("Add 5 moments in ")
            .font(AppTheme.Font.englishBody)
            .foregroundStyle(AppTheme.Color.textSecondary)
        + Text("Capture")
            .font(AppTheme.Font.englishBody).bold()
            .foregroundStyle(AppTheme.Color.textSecondary)
        + Text(". Reach 20 words in any topic to start practicing.")
            .font(AppTheme.Font.englishBody)
            .foregroundStyle(AppTheme.Color.textSecondary)
    }

    // ── INPUTS progress ─────────────────────────────────────────────────
    private var inputsSection: some View {
        let count  = vm.data?.inputCount ?? 0
        let fill   = min(CGFloat(count) / CGFloat(inputTarget), 1.0)
        return VStack(alignment: .leading, spacing: AppTheme.Space.paddingS) {
            sectionHeader("MOMENTS", note: "\(count) of \(inputTarget)")
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.Color.brandStrong)
                        .frame(width: geo.size.width * fill, height: 4)
                        .animation(.easeOut(duration: 0.4), value: count)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, AppTheme.Space.paddingPage)
        }
    }

    // ── AREAS list ───────────────────────────────────────────────────────
    private var areasSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("AREAS", note: "Any one reaching 20 opens it.")
                .padding(.bottom, AppTheme.Space.paddingS)

            let cats  = categoriesWithWords
            let topId = closestCategory?.id
            ForEach(cats) { cat in
                CategoryProgressRow(
                    category: cat,
                    isHighlighted: cat.id == topId,
                    loadWords: { await vm.loadCategoryWords(for: cat.sceneCategory) }
                )
                Divider()
                    .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            if cats.isEmpty {
                Text("Capture a moment to get started.")
                    .font(AppTheme.Font.englishBody)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.vertical, AppTheme.Space.paddingCard)
            }
        }
    }

    // ── CTA ──────────────────────────────────────────────────────────────
    private var captureButton: some View {
        let isReady = vm.isReadyToUnlock
        return Button {
            if isReady {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                vm.confirmUnlock()
            } else {
                onCapture()
            }
        } label: {
            Text(isReady ? "You're all set" : "Capture something")
                .font(AppTheme.Font.ctaLabel)
                .foregroundStyle(AppTheme.Color.cardBg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.Color.brandStrong)
                .clipShape(Capsule())
                .animation(.easeInOut(duration: 0.2), value: isReady)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    private var categoriesWithWords: [Tab2CategoryData] {
        (vm.data?.categories ?? []).filter { $0.wordCount >= 1 }
    }

    private var closestCategory: Tab2CategoryData? {
        categoriesWithWords.max(by: { $0.wordCount < $1.wordCount })
    }

    private func sectionHeader(_ title: String, note: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppTheme.Space.paddingS) {
            Text(title)
                .font(AppTheme.Font.sectionLabel)
                .foregroundStyle(AppTheme.Color.textMuted)
            Text(note)
                .font(AppTheme.Font.pos)
                .foregroundStyle(AppTheme.Color.textMuted)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
    }
}

// MARK: - Unlocked view

private struct Tab2UnlockedView: View {
    let vm: Tab2HomeViewModel
    let onTalk: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Space.paddingCard) {
                Text("Talk about something")
                    .font(AppTheme.Font.screenTitle)
                    .foregroundStyle(AppTheme.Color.textPrimary)
                    .padding(.horizontal, AppTheme.Space.paddingPage)
                    .padding(.top, AppTheme.Space.paddingPage)

                contentSections
            }
            .padding(.bottom, AppTheme.Space.paddingPage)
        }
        .background(AppTheme.Color.pageBg)
        .onAppear {
            // 首次解锁动效：已在 vm.isPermanentlyUnlocked onChange 触发；
            // 解锁文案出现后 0.5 s 标记已展示，防止再次显示
            if vm.isFirstUnlock {
                Task {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    vm.markFirstUnlockShown()
                }
            }
        }
    }

    @ViewBuilder
    private var contentSections: some View {
        if let data = vm.data {
            let hero    = vm.heroCategory()
            let heroId  = hero?.id

            // Hero 卡
            if let hero {
                Tab2HeroCard(
                    category: hero,
                    isFirstUnlock: vm.isFirstUnlock,
                    onTalk: { onTalk(hero.sceneCategory) }
                )
                .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // 其他已解锁分类行
            let otherUnlocked = data.categories.filter { $0.unlocked && $0.id != heroId }
            ForEach(otherUnlocked) { cat in
                Tab2CategoryRow(
                    category: cat,
                    onTalk: { onTalk(cat.sceneCategory) }
                )
                Divider()
                    .padding(.horizontal, AppTheme.Space.paddingPage)
            }

            // Still filling up
            let stillFilling = data.categories.filter { !$0.unlocked && $0.wordCount >= 1 }
            if !stillFilling.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text("STILL FILLING UP")
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .padding(.horizontal, AppTheme.Space.paddingPage)
                        .padding(.top, AppTheme.Space.paddingCard)

                    ForEach(stillFilling) { cat in
                        CategoryProgressRow(
                            category: cat,
                            isHighlighted: false,
                            loadWords: { await vm.loadCategoryWords(for: cat.sceneCategory) }
                        )
                        Divider()
                            .padding(.horizontal, AppTheme.Space.paddingPage)
                    }
                }
            }
        }
    }
}

// MARK: - Conversation stub (E1 placeholder — replaced when voice dialogue is built)

private struct ConversationStubView: View {
    let sceneCategory: String
    @Environment(\.dismiss) private var dismiss

    private var englishLabel: String {
        SceneCategory(rawValue: sceneCategory)?.englishLabel ?? sceneCategory
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AppTheme.Color.pageBg.ignoresSafeArea()

            VStack(spacing: AppTheme.Space.paddingCard) {
                Spacer()

                Image(systemName: "waveform.circle")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(AppTheme.Color.brandStrong.opacity(0.4))

                VStack(spacing: AppTheme.Space.paddingS) {
                    Text(englishLabel)
                        .font(AppTheme.Font.screenTitle)
                        .foregroundStyle(AppTheme.Color.textPrimary)

                    Text("Voice practice is coming soon.")
                        .font(AppTheme.Font.englishBody)
                        .foregroundStyle(AppTheme.Color.textMuted)
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)

            // Close button — top-left, always reachable
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(AppTheme.Color.textSecondary)
                    .frame(width: AppTheme.Size.barControl, height: AppTheme.Size.barControl)
                    .background(AppTheme.Color.cardBg)
                    .clipShape(Circle())
                    .shadow(
                        color: AppTheme.Shadow.cardColor,
                        radius: AppTheme.Shadow.cardRadius / 2,
                        x: AppTheme.Shadow.cardX,
                        y: AppTheme.Shadow.cardY
                    )
            }
            .buttonStyle(.plain)
            .padding(.leading, AppTheme.Space.paddingPage)
            .padding(.top, AppTheme.Space.paddingCard)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    MineView()
}
