//
//  SeasonPlayerManagementView.swift
//  PickUpSoccer
//
//  Created by xc j on 7/18/25.
//

import SwiftUI
import SwiftData

struct SeasonPlayerManagementView: View {
    let season: Season
    
    @Query(sort: \Player.name) private var allPlayers: [Player]
    
    // 计算属性：筛选出赛季内的球员
    private var playersInSeason: [Player] {
        allPlayers.filter { player in
            // 使用 contains 判断球员是否在赛季的 players 数组中
            season.players.contains(where: { $0.id == player.id })
        }
    }
    
    // 计算属性：筛选出赛季外的球员
    private var playersOutOfSeason: [Player] {
        allPlayers.filter { player in
            !season.players.contains(where: { $0.id == player.id })
        }
    }
    
    var body: some View {
        List {
            Section("赛季内球员 (\(playersInSeason.count))") {
                ForEach(playersInSeason) { player in
                    Text(player.name)
                }
                .onDelete(perform: removePlayer) // 滑动删除
            }
            
            Section("赛季外球员 (\(playersOutOfSeason.count))") {
                ForEach(playersOutOfSeason) { player in
                    HStack {
                        Text(player.name)
                        Spacer()
                        Button("添加") {
                            add(player: player)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .navigationTitle("管理球员")
        }
    }
    
    private func add(player: Player) {
        season.players.append(player)
    }

    private func removePlayer(at offsets: IndexSet) {
        // 从season的players数组中移除
        season.players.remove(atOffsets: offsets)
    }
}
