import SwiftUI
import SwiftData

@main
struct PickUpSoccerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Player.self,
            Match.self,
            MatchEvent.self,
            PlayerMatchStats.self,
            Season.self
        ])
        
        // 关键：启用自动迁移 (isStoredInMemoryOnly = false)
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            print("❌ 数据库初始化失败: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                // [关键修复] 在这里注入数据库容器，打通手表通信与存储的桥梁
                .onAppear {
                    print("🚀 初始化 WatchConnectivityManager...")
                    WatchConnectivityManager.shared.configure(with: sharedModelContainer)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
