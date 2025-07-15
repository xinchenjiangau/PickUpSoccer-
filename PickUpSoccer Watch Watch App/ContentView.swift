//
//  ContentView.swift
//  PickUpSoccer Watch Watch App
//
//  Created by xc j on 6/24/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // 查询当前是否有状态为 active 的比赛会话
    @Query(filter: #Predicate<WatchMatchSession> { session in
        session.isActive == true
    }) private var activeSessions: [WatchMatchSession]
    
    var body: some View {
        // MARK: - 最终修正
        // 根据是否有活动的比赛会话，决定显示哪个视图
        if let activeSession = activeSessions.first {
            // 如果有比赛，加载我们包含了 TabView 的容器视图 MatchSessionView
            MatchSessionView(session: activeSession)
        } else {
            // 如果没有比赛，显示等待视图
            WaitingForMatchView()
        }
    }
}


