//
//  MatchSessionView.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//
import SwiftUI

struct MatchSessionView: View {
    @Bindable var session: WatchMatchSession

    var body: some View {
        TabView {
            // MARK: - 恢复到最初始的状态
            // 默认加载 EventRecordingView
            EventRecordingView(session: session)
                .tag(0)
            
            // 右滑页面：时间轴 (保持不变)
            WatchTimelineView(session: session)
                .tag(1)

            // 左滑页面：比赛操作 (保持不变)
            MatchActionsView(session: session)
                .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

