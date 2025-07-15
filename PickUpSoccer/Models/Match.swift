import Foundation
import SwiftData

@Model
final class Match {
    var id: UUID
    var status: MatchStatus
    var homeTeamName: String
    var awayTeamName: String
    var matchDate: Date
    var location: String?
    var weather: String?
    var referee: String?
    var duration: Int?        // 已有的比赛时长字段
    var homeScore: Int
    var awayScore: Int
    
    @Relationship var season: Season?
    @Relationship(deleteRule: .cascade) var events: [MatchEvent]
    @Relationship(deleteRule: .cascade) var playerStats: [PlayerMatchStats]
    
    // 新增统计字段
    var mvp: Player?
    var topScorer: Player?
    var topGoalkeeper: Player?
    var topPlaymaker: Player?
    var playerCount: Int = 0    // 参与人数
    
    init(
        id: UUID = UUID(),
        status: MatchStatus = .notStarted,
        homeTeamName: String,
        awayTeamName: String
    ) {
        self.id = id
        self.status = status
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.matchDate = Date()
        self.location = nil
        self.weather = nil
        self.referee = nil
        self.duration = nil
        self.homeScore = 0
        self.awayScore = 0
        self.events = []
        self.playerStats = []
    }
}

// Match 模型扩展，添加统计方法
extension Match {
    // 计算MVP（根据进球、助攻、扑救综合评分）
    func calculateMVP() -> Player? {
        let playerScores = playerStats.map { stats -> (player: Player, score: Int) in
            let score = stats.goals * 3 + stats.assists * 2 + stats.saves
            return (stats.player!, score)
        }
        return playerScores.max(by: { $0.score < $1.score })?.player
    }
    
    // 计算最佳射手
    func calculateTopScorer() -> Player? {
        return playerStats
            .max(by: { $0.goals < $1.goals })?
            .player
    }
    
    // 计算最佳守门员
    func calculateTopGoalkeeper() -> Player? {
        return playerStats
            .max(by: { $0.saves < $1.saves })?
            .player
    }
    
    // 计算最佳组织者
    func calculateTopPlaymaker() -> Player? {
        return playerStats
            .max(by: { $0.assists < $1.assists })?
            .player
    }
    
    // 更新比赛统计数据
    // 修正后的代码
    func updateMatchStats() {
        // MARK: - 关键修正：在计算前，先汇总所有统计数据
        
        // 1. 先将所有球员的统计数据清零
        for stats in playerStats {
            stats.goals = 0
            stats.assists = 0
            stats.saves = 0
        }
        
        // 2. 遍历所有比赛事件，重新累加统计数据
        for event in events {
            switch event.eventType {
            case .goal:
                if let scorerId = event.scorer?.id,
                   let stats = playerStats.first(where: { $0.player?.id == scorerId }) {
                    stats.goals += 1
                }
                if let assistantId = event.assistant?.id,
                   let stats = playerStats.first(where: { $0.player?.id == assistantId }) {
                    stats.assists += 1
                }
            case .save:
                if let goalkeeperId = event.goalkeeper?.id,
                   let stats = playerStats.first(where: { $0.player?.id == goalkeeperId }) {
                    stats.saves += 1
                }
            default:
                break
            }
        }
        
        // 3. 现在所有 PlayerMatchStats 的数据都是准确的，可以进行后续计算
        self.mvp = calculateMVP()
        self.topScorer = calculateTopScorer()
        self.topGoalkeeper = calculateTopGoalkeeper()
        self.topPlaymaker = calculateTopPlaymaker()
        
        self.playerCount = playerStats.count
        
        if let firstEvent = events.min(by: { $0.timestamp < $1.timestamp }),
           let lastEvent = events.max(by: { $0.timestamp < $1.timestamp }) {
            self.duration = Int(lastEvent.timestamp.timeIntervalSince(firstEvent.timestamp) / 60)
        }
    }
}
