import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // 第一个标签：比赛
            MatchesView()
                .tabItem {
                    Label("比赛", systemImage: "sportscourt")
                }
            
            // 第二个标签：排行榜
            LeaderboardView()
                .tabItem {
                    Label("排行榜", systemImage: "list.number")
                }
            
            // 第三个标签：设置
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
    }
}

#Preview {
    ContentView()
}
