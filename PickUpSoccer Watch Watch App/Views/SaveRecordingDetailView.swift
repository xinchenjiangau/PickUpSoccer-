//
//  SaveRecordingDetailView.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import SwiftUI
import SwiftData

struct SaveRecordingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    
    let session: WatchMatchSession
    let players: [WatchPlayer]
    let onSave: (WatchMatchEvent) -> Void

    @State private var goalkeeper: WatchPlayer?

    var body: some View {
        NavigationStack {
            Form {
                NavigationLink {
                    PlayerListView(players: players) { selectedPlayer in
                        goalkeeper = selectedPlayer
                        
                    }
                } label: {
                    HStack {
                        Text("扑救球员")
                        Spacer()
                        Text(goalkeeper?.name ?? "请选择")
                            .foregroundStyle(goalkeeper == nil ? .secondary : .primary)
                    }
                }
            }
            .navigationTitle("记录扑救")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }.disabled(goalkeeper == nil)
                }
            }
        }
    }

    private func save() {
        guard let goalkeeperId = goalkeeper?.playerId,
              let realGoalkeeper = players.first(where: { $0.playerId == goalkeeperId }) else { return }
        
        let newEvent = WatchMatchEvent(eventType: "save", goalkeeper: realGoalkeeper)
        let session = try? modelContext.fetch(FetchDescriptor<WatchMatchSession>()).first

        newEvent.matchSession = session
        onSave(newEvent)
        dismiss()
    }
}

