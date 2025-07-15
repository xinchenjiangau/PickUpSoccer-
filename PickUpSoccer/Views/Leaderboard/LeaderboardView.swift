import SwiftUI
import SwiftData

struct LeaderboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [Player]
    @Query private var matchStats: [PlayerMatchStats]
    @State private var selectedTab = 0
    
    // 进球排行
    var goalScorers: [(player: Player, goals: Int)] {
        let playerStats = Dictionary(grouping: matchStats, by: { $0.player! })
            .mapValues { stats in
                stats.reduce(0) { $0 + $1.goals }
            }
        return players.map { player in
            (player: player, goals: playerStats[player] ?? 0)
        }
        .sorted { $0.goals > $1.goals }
    }
    
    // 助攻排行
    var assistLeaders: [(player: Player, assists: Int)] {
        let playerStats = Dictionary(grouping: matchStats, by: { $0.player! })
            .mapValues { stats in
                stats.reduce(0) { $0 + $1.assists }
            }
        return players.map { player in
            (player: player, assists: playerStats[player] ?? 0)
        }
        .sorted { $0.assists > $1.assists }
    }
    
    // 扑救排行
    var saveLeaders: [(player: Player, saves: Int)] {
        let playerStats = Dictionary(grouping: matchStats, by: { $0.player! })
            .mapValues { stats in
                stats.reduce(0) { $0 + $1.saves }
            }
        return players.map { player in
                (player: player, saves: playerStats[player] ?? 0)
            }
            .sorted { $0.saves > $1.saves }
    }
    
    // 评分榜
    var scoreLeaders: [(player: Player, averageScore: Double)] {
        let playerStats = Dictionary(grouping: matchStats, by: { $0.player! })
        return players.map { player in
            let stats = playerStats[player] ?? []
            let avg = stats.isEmpty ? 0 : stats.map { $0.score }.reduce(0, +) / Double(stats.count)
            return (player: player, averageScore: avg)
        }
        .sorted { $0.averageScore > $1.averageScore }
    }
    
    // 标题数据
    private let titles = ["进球榜", "助攻榜", "扑救榜", "评分榜"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标题栏
                HStack {
                    ForEach(0..<4) { index in
                        Button(action: {
                            withAnimation {
                                selectedTab = index
                            }
                        }) {
                            Text(["进球榜", "助攻榜", "扑救榜", "评分榜"][index])
                                .foregroundColor(selectedTab == index ? .black : .gray)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 排行榜内容
                TabView(selection: $selectedTab) {
                    // 进球榜
                    LeaderboardTabView(
                        title: "进球榜",
                        items: goalScorers.map { (player: $0.player, value: $0.goals) },
                        valueLabel: "进球",
                        getValue: { $0 }
                    )
                    .tag(0)
                    
                    // 助攻榜
                    LeaderboardTabView(
                        title: "助攻榜",
                        items: assistLeaders.map { (player: $0.player, value: $0.assists) },
                        valueLabel: "助攻",
                        getValue: { $0 }
                    )
                    .tag(1)
                    
                    // 扑救榜
                    LeaderboardTabView(
                        title: "扑救榜",
                        items: saveLeaders.map { (player: $0.player, value: $0.saves) },
                        valueLabel: "扑救",
                        getValue: { $0 }
                    )
                    .tag(2)
                    
                    // 评分榜
                    LeaderboardScoreTabView(
                        title: "评分榜",
                        items: scoreLeaders,
                        valueLabel: "场均评分"
                    )
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("排行榜")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// 排行榜标签页视图
struct LeaderboardTabView<T: BinaryInteger>: View {
    let title: String
    let items: [(player: Player, value: T)]
    let valueLabel: String
    let getValue: (T) -> T
    
    var body: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.player.id) { index, item in
                HStack {
                    // 排名
                    Text("\(index + 1)")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .frame(width: 30)
                    
                    // 球员信息
                    VStack(alignment: .leading) {
                        Text(item.player.name)
                            .font(.headline)
                        Text(item.player.position.rawValue)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // 数据
                    HStack {
                        Text("\(getValue(item.value))")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text(valueLabel)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct LeaderboardScoreTabView: View {
    let title: String
    let items: [(player: Player, averageScore: Double)]
    let valueLabel: String

    var body: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.player.id) { index, item in
                HStack {
                    Text("\(index + 1)")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .frame(width: 30)
                    VStack(alignment: .leading) {
                        Text(item.player.name)
                            .font(.headline)
                        Text(item.player.position.rawValue)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    HStack {
                        Text(String(format: "%.2f", item.averageScore))
                            .font(.headline)
                            .foregroundColor(.orange)
                        Text(valueLabel)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

#Preview {
    LeaderboardView()
} 