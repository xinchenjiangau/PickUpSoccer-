import SwiftUI
import SwiftData

struct AddMatchPlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var match: Match
    @State private var isHomeTeam = true
    @Query private var allPlayers: [Player]
    
    // 过滤掉已经在比赛中的球员
    var availablePlayers: [Player] {
        let existingPlayerIds = Set(match.playerStats.compactMap { $0.player?.id })
        return allPlayers.filter { !existingPlayerIds.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // 选择队伍
                Picker("选择队伍", selection: $isHomeTeam) {
                    Text("红队").tag(true)
                    Text("蓝队").tag(false)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if availablePlayers.isEmpty {
                    ContentUnavailableView("没有可添加的球员", 
                                        systemImage: "person.slash")
                } else {
                    List(availablePlayers) { player in
                        Button(action: {
                            addPlayerToMatch(player)
                        }) {
                            HStack {
                                Text(player.name)
                                Spacer()
                                Text(player.position.rawValue)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加球员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addPlayerToMatch(_ player: Player) {
        // 创建新的球员比赛统计
        let stats = PlayerMatchStats(player: player, match: match)
        stats.isHomeTeam = isHomeTeam
        
        // 添加到比赛中
        match.playerStats.append(stats)
        
        // 保存更改
        try? modelContext.save()
        WatchConnectivityManager.shared.syncPlayerToWatchIfNeeded(player: player, match: match)

        // 关闭视图
        dismiss()
        

    }
} 