//
//  PickUpSoccerApp.swift
//  PickUpSoccer
//
//  Created by xc j on 2/17/25.
//

import SwiftUI
import SwiftData

@main
struct PickUpSoccerApp: App {
    // 1. 获取 SwiftData 的 ModelContainer
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Match.self,
            Player.self,
            MatchEvent.self,
            Season.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()


    init() {
        // 2. 在App初始化时，将 ModelContainer 交给 WatchConnectivityManager
        // 这样它就能在后台处理来自手表的数据了
        WatchConnectivityManager.shared.configure(with: sharedModelContainer)
        
    }
    @StateObject private var coordinator = NavigationCoordinator()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
        }
        .modelContainer(sharedModelContainer)
    }
}
