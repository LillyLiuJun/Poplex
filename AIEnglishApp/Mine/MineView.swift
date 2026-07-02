import SwiftUI

struct MineView: View {
    @State private var vm = MineViewModel()
    @State private var showVocabBook = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = vm.errorMessage {
                    ContentUnavailableView(
                        "Failed to load",
                        systemImage: "wifi.slash",
                        description: Text(err)
                    )
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
            .task { await vm.loadScenes() }          // 首次加载
            .onAppear { Task { await vm.loadScenesIfStale() } } // 切 Tab 时刷新（防抖30s）
            .navigationDestination(isPresented: $showVocabBook) {
                VocabBookView(vocabCount: vm.vocabCount)
            }
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

                // 词汇本胶囊（常驻最右侧）
                Button {
                    showVocabBook = true
                } label: {
                    Text(vm.vocabCount > 0 ? "词汇本 \(vm.vocabCount)" : "词汇本")
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

            Divider()

            ScrollView {
                LazyVStack(spacing: AppTheme.Space.paddingCard) {
                    ForEach(vm.filteredScenes) { material in
                        if case .scene(let scene) = material.rawContent {
                            NavigationLink {
                                SceneDetailView(material: material)
                            } label: {
                                SceneCardRow(scene: scene)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Space.paddingPage)
                .padding(.vertical, AppTheme.Space.paddingCard)
            }
        }
    }
}

#Preview {
    MineView()
}
