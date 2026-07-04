import SwiftUI

struct TodayView: View {
    @State private var viewModel = TodayViewModel(service: LiveAIService())
    @State private var inputText = ""
    @State private var previewImage: UIImage?

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            timeline
                .navigationTitle("Today")
                .safeAreaInset(edge: .bottom) {
                    InputBar(text: $inputText, image: $vm.pendingImage, isLoading: viewModel.isLoading) {
                        let toSend = inputText
                        inputText = ""
                        Task { await viewModel.send(toSend) }
                    }
                }
        }
        .overlay {
            if let img = previewImage {
                ImagePreview(image: img) {
                    withAnimation(.spring(duration: 0.3)) { previewImage = nil }
                }
                .transition(.scale(scale: 0.1, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: previewImage != nil)
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppTheme.Space.paddingCard) {
                    ForEach(viewModel.entries) { entry in
                        TimelineRow(entry: entry, onImageTap: { img in
                            withAnimation(.spring(duration: 0.35)) { previewImage = img }
                        })
                        .id(entry.id)
                    }
                }
                .padding(AppTheme.Space.paddingPage)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .onChange(of: viewModel.entries.count) {
                if let last = viewModel.entries.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }
}

#Preview {
    TodayView()
}
