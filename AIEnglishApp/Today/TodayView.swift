import SwiftUI

struct TodayView: View {
    @State private var viewModel = TodayViewModel(service: LiveAIService())
    @State private var inputText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            timeline
        }
        .safeAreaInset(edge: .bottom) {
            InputBar(text: $inputText, isLoading: viewModel.isLoading) {
                let toSend = inputText
                inputText = ""
                Task { await viewModel.send(toSend) }
            }
        }
    }

    private var header: some View {
        Text("Today")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Space.paddingCard)
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppTheme.Space.paddingCard) {
                    ForEach(viewModel.entries) { entry in
                        TimelineRow(entry: entry)
                            .id(entry.id)
                    }

                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .id("loading")
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Color.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(AppTheme.Space.paddingPage)
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
