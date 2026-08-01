import SwiftUI

/// Conversation page — the practice execution surface launched from Tab2's category card (§4.1).
///
/// State machine (§2):
///   permissionNeeded → MicPermissionView (mic / speech-rec denied)
///   preparing        → topic name + PreparingIndicator (permission OK, awaiting session)
///   active           → three-zone layout (§3)
///   failed           → active + inline error banner at foot of chat
///   ended            → ConversationSummaryView
///
/// Step 2 wires real permission checks; Steps 4–5 add ASR + backend.
struct ConversationView: View {
    let sceneCategory: String

    @State private var vm: ConversationViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(sceneCategory: String) {
        self.sceneCategory = sceneCategory
        self._vm = State(wrappedValue: ConversationViewModel(sceneCategory: sceneCategory))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.Color.pageBg.ignoresSafeArea()

            // Main state switcher
            Group {
                switch vm.pageState {
                case .permissionNeeded:
                    MicPermissionView(onOpenSettings: vm.openSettings)
                        .transition(.opacity)

                case .preparing:
                    preparingView
                        .transition(.opacity)

                case .active:
                    activeLayout
                        .transition(.opacity)

                case .failed:
                    failedLayout
                        .transition(.opacity)

                case .ended:
                    ConversationSummaryView(
                        sceneCategory: sceneCategory,
                        onDismiss: { /* step 8: pop to Tab2 + force refresh */ }
                    )
                    .transition(.opacity)
                }
            }
            .animation(AppTheme.Motion.tabSelection, value: vm.pageState)

            // Debug state picker — lets PM switch all 5 states without a build
            debugStatePicker
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { vm.cancelListening() }
        .task { await vm.checkPermissions() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await vm.checkPermissions() } }
        }
    }

    // MARK: - Preparing (§4.3)

    private var preparingView: some View {
        VStack(spacing: 0) {
            // Back button still reachable even while loading
            ConversationTopBar(topicName: sceneCategory, onDismiss: { /* pop */ })

            Spacer()
            PreparingIndicator()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Active / Failed — three-zone layout (§3)

    private var activeLayout: some View {
        conversationLayout(errorBetweenZones: false)
    }

    private var failedLayout: some View {
        conversationLayout(errorBetweenZones: true)
    }

    @ViewBuilder
    private func conversationLayout(errorBetweenZones: Bool) -> some View {
        VStack(spacing: 0) {
            // ── Zone 1: Top bar (44 pt) ──────────────────────────
            ConversationTopBar(
                topicName: vm.sceneDetail,
                onDismiss: {
                    withAnimation(AppTheme.Motion.tabSelection) {
                        vm.pageState = .ended
                    }
                }
            )

            // ── Zone 2: Dialogue flow (fills remaining space) ────
            dialogueScrollView

            // ── Error notice (failed state only) — sits at the foot of the chat ──
            if errorBetweenZones {
                errorBanner
            }

            // ── Zone 3: Bottom controls (~140–160 pt) ────────────
            bottomControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Dialogue scroll (Zone 2)

    private var dialogueScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // VStack (not Lazy) so all items are laid out immediately —
                // required for scrollTo to work reliably on first appear.
                VStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
                    ForEach(vm.lines) { line in
                        DialogueLineRow(text: line.text, role: line.role)
                            .id(line.id)
                    }
                }
                .padding(.vertical, AppTheme.Space.paddingM)
                .padding(.bottom, AppTheme.Space.paddingCard)
            }
            .topEdgeFade()
            .onAppear {
                // Snap to last item without animation on first load.
                proxy.scrollTo(vm.lines.last?.id, anchor: .bottom)
            }
            .onChange(of: vm.lines.count) { _, _ in
                withAnimation { proxy.scrollTo(vm.lines.last?.id, anchor: .bottom) }
            }
        }
    }

    // MARK: - Bottom controls (Zone 3)

    private var bottomControls: some View {
        VStack(spacing: 0) {
            SuggestionsBar(
                suggestions: vm.suggestions,
                isExpanded: $vm.isSuggestionsExpanded
            )

            VStack(spacing: AppTheme.Space.paddingS) {
                MicButton(state: vm.micState, onTap: handleMicTap)
                    .padding(.top, AppTheme.Space.paddingM)

                NativeFallbackButton(onTap: { /* step 6 */ })
                    .padding(.bottom, AppTheme.Space.paddingCard)
            }
        }
        .background(AppTheme.Color.pageBg)
    }

    // MARK: - Error banner (failed state)

    private var errorBanner: some View {
        HStack(spacing: AppTheme.Space.paddingS) {
            Image(systemName: "wifi.slash")
                .font(AppTheme.Font.sectionLabel)
                .foregroundStyle(AppTheme.Color.textSecondary)
            Text("Couldn't reach the server — your words are saved.")
                .font(AppTheme.Font.buddy)
                .foregroundStyle(AppTheme.Color.textSecondary)
            Spacer()
            Button("Retry") {
                withAnimation(AppTheme.Motion.tabSelection) {
                    vm.pageState = .active
                }
            }
            .font(AppTheme.Font.sectionLabel)
            .foregroundStyle(AppTheme.Color.brandDefault)
        }
        .padding(.horizontal, AppTheme.Space.paddingPage)
        .padding(.vertical, AppTheme.Space.paddingM)
        .background(AppTheme.Color.brandSubtleBg)
    }

    // MARK: - Mic tap handler (Step 4 — real ASR)

    private func handleMicTap() {
        switch vm.micState {
        case .idle:       vm.startListening()
        case .listening:  vm.stopListening()
        case .aiSpeaking: vm.interruptAI()
        case .disabled:   break
        }
    }

    // MARK: - Debug state picker (step 1 only — lets PM screenshot all five states)

    private var debugStatePicker: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Space.paddingS) {
                    Text("DEBUG")
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(AppTheme.Color.textFaint)
                        .padding(.leading, AppTheme.Space.paddingM)

                    ForEach(ConversationPageState.allCases, id: \.self) { state in
                        Button(debugLabel(for: state)) {
                            withAnimation(AppTheme.Motion.tabSelection) {
                                vm.pageState = state
                                // Seed mic state from page state for visual clarity
                                if state == .active { vm.micState = .idle }
                                if state == .failed { vm.micState = .disabled }
                            }
                        }
                        .font(AppTheme.Font.sectionLabel)
                        .foregroundStyle(
                            vm.pageState == state
                            ? AppTheme.Color.brandStrong
                            : AppTheme.Color.textMuted
                        )
                        .padding(.horizontal, AppTheme.Space.paddingM)
                        .padding(.vertical, AppTheme.Space.paddingS)
                        .background(
                            vm.pageState == state
                            ? AppTheme.Color.brandSubtleBg
                            : AppTheme.Color.pageBg,
                            in: Capsule()
                        )
                    }

                    Divider().frame(height: 16)

                    // "+ Line" — appends a fake dialogue line to test auto-scroll-to-bottom
                    Button("+ Line") {
                        vm.debugAddLine()
                    }
                    .font(AppTheme.Font.sectionLabel)
                    .foregroundStyle(AppTheme.Color.textMuted)
                    .padding(.horizontal, AppTheme.Space.paddingM)
                    .padding(.vertical, AppTheme.Space.paddingS)
                    .background(AppTheme.Color.pageBg, in: Capsule())
                    .padding(.trailing, AppTheme.Space.paddingM)
                }
                .padding(.horizontal, AppTheme.Space.paddingS)
                .padding(.vertical, AppTheme.Space.paddingS)
            }
            .background(.regularMaterial)
        }
    }

    private func debugLabel(for state: ConversationPageState) -> String {
        switch state {
        case .permissionNeeded: return "perm"
        case .preparing:        return "prep"
        case .active:           return "active"
        case .failed:           return "failed"
        case .ended:            return "ended"
        }
    }
}

#Preview {
    NavigationStack {
        ConversationView(sceneCategory: "工作与学业")
    }
}
