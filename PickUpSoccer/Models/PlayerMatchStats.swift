import Foundation
import SwiftData

@Model
final class PlayerMatchStats {
    var id: UUID
    @Relationship var player: Player?
    @Relationship var match: Match?
    var isHomeTeam: Bool
    
    var goals: Int
    var assists: Int
    var saves: Int
    var fouls: Int
    var minutesPlayed: Int
    var distance: Double? // 跑动距离（米）
    
    init(id: UUID = UUID(),
         player: Player? = nil,
         match: Match? = nil) {
        self.id = id
        self.player = player
        self.match = match
        self.isHomeTeam = false // 默认值
        self.goals = 0
        self.assists = 0
        self.saves = 0
        self.fouls = 0
        self.minutesPlayed = 0
    }

    /// 单场评分算法，满分10分，基础分6.0
    var score: Double {
        let firstGoalScore = goals > 0 ? 2.4: 0.0
        let extraGoalScore = goals > 1 ? 1.9 * (1 - exp(-0.95 * Double(goals - 1))) : 0.0

        let firstAssistScore = assists > 0 ? 1.5 : 0.0
        let extraAssistScore = assists > 1 ? 1.3 * (1 - exp(-0.75 * Double(assists - 1))) : 0.0

        let firstSaveScore = saves > 0 ? 1.3 : 0.0
        let extraSaveScore = saves > 1 ? 1.0 * (1 - exp(-0.6 * Double(saves - 1))) : 0.0

        let rawScore = 4.0 + firstGoalScore + extraGoalScore + firstAssistScore + extraAssistScore + firstSaveScore + extraSaveScore
        return min(rawScore, 10.0)
    }


} 
