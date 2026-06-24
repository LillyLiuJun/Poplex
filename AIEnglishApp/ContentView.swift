import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                TodayView()
            }
            Tab("Mine", systemImage: "person.crop.circle") {
                MineView()
            }
        }
    }
}

#Preview {
    ContentView()
}
