import SwiftUI
import SwiftData

struct TeamSelectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State var selectedPlayers: [Player]
    @State private var playerColors: [UUID: Color] = [:] // 存储每个球员的颜色
    @State private var firstPlayerSelected: Bool = false // 记录是否已选择第一个球员
    @State private var showingMatchRecord = false // 状态变量
    @State private var currentMatch: Match? // 存储当前创建的比赛
    @State private var redTeamAverageScore: Double = 0
    @State private var blueTeamAverageScore: Double = 0
    @EnvironmentObject var coordinator: NavigationCoordinator
    
    var redTeam: [Player] {
        selectedPlayers.filter { playerColors[$0.id] == .red }
    }
    
    var blueTeam: [Player] {
        selectedPlayers.filter { playerColors[$0.id] == .blue }
    }
    
    private func randomizeTeams() {
        // 清空现有分配
        playerColors.removeAll()
        
        // 随机打乱球员顺序
        let shuffledPlayers = selectedPlayers.shuffled()
        
        // 计算每队应有人数
        let totalPlayers = selectedPlayers.count
        let redTeamSize = totalPlayers / 2 + (totalPlayers % 2) // 如果是奇数，红队多一人
        
        // 分配球员
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
                                .foregroundColor(playerColors[player.id] ?? .gray) // 默认灰色
                        }
                    }
                }
            }
            // 跳转到比赛记录页面
            NavigationLink(
                destination: currentMatch.map { MatchRecordView(match: $0).environmentObject(coordinator) },
                isActive: $showingMatchRecord
            ) {
                EmptyView()
            }
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
        .onChange(of: showingMatchRecord) { oldValue, newValue in
            if !newValue {
                dismiss() // 当 MatchRecordView 关闭时，返回到 MatchesView
            }
        }
    }
    
    private func createAndStartMatch() {
        // 创建新的比赛，只传入必要参数
        let newMatch = Match(
            id: UUID(),
            status: .inProgress,  // 创建时直接设置为进行中
            homeTeamName: "红队",
            awayTeamName: "蓝队"
        )
        
        // 初始化比分
        newMatch.homeScore = 0
        newMatch.awayScore = 0
        
        // 初始化空数组
        newMatch.events = []
        newMatch.playerStats = []
        
        // 为每个球员创建比赛统计
        for player in redTeam {
            let stats = PlayerMatchStats(player: player, match: newMatch)
            stats.isHomeTeam = true
            newMatch.playerStats.append(stats)
        }
        
        for player in blueTeam {
            let stats = PlayerMatchStats(player: player, match: newMatch)
            stats.isHomeTeam = false
            newMatch.playerStats.append(stats)
        }
        
        // 保存到数据库
        modelContext.insert(newMatch)
        
        // 保存当前比赛并显示比赛记录页面
        currentMatch = newMatch
        showingMatchRecord = true
    }
    
    private func togglePlayerColor(_ player: Player) {
        if !firstPlayerSelected {
            // 第一次点击，设置第一个球员为红色，其他为蓝色
            playerColors[player.id] = .red
            firstPlayerSelected = true
            
            // 将其他球员设置为蓝色
            for otherPlayer in selectedPlayers where otherPlayer.id != player.id {
                playerColors[otherPlayer.id] = .blue
            }
        } else {
            // 如果已经选择了第一个球员，切换颜色
            if playerColors[player.id] == .red {
                playerColors[player.id] = .blue // 切换为蓝色
            } else {
                playerColors[player.id] = .red // 切换为红色
            }
        }
        updateTeamAverageScores()
    }
    
    // 添加队伍人数显示
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
    
    /// 按评分均衡分队（贪心算法）
    func balancedTeams(players: [Player], season: Season?) -> ([Player], [Player]) {
        // 1. 按评分排序
        let sortedPlayers = players.sorted { 
            $0.averageScoreForSeason(season) > $1.averageScoreForSeason(season) 
        }
        
        let teamSize = players.count / 2
        var teamA: [Player] = []
        var teamB: [Player] = []
        var sumA: Double = 0
        var sumB: Double = 0
        
        // 2. 使用贪心策略分配球员
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
        // 添加错误处理
        guard !selectedPlayers.isEmpty else { return }
        
        let (red, blue) = balancedTeams(players: selectedPlayers, season: nil)
        playerColors.removeAll()
        
        // 使用批量更新减少重绘次数
        for player in red {
            playerColors[player.id] = .red
        }
        for player in blue {
            playerColors[player.id] = .blue
        }
        
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

#Preview {
    TeamSelectView(selectedPlayers: [Player(name: "球员1", position: .forward), Player(name: "球员2", position: .midfielder)])
} 
