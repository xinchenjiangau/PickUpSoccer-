import SwiftUI
import SwiftData

struct TeamSelectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State var selectedPlayers: [Player]
    @State private var playerColors: [UUID: Color] = [:]
    @State private var firstPlayerSelected: Bool = false
    
    // [修改 1] 使用 navigateToMatch 控制新版导航
    @State private var navigateToMatch = false
    @State private var currentMatch: Match?
    
    @State private var redTeamAverageScore: Double = 0
    @State private var blueTeamAverageScore: Double = 0
    @EnvironmentObject var coordinator: NavigationCoordinator
    
    // 获取环境中的赛季ID (如果有)
    @Environment(\.selectedSeasonID) var selectedSeasonID
    @Query private var seasons: [Season]
    
    var redTeam: [Player] {
        selectedPlayers.filter { playerColors[$0.id] == .red }
    }
    
    var blueTeam: [Player] {
        selectedPlayers.filter { playerColors[$0.id] == .blue }
    }
    
    private func randomizeTeams() {
        playerColors.removeAll()
        let shuffledPlayers = selectedPlayers.shuffled()
        let totalPlayers = selectedPlayers.count
        let redTeamSize = totalPlayers / 2 + (totalPlayers % 2)
        
        for (index, player) in shuffledPlayers.enumerated() {
            playerColors[player.id] = index < redTeamSize ? .red : .blue
        }
        updateTeamAverageScores()
    }
    
    var body: some View {
        VStack {
            teamCountsView
            HStack {
                Text(String(format: "红队平均分: %.2f", redTeamAverageScore))
                    .foregroundColor(.red)
                Spacer()
                Text(String(format: "蓝队平均分: %.2f", blueTeamAverageScore))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            List {
                ForEach(selectedPlayers, id: \.id) { player in
                    Button(action: {
                        togglePlayerColor(player)
                    }) {
                        HStack {
                            Text(player.name)
                                .foregroundColor(playerColors[player.id] ?? .gray)
                        }
                    }
                }
            }
            // [修改 2] 移除了旧的 NavigationLink，它容易导致崩溃
        }
        .navigationTitle("选择球队")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: randomizeTeams) {
                    Image(systemName: "shuffle.circle")
                }
                Button("开始比赛") {
                    createAndStartMatch()
                }
                Button("评分均衡分队") {
                    assignBalancedTeams()
                }
            }
        }
        // [修改 3] 使用新的导航修饰符，安全性更高
        .navigationDestination(isPresented: $navigateToMatch) {
            if let match = currentMatch {
                MatchRecordView(match: match)
                    .environmentObject(coordinator)
            }
        }
        .onChange(of: navigateToMatch) { oldValue, newValue in
            // 当从比赛页面返回时，关闭当前页面
            if !newValue {
                dismiss()
            }
        }
    }
    
    private func createAndStartMatch() {
        // 创建新的比赛
        let newMatch = Match(
            homeTeamName: "红队",
            awayTeamName: "蓝队"
        )
        newMatch.status = .inProgress
        
        // 关联赛季
        if let seasonID = selectedSeasonID,
           let targetSeason = seasons.first(where: { $0.id == seasonID }) {
            newMatch.season = targetSeason
        } else if let current = seasons.first(where: { $0.isCurrent }) {
            newMatch.season = current
        }
        
        // 初始化空数组（防止 nil 访问）
        newMatch.events = []
        newMatch.playerStats = []
        
        modelContext.insert(newMatch)
        
        // 创建统计数据
        for player in redTeam {
            let stats = PlayerMatchStats(player: player, match: newMatch, team: .home)
            newMatch.playerStats.append(stats)
        }
        
        for player in blueTeam {
            let stats = PlayerMatchStats(player: player, match: newMatch, team: .away)
            newMatch.playerStats.append(stats)
        }
        
        // MARK: - 关键修复：先保存，再跳转
        // 只有当 try? modelContext.save() 成功执行后，match 对象才拥有永久 ID
        // 此时再跳转，MatchRecordView 读取的就是安全的数据了
        do {
            try modelContext.save()
            print("✅ 比赛创建成功，准备跳转。ID: \(newMatch.id)")
            
            // 赋值并触发跳转
            currentMatch = newMatch
            navigateToMatch = true
        } catch {
            print("❌ 保存比赛失败: \(error)")
            // 可以在这里加一个 Alert 提示用户保存失败，而不是让它崩溃
        }
    }
    
    private func togglePlayerColor(_ player: Player) {
        if !firstPlayerSelected {
            playerColors[player.id] = .red
            firstPlayerSelected = true
            for otherPlayer in selectedPlayers where otherPlayer.id != player.id {
                playerColors[otherPlayer.id] = .blue
            }
        } else {
            if playerColors[player.id] == .red {
                playerColors[player.id] = .blue
            } else {
                playerColors[player.id] = .red
            }
        }
        updateTeamAverageScores()
    }
    
    var teamCountsView: some View {
        HStack {
            Text("红队: \(redTeam.count)人")
                .foregroundColor(.red)
            Spacer()
            Text("蓝队: \(blueTeam.count)人")
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    func balancedTeams(players: [Player], season: Season?) -> ([Player], [Player]) {
        let sortedPlayers = players.sorted {
            $0.averageScoreForSeason(season) > $1.averageScoreForSeason(season)
        }
        
        let teamSize = players.count / 2
        var teamA: [Player] = []
        var teamB: [Player] = []
        var sumA: Double = 0
        var sumB: Double = 0
        
        for player in sortedPlayers {
            let score = player.averageScoreForSeason(season)
            if (sumA <= sumB && teamA.count < teamSize) || teamB.count >= (players.count - teamSize) {
                teamA.append(player)
                sumA += score
            } else {
                teamB.append(player)
                sumB += score
            }
        }
        
        return (teamA, teamB)
    }
    
    private func assignBalancedTeams() {
        guard !selectedPlayers.isEmpty else { return }
        
        let (red, blue) = balancedTeams(players: selectedPlayers, season: nil)
        playerColors.removeAll()
        
        for player in red { playerColors[player.id] = .red }
        for player in blue { playerColors[player.id] = .blue }
        
        firstPlayerSelected = true
        updateTeamAverageScores()
    }
    
    private func updateTeamAverageScores() {
        let redScores = redTeam.map { $0.averageScoreForSeason(nil) }
        let blueScores = blueTeam.map { $0.averageScoreForSeason(nil) }
        redTeamAverageScore = redScores.isEmpty ? 0 : redScores.reduce(0, +) / Double(redScores.count)
        blueTeamAverageScore = blueScores.isEmpty ? 0 : blueScores.reduce(0, +) / Double(blueScores.count)
    }
}

extension Array {
    func combinations(ofCount k: Int) -> [[Element]] {
        guard k > 0 else { return [[]] }
        guard let first = first else { return [] }
        let subcombos = Array(self[1...]).combinations(ofCount: k - 1)
        var result = subcombos.map { [first] + $0 }
        result += Array(self[1...]).combinations(ofCount: k)
        return result
    }
}
