//
//  GoalRecordingDetailView.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import SwiftUI
import SwiftData
import WatchConnectivity

struct GoalRecordingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let session: WatchMatchSession
    let players: [WatchPlayer]
    let onSave: (WatchMatchEvent) -> Void

    @State private var scorer: WatchPlayer?
    @State private var assistant: WatchPlayer?

    var body: some View {
        NavigationStack {
            Form {
                NavigationLink {
                    PlayerListView(players: players) { selectedPlayer in
                        scorer = selectedPlayer
                        
                    }
                } label: {
                    h_stack_label(title: "进球", value: scorer?.name)
                }

                NavigationLink {
                    let assistantOptions = players.filter { $0.playerId != scorer?.playerId }
                    PlayerListView(players: assistantOptions) { selectedPlayer in
                        assistant = selectedPlayer
                        
                    }
                } label: {
                    h_stack_label(title: "助攻", value: assistant?.name)
                }
                .disabled(scorer == nil)
            }
            .navigationTitle("记录进球")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveGoal() }.disabled(scorer == nil)
                }
            }
        }
    }
    
    private func h_stack_label(title: String, value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value ?? "请选择")
                .foregroundStyle(value == nil ? .secondary : .primary)
        }
    }
    
    private func saveGoal() {
        guard let scorerId = scorer?.playerId,
              let realScorer = players.first(where: { $0.playerId == scorerId }) else { return }
        var realAssistant: WatchPlayer? = nil
        if let assistantId = assistant?.playerId {
            realAssistant = players.first(where: { $0.playerId == assistantId })
        }
        ensurePlayerSyncedToPhone(realScorer)
        if let realAssistant = realAssistant {
            ensurePlayerSyncedToPhone(realAssistant)
        }
        let newEvent = WatchMatchEvent(eventType: "goal", scorer: realScorer, assistant: realAssistant)
        let session = try? modelContext.fetch(FetchDescriptor<WatchMatchSession>()).first
        newEvent.matchSession = session
        print("scorer: \(scorer?.name ?? "nil") id: \(scorer?.playerId.uuidString ?? "nil")")
        onSave(newEvent)
        syncScoreToPhone()
        dismiss()
    }
    
    private func syncScoreToPhone() {
        let events = (try? modelContext.fetch(FetchDescriptor<WatchMatchEvent>())) ?? []
        let sessionEvents = events.filter { $0.matchSession?.matchId == session.matchId }
        let homeScore = sessionEvents.filter { $0.eventType == "goal" && ($0.scorer?.isHomeTeam ?? false) }.count
        let awayScore = sessionEvents.filter { $0.eventType == "goal" && !($0.scorer?.isHomeTeam ?? true) }.count
        
        let message: [String: Any] = [
            "command": "updateScore",
            "matchId": session.matchId.uuidString,
            "homeScore": homeScore,
            "awayScore": awayScore
        ]
        
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil) { error in
                print("发送比分更新失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func ensurePlayerSyncedToPhone(_ player: WatchPlayer) {
        // Implementation of ensurePlayerSyncedToPhone function
    }
}

