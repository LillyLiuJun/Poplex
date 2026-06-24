import SwiftUI

struct TodayView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Content coming soon",
                systemImage: "sparkles",
                description: Text("Capture a moment from your day to get started.")
            )
            .navigationTitle("Today")
        }
    }
}

#Preview {
    TodayView()
}
