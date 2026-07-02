import SwiftUI

struct MineView: View {
    @State private var vm = MineViewModel()
    @State private var showVocabBook = false

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Mine")
            .task { await vm.loadScenes() }
            .onAppear { Task { await vm.loadScenesIfStale() } }
            .navigationDestination(isPresented: $showVocabBook) {
                VocabBookView(vocabCount: vm.vocabCount)
            }
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
                    showVocabBook = true
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
                            NavigationLink {
                                SceneDetailView(material: material, onDelete: {
                                    Task { await vm.deleteMaterial(material) }
                                })
                            } label: { EmptyView() }
                                .opacity(0)
                            SceneCardRow(scene: scene)
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
        }
    }
}

#Preview {
    MineView()
}
