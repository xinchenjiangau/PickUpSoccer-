//
//  PlayerListView.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import SwiftUI
import SwiftData



struct PlayerListView: View {
    @Environment(\.dismiss) private var dismiss
    let players: [WatchPlayer]
    let onPlayerSelected: (WatchPlayer) -> Void

    var body: some View {
        List(players) { player in
            Button(player.name) {
                onPlayerSelected(player)
                dismiss()
            }
        }
        .navigationTitle("选择球员")
    }
}

