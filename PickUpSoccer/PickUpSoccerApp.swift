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
    // 1. 将容器和管理器声明为属性
    let sharedModelContainer: ModelContainer
    @StateObject var authManager: AuthManager
    @StateObject private var coordinator = NavigationCoordinator()

    init() {
        do {
            // 2. 在init中创建Schema和Configuration
            let schema = Schema([
                Item.self,
                Match.self,
                Player.self,
                MatchEvent.self,
                Season.self,
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

            // 3. 创建并赋值给属性
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.sharedModelContainer = container
            
            // 4. 使用StateObject包装器创建AuthManager的唯一实例
            _authManager = StateObject(wrappedValue: AuthManager(modelContext: container.mainContext))

        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        // WatchConnectivityManager的配置保持不变
        //WatchConnectivityManager.shared.configure(with: sharedModelContainer)
        WatchConnectivityManager.shared.configure(with: sharedModelContainer, coordinator: self.coordinator)
    }

    var body: some Scene {
        WindowGroup {
            RootView() // RootView现在变得非常干净
                .environmentObject(coordinator)
                // 5. 从这里将唯一的AuthManager实例注入到所有子视图
                .environmentObject(authManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
