import SwiftUI

/// Conversation page — the practice execution surface launched from Tab2's category card (§4.1).
///
/// This is the container and state machine (§2). Step 1 content is fake data; real ASR and
/// backend connections arrive in steps 4–5 (§九 实现顺序).
///
/// Five states (§2):
///   permissionNeeded → MicPermissionView
///   preparing        → topic name + PreparingIndicator
///   active           → three-zone layout (§3)
///   failed           → same as active + inline error banner (dialogue NOT cleared, §2)
///   ended            → ConversationSummaryView
struct ConversationView: View {
    let sceneCategory: String

    @State private var vm: ConversationViewModel

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
                    MicPermissionView(onOpenSettings: { /* step 2 */ })
                        .transition(.opacity)

                case .preparing:
                    preparingView
                        .transition(.opacity)

                case .active:
                    activeLayout
                        .transition(.opacity)

                case .failed:
                    activeLayout
                        .overlay(alignment: .top) { errorBanner }
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

            // Debug state picker — visible in step 1 only so the PM can screenshot all 5 states
            debugStatePicker
        }
        .toolbar(.hidden, for: .navigationBar)
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

            // ── Zone 3: Bottom controls (~140–160 pt) ────────────
            bottomControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Dialogue scroll (Zone 2)

    private var dialogueScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.Space.paddingM) {
                    ForEach(vm.lines) { line in
                        DialogueLineRow(text: line.text, role: line.role)
                            .id(line.id)
                    }
                }
                .padding(.vertical, AppTheme.Space.paddingM)
            }
            .topEdgeFade()
            .onChange(of: vm.lines.count) { _, _ in
                // Auto-scroll to the newest line
                if let last = vm.lines.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
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

    // MARK: - Mic tap handler (stub — real logic in step 4)

    private func handleMicTap() {
        switch vm.micState {
        case .idle:       vm.micState = .listening
        case .listening:  vm.micState = .aiSpeaking
        case .aiSpeaking: vm.micState = .idle
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
