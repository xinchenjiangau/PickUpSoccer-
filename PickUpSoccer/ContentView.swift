//
//  ContentView.swift
//  PickUpSoccer
//
//  Created by xc j on 2/17/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    // --- 状态变量 ---
    // 用于控制“完善球员资料”页面的弹出
    @State private var showUserPlayerSheet = false
    
    // 用于控制后续的Alert和Sheet
    @State private var isShowingMigrationAlert = false
    @State private var isShowingSeasonEditor = false
    @State private var seasonToClaim: Season? = nil

    var body: some View {
        TabView {
            MatchesView()
                .tabItem { Label("比赛", systemImage: "soccerball") }
            
            LeaderboardView()
                .tabItem { Label("排行榜", systemImage: "list.number") }
            
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .onAppear(perform: startOnboardingIfNeeded)
        .sheet(isPresented: $showUserPlayerSheet, onDismiss: {
            // 当“完善资料”页面被关闭后，再调用数据迁移检查
            authManager.checkForMigration()
        }) {
            // 确保UserPlayerView能被注入AuthManager
            UserPlayerView().environmentObject(authManager)
        }
        .onChange(of: authManager.migrationState) { oldValue, newValue in
            // 监听迁移状态的变化，以弹出Alert
            if case .needsAdminConfirmation(let season) = newValue {
                self.seasonToClaim = season
                self.isShowingMigrationAlert = true
            }
        }
        .alert("发现本地数据", isPresented: $isShowingMigrationAlert, presenting: seasonToClaim) { season in
            Button("打包并成为管理员") {
                // 用户同意后，才弹出赛季编辑页
                self.isShowingSeasonEditor = true
            }
            Button("忽略", role: .cancel) {
                authManager.declineMigration()
            }
        } message: { season in
            Text("我们发现了您设备上的历史比赛数据。您想将它们打包到一个新赛季并由您管理吗？")
        }
        .sheet(isPresented: $isShowingSeasonEditor, onDismiss: {
            // 当赛季编辑页关闭后，正式完成管理员身份认领
            if let season = seasonToClaim {
                authManager.claimAdminRole(for: season, withName: authManager.currentPlayer?.name)
            }
        }) {
            if let season = seasonToClaim {
                SeasonEditView(season: season)
            }
        }
    }
    
    private func startOnboardingIfNeeded() {
        // 检查球员资料是否完整，如果未完成，弹出 UserPlayerView
        if authManager.isLoggedIn && !(authManager.currentPlayer?.isProfileComplete ?? false) {
            self.showUserPlayerSheet = true
        } else if authManager.isLoggedIn {
            // 如果资料是完整的（或非首次启动），才去检查数据迁移
            authManager.checkForMigration()
        }
    }
}

//#Preview {
//    ContentView()
//        .modelContainer(for: Item.self, inMemory: true)
//}
