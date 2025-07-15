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
    @State private var showUserPlayerSheet = false

    var body: some View {
        TabView {
            MatchesView()
                .tabItem {
                    Label("比赛", systemImage: "soccerball")
                }
            
            LeaderboardView()
                .tabItem {
                    Label("排行榜", systemImage: "list.number")
                }
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
        .onAppear {
            // 检查用户是否已登录并且资料是否完整
            if authManager.isLoggedIn {
                if let player = authManager.currentPlayer, !player.isProfileComplete {
                    showUserPlayerSheet = true
                }
            }
        }
        .sheet(isPresented: $showUserPlayerSheet) {
            UserPlayerView()
                .environmentObject(authManager)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
