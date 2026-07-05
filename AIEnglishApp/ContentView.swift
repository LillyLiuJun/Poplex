import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }
            MineView()
                .tabItem {
                    Label("Mine", systemImage: "person.crop.circle")
                }
        }
    }
}

#Preview {
    ContentView()
}
