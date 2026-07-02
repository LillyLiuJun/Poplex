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

                // 词汇本胶囊（常驻最右侧）
                Button {
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
