//
//  PickUpSoccer_WatchApp.swift
//  PickUpSoccer Watch Watch App
//
//  Created by xc j on 6/24/25.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct PickUpSoccer_Watch_Watch_AppApp: App {
    
    init() {
        // MARK: - 核心修正
        // 在 App 的 init() 方法中，立即初始化 WatchConnectivityManager。
        // 这确保了无论 App 在前台还是后台启动，WCSession 的代理都能被第一时间设置。
        _ = WatchConnectivityManager.shared
        
        // 请求通知权限的逻辑保持不变
        requestNotificationAuthorization()
    }
    
    var body: some Scene {
        WindowGroup {
            // ContentView 的逻辑是正确的，无需修改
            ContentView()
        }
        .modelContainer(for: [WatchMatchSession.self, WatchPlayer.self, WatchMatchEvent.self])
    }
    
    private func requestNotificationAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("⌚️ 通知权限已获取")
            } else if let error = error {
                print("⌚️ 获取通知权限失败: \(error.localizedDescription)")
            }
        }
    }
}



