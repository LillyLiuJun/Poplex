import SwiftUI

struct MineView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "No content yet",
                systemImage: "books.vertical",
                description: Text("Materials you generate will be organized here.")
            )
            .navigationTitle("Mine")
        }
    }
}

#Preview {
    MineView()
}
