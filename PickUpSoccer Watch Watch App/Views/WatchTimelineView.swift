//
//  WatchTimelineView.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import SwiftUI
import SwiftData

struct WatchTimelineView: View {
    @Bindable var session: WatchMatchSession
    
    // The query will be initialized dynamically based on the session.
    @Query var events: [WatchMatchEvent]
    
    init(session: WatchMatchSession) {
        self.session = session
        let sessionId = session.persistentModelID
        
        // 修正: 为 #Predicate 添加明确的类型 <WatchMatchEvent>
        // 并使用一个有名字的参数 `event` 来提高可读性
        self._events = Query(
            filter: #Predicate<WatchMatchEvent> { event in
                event.matchSession?.persistentModelID == sessionId
            },
            sort: [SortDescriptor(\.timestamp, order: .reverse)]
        )
    }

    var body: some View {
        VStack {
            Text("比赛事件")
                .font(.headline)
                .padding(.bottom, 2)
            
            if events.isEmpty {
                Spacer()
                ContentUnavailableView("暂无事件", systemImage: "clock.badge.xmark")
                Spacer()
            } else {
                // 优化: 使用自定义的 EventRowView 来显示事件，替代简单的Text
                List(events) { event in
                    EventRowView(event: event)
                }
            }
        }
    }
}

// 新增: 一个用于显示单条事件记录的视图，让列表更美观
struct EventRowView: View {
    let event: WatchMatchEvent
    
    var body: some View {
        HStack {
            Image(systemName: event.eventType == "goal" ? "soccerball.inverse" : "figure.handball")
                .foregroundStyle(event.eventType == "goal" ? .green : .accentColor)
                .font(.title2)
            
            VStack(alignment: .leading) {
                if event.eventType == "goal" {
                    Text(event.scorer?.name ?? "未知球员")
                        .font(.headline)
                    if let assistant = event.assistant {
                        Text("助攻: \(assistant.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if event.eventType == "save" {
                     Text(event.goalkeeper?.name ?? "未知球员")
                        .font(.headline)
                    Text("扑救成功")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Text(event.timestamp, style: .time)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

