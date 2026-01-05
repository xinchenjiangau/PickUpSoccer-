import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 使用 @State 来持有 AuthManager
    @State private var authManager: AuthManager?
    
    // 查询数据用于迁移检测
    @Query private var allMatches: [Match]
    @Query private var seasons: [Season]
    
    @State private var showMigrationAlert = false
    
    var body: some View {
        Group {
            if let manager = authManager {
                // 传递给子视图
                RootContent(authManager: manager)
            } else {
                // 初始化 AuthManager 前的加载状态
                LaunchScreenView()
            }
        }
        .onAppear {
            // 1. 初始化 AuthManager
            if authManager == nil {
                authManager = AuthManager(modelContext: modelContext)
            }
            
            // 2. 执行数据迁移检查
            checkAndMigrateData()
        }
        .alert("数据升级", isPresented: $showMigrationAlert) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("检测到旧版本的历史数据，已自动将其归档至“历史赛季”。您可以在设置中管理赛季。")
        }
    }
    
    // MARK: - 数据迁移逻辑
    private func checkAndMigrateData() {
        let oldMatches = allMatches.filter { $0.season == nil }
        
        if !oldMatches.isEmpty {
            print("开始迁移数据，旧比赛数量: \(oldMatches.count)")
            
            // A. 查找或创建 "历史赛季"
            let historySeason: Season
            if let existing = seasons.first(where: { $0.name == "历史赛季" }) {
                historySeason = existing
            } else {
                let start = Date.distantPast
                let end = Date()
                // Season 初始化 (根据您的 Model 定义)
                historySeason = Season(name: "历史赛季", startDate: start, endDate: end)
                modelContext.insert(historySeason)
            }
            
            // B. 将旧比赛关联到该赛季
            for match in oldMatches {
                match.season = historySeason
            }
            
            do {
                try modelContext.save()
                showMigrationAlert = true
            } catch {
                print("迁移失败: \(error)")
            }
        }
    }
}

// MARK: - 子视图 (RootContent)
struct RootContent: View {
    @ObservedObject var authManager: AuthManager
    
    var body: some View {
        // 使用独立属性分离逻辑，解决 ViewBuilder 推断错误
        contentView
            .environmentObject(authManager)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if authManager.isLoggedIn {
            // 已登录状态的处理逻辑
            if let player = authManager.currentPlayer {
                if player.isProfileComplete {
                    // ✅ 修正点：这里必须是 View，所以用 ContentView()，而不是 NavigationCoordinator
                    ContentView()
                } else {
                    // 资料不完整，进入设置页
                    SettingsView()
                }
            } else {
                // 异常情况：有 ID 但找不到 Player 对象，进入设置页重建
                SettingsView()
            }
        } else {
            // 未登录状态
            LoginView()
        }
    }
}
