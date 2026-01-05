import SwiftUI
import SwiftData

struct ConfirmationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // 1. 获取环境中的赛季ID
    // 修复：现在底部添加了 EnvironmentKey 定义，这里就不会报错了
    @Environment(\.selectedSeasonID) var selectedSeasonID
    
    // 2. 查询所有赛季以便查找对象
    @Query private var seasons: [Season]
    
    let homeTeam: [Player]
    let awayTeam: [Player]
    let homeTeamName: String
    let awayTeamName: String
    
    @State private var navigateToRecord = false
    @State private var createdMatch: Match?
    
    var body: some View {
        VStack(spacing: 20) {
            List {
                Section("蓝队 (\(homeTeamName))") {
                    ForEach(homeTeam) { player in
                        Text(player.name)
                    }
                }
                
                Section("红队 (\(awayTeamName))") {
                    ForEach(awayTeam) { player in
                        Text(player.name)
                    }
                }
            }
            
            Button(action: startMatch) {
                Text("开始比赛")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(10)
            }
            .padding()
        }
        .navigationTitle("确认名单")
        .navigationDestination(isPresented: $navigateToRecord) {
            if let match = createdMatch {
                MatchRecordView(match: match)
            }
        }
    }
    
    private func startMatch() {
        // 创建比赛实例
        let match = Match(
            homeTeamName: homeTeamName,
            awayTeamName: awayTeamName
        )
        
        // MARK: - 3. 关联赛季逻辑
        // 优先使用从列表页传来的选中赛季
        if let seasonID = selectedSeasonID,
           let targetSeason = seasons.first(where: { $0.id == seasonID }) {
            match.season = targetSeason
        } else {
            // 如果没有传（比如直接进入），默认归入当前赛季
            if let current = seasons.first(where: { $0.isCurrent }) {
                match.season = current
            }
        }
        
        // 初始化比赛数据
        modelContext.insert(match)
        
        // 为所有球员创建初始数据
        // 注意：确保 PlayerMatchStats 的 init 包含 team 参数
        for player in homeTeam {
            let stats = PlayerMatchStats(player: player, match: match, team: .home)
            match.playerStats.append(stats)
        }
        
        for player in awayTeam {
            let stats = PlayerMatchStats(player: player, match: match, team: .away)
            match.playerStats.append(stats)
        }
        
        do {
            try modelContext.save()
            createdMatch = match
            navigateToRecord = true
        } catch {
            print("创建比赛失败: \(error)")
        }
    }
}

// MARK: - 修复报错的关键：定义环境键
// 将这段代码放在文件末尾，确保 selectedSeasonID 能够被识别
struct SelectedSeasonIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}

extension EnvironmentValues {
    var selectedSeasonID: UUID? {
        get { self[SelectedSeasonIDKey.self] }
        set { self[SelectedSeasonIDKey.self] = newValue }
    }
}
