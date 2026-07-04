import SwiftUI

struct TodayView: View {
    @State private var viewModel = TodayViewModel(service: LiveAIService())
    @State private var inputText = ""

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
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppTheme.Space.paddingCard) {
                    ForEach(viewModel.entries) { entry in
                        TimelineRow(entry: entry)
                            .id(entry.id)
                    }

                }
                .padding(AppTheme.Space.paddingPage)
            }
            .scrollDismissesKeyboard(.interactively)
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
