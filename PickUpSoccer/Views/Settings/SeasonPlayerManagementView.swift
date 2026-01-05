//
//  SeasonPlayerManagementView.swift
//  PickUpSoccer
//
//  Created by xc j on 1/5/26.
//

import SwiftUI
import SwiftData

struct SeasonPlayerManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var season: Season
    
    // 获取所有未删除的球员
    // 注意：确保 Player 模型中有 isArchived 属性。如果没有，请去掉 filter 或改为 !player.isDeleted
    @Query(filter: #Predicate<Player> { !$0.isArchived }, sort: \Player.name)
    private var allPlayers: [Player]
    
    @State private var searchText = ""
    
    var filteredPlayers: [Player] {
        if searchText.isEmpty {
            return allPlayers
        } else {
            return allPlayers.filter { $0.name.localizedStandardContains(searchText) }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredPlayers) { player in
                HStack {
                    // 名字
                    Text(player.name)
                    
                    Spacer()
                    
                    // 勾选状态：检查该球员是否在当前赛季的 players 数组中
                    if let seasonPlayers = season.players, seasonPlayers.contains(player) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "circle")
                            .foregroundColor(.gray)
                    }
                }
                .contentShape(Rectangle()) // 让整个行都能点击
                .onTapGesture {
                    togglePlayer(player)
                }
            }
        }
        .searchable(text: $searchText, prompt: "搜索球员")
        .navigationTitle("管理赛季球员")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Text("已选: \(season.players?.count ?? 0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func togglePlayer(_ player: Player) {
        // 确保 players 数组已初始化
        if season.players == nil {
            season.players = []
        }
        
        if let index = season.players?.firstIndex(of: player) {
            // 如果已存在，则移除
            season.players?.remove(at: index)
        } else {
            // 如果不存在，则添加
            season.players?.append(player)
        }
        
        // 显式保存，确保关系更新
        try? modelContext.save()
    }
}
