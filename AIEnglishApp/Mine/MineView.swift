import SwiftUI

/// Mine 内部导航目的地。用 Material.id（UUID, Hashable）而非整个 Material，
/// 避免给 Material 加 Hashable；push/pop 会同步改写 path，便于即时联动顶栏显隐。
private enum MineRoute: Hashable {
    case scene(UUID)
    case vocab
}

struct MineView: View {
    var listResetToken: UUID = UUID()
    @Binding var swipeActionOpen: Bool
    @Binding var detailActive: Bool
    /// 全局浮层顶栏的实测高度：本视图有独立 NavigationStack，会吞掉父层
    /// safeAreaInset，需在自己内部预留等高空位，避免内容被顶栏盖住
    var topInset: CGFloat = 0
    @State private var vm = MineViewModel()
    @State private var path: [MineRoute] = []

    init(
        listResetToken: UUID = UUID(),
        swipeActionOpen: Binding<Bool> = .constant(false),
        detailActive: Binding<Bool> = .constant(false),
        topInset: CGFloat = 0
    ) {
        self.listResetToken = listResetToken
        self._swipeActionOpen = swipeActionOpen
        self._detailActive = detailActive
        self.topInset = topInset
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if vm.isLoading && vm.scenes.isEmpty {
                    // 首次加载（无历史数据）才显示骨架屏，数量用上次缓存的 count
                    List {
                        ForEach(0..<vm.skeletonCount, id: \.self) { _ in
                            SkeletonCardRow()
                        }
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
                } else if vm.errorMessage != nil && vm.scenes.isEmpty {
                    // 只在没有任何数据时才显示错误状态，有数据时静默失败
                    VStack(spacing: AppTheme.Space.paddingCard) {
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(AppTheme.Color.textSecondary)
                        Text("Failed to load")
                            .font(.headline)
                        Button("Retry") {
                            Task { await vm.loadScenes() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if vm.scenes.isEmpty {
                    ContentUnavailableView(
                        "No materials yet",
                        systemImage: "books.vertical",
                        description: Text("Share a moment in Today — your materials will appear here.")
                    )
                } else {
                    sceneList
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await vm.loadScenes() }
            .onAppear { Task { await vm.loadScenesIfStale() } }
            // path 变化即 push/pop 发生的同一帧 —— 顶栏据此即时显隐，无延迟闪现
            .onChange(of: path) { _, newPath in
                detailActive = !newPath.isEmpty
            }
            .safeAreaInset(edge: .top, spacing: 0) { topInsetBar }
            .toast(message: Binding(get: { vm.toastMessage }, set: { vm.toastMessage = $0 }),
                   systemImage: "exclamationmark.triangle")
            .navigationDestination(for: MineRoute.self) { destination(for: $0) }
            .overlay(alignment: .bottom) {
                if vm.lastDeletedMaterial != nil {
                    UndoToast(message: "Deleted") {
                        Task { await vm.restoreMaterial() }
                    }
                    .padding(.bottom, AppTheme.Space.paddingPage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: vm.lastDeletedMaterial != nil)
        }
    }

    @ViewBuilder
    private func destination(for route: MineRoute) -> some View {
        switch route {
        case .scene(let id):
            if let material = vm.scenes.first(where: { $0.id == id }) {
                SceneDetailView(material: material, onDelete: {
                    Task { await vm.deleteMaterial(material) }
                })
            }
        case .vocab:
            VocabBookView(vocabCount: vm.vocabCount)
        }
    }

    // 顶部预留区：全局浮层顶栏等高空位
    private var topInsetBar: some View {
        Color.clear.frame(height: topInset)
    }

    private var sceneList: some View {
        VStack(spacing: 0) {
            // 情境筛选栏 + 词汇本入口（同一行）
            HStack(spacing: 0) {
                ContextFilterBar(
                    categories: vm.availableCategories,
                    selected: $vm.selectedCategory
                )
                .animation(.easeInOut(duration: 0.3), value: vm.availableCategories.count)

                // 词汇本胶囊（常驻最右侧）
                Button {
                    Analytics.track("vocab_book_opened", properties: ["vocab_count": vm.vocabCount])
                    path.append(.vocab)
                } label: {
                    Text(vm.vocabCount > 0 ? "Vocab \(vm.vocabCount)" : "Vocabulary")
                        .font(.subheadline)
                        .padding(.horizontal, AppTheme.Space.paddingCard)
                        .padding(.vertical, AppTheme.Space.paddingXS)
                        .background(AppTheme.Color.cardBg)
                        .foregroundStyle(AppTheme.Color.textSecondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.trailing, AppTheme.Space.paddingCard)
                .padding(.vertical, AppTheme.Space.paddingXS)
            }

            List {
                ForEach(vm.filteredScenes) { material in
                    if case .scene(let scene) = material.rawContent {
                        ZStack {
                            // 隐形 value-based link：整行可点、无默认 disclosure 箭头，
                            // 且 push 时同步写入 path（供顶栏即时联动）
                            NavigationLink(value: MineRoute.scene(material.id)) { EmptyView() }
                                .opacity(0)
                            SceneCardRow(materialId: material.id, scene: scene)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await vm.deleteMaterial(material) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
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
            .id(listResetToken)
            .simultaneousGesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if value.translation.width < -30 { swipeActionOpen = true }
                    }
                    .onEnded { value in
                        if value.translation.width > 30 { swipeActionOpen = false }
                    }
            )
        }
    }
}

#Preview {
    MineView()
}
