import SwiftUI

struct TodayView: View {
    // 已接真后端：调用 Supabase Edge Function，由它在服务器端带 Key 调用 Gemini。
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

    // Layer 1：顶部固定栏，极简、居中标题
    private var header: some View {
        Text("Today")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Space.paddingCard)
    }

    // Layer 2：中部滚动时间线，最新消息在最底部，发送后自动滚到底
    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppTheme.Space.paddingCard) {
                    ForEach(viewModel.messages) { message in
                        MessageRow(message: message)
                            .id(message.id)
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
            .onChange(of: viewModel.messages.count) {
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }
}

#Preview {
    TodayView()
}
