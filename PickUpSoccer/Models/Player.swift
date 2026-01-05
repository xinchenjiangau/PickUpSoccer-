import Foundation
import SwiftData

@Model
final class Player {
    var id: UUID
    var name: String
    var number: Int?
    var position: PlayerPosition
    var phone: String?
    var email: String?
    var profilePicture: URL?
    var age: Int?
    var gender: String?
    var height: Double?
    var weight: Double?
    var appleUserID: String?
    var nickname: String?
    
    // 软删除标记
    var isArchived: Bool = false
    
    // 赛季关联
    var seasons: [Season]? = []
    
    @Relationship(deleteRule: .cascade) var matchStats: [PlayerMatchStats]
    
    init(id: UUID = UUID(),
         name: String,
         number: Int? = nil,
         position: PlayerPosition) {
        self.id = id
        self.name = name
        self.number = number
        self.position = position
        self.matchStats = []
        self.isArchived = false
        self.seasons = []
    }
    
    // MARK: - 基础统计属性
    var totalGoals: Int {
        matchStats.reduce(into: 0) { result, stats in
            result += stats.goals
        }
    }
    
    var totalAssists: Int {
        matchStats.reduce(into: 0) { result, stats in
            result += stats.assists
        }
    }
    
    var totalMatches: Int {
        matchStats.count
    }
    
    var totalSaves: Int {
        matchStats.reduce(into: 0) { result, stats in
            result += stats.saves
        }
    }
    
    // MARK: - 扩展功能
    
    /// 判断资料是否完整
    var isProfileComplete: Bool {
        return name != "新用户" && number != nil && profilePicture != nil
    }

    /// 获取某赛季所有比赛评分
    func scoresForSeason(_ season: Season?) -> [Double] {
        let stats = matchStats.filter {
            season == nil || $0.match?.season?.id == season?.id
        }
        return stats.map { $0.score }
    }

    /// 场均评分
    func averageScoreForSeason(_ season: Season?) -> Double {
        let scores = scoresForSeason(season)
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    /// 最近N场评分
    func recentAverageScoreForSeason(_ season: Season?, count: Int = 5) -> Double {
        let stats = matchStats
            .filter { season == nil || $0.match?.season?.id == season?.id }
            .sorted { ($0.match?.matchDate ?? .distantPast) > ($1.match?.matchDate ?? .distantPast) }
            .prefix(count)
        let scores = stats.map { $0.score }
        guard !scores.isEmpty else { return 0 }
        return scores.reduce(0, +) / Double(scores.count)
    }

    // MARK: - 关键修复：MVP 统计逻辑
    /// MVP场次（统计 match.mvp 是自己的次数）
    func mvpCountForSeason(_ season: Season?) -> Int {
        // 1. 获取该球员在该赛季的所有比赛统计
        let seasonStats = stats(in: season)
        
        // 2. 筛选出那些“比赛的MVP记录是自己”的场次
        let mvpMatches = seasonStats.filter { stat in
            guard let match = stat.match, let matchMvp = match.mvp else { return false }
            return matchMvp.id == self.id
        }
        
        return mvpMatches.count
    }
    
    // MARK: - 统计辅助方法
    
    /// 获取特定赛季的比赛统计
    func stats(in season: Season?) -> [PlayerMatchStats] {
        if let season = season {
            return matchStats.filter { $0.match?.season?.id == season.id }
        } else {
            return matchStats
        }
    }

    /// 特定赛季进球数
    func goals(in season: Season?) -> Int {
        stats(in: season).reduce(0) { $0 + $1.goals }
    }

    /// 特定赛季助攻数
    func assists(in season: Season?) -> Int {
        stats(in: season).reduce(0) { $0 + $1.assists }
    }
    
    /// 特定赛季扑救数
    func saves(in season: Season?) -> Int {
        stats(in: season).reduce(0) { $0 + $1.saves }
    }
}
