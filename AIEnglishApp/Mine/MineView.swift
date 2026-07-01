import SwiftUI

struct MineView: View {
    @State private var vm = MineViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = vm.errorMessage {
                    ContentUnavailableView(
                        "加载失败",
                        systemImage: "wifi.slash",
                        description: Text(err)
                    )
                } else if vm.scenes.isEmpty {
                    ContentUnavailableView(
                        "还没有素材",
                        systemImage: "books.vertical",
                        description: Text("在 Today 页面输入生活场景，素材会自动出现在这里。")
                    )
                } else {
                    sceneList
                }
            }
            .navigationTitle("Mine")
            .task { await vm.loadScenes() }
        }
    }

    private var sceneList: some View {
        VStack(spacing: 0) {
            ContextFilterBar(
                categories: vm.availableCategories,
                selected: $vm.selectedCategory
            )

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
