import Foundation
import SwiftData

@Model
final class PlayerMatchStats {
    var id: UUID
    @Relationship var player: Player?
    @Relationship var match: Match?
    
    // MARK: - 1. 恢复旧存储结构 (救命关键)
    // 直接使用 Bool 类型存储，完全匹配旧数据库的列定义，确保能成功打开 App
    var isHomeTeam: Bool = true
    
    // MARK: - 2. 伪装新接口 (适配代码)
    // @Transient 表示这个属性不存入数据库，只在内存中计算
    // 所有的 UI 和逻辑代码调用 .team 时，实际上是在读写 .isHomeTeam
    @Transient var team: Team {
        get {
            return isHomeTeam ? .home : .away
        }
        set {
            isHomeTeam = (newValue == .home)
        }
    }
    
    // 其他统计数据 (SwiftData 会自动为新加的字段赋予默认值，通常不会导致崩溃)
    var goals: Int = 0
    var assists: Int = 0
    var saves: Int = 0
    var fouls: Int = 0
    var minutesPlayed: Int = 0
    var distance: Double? = 0.0
    var score: Double = 6.0
    
    init(id: UUID = UUID(),
         player: Player? = nil,
         match: Match? = nil,
         team: Team = .home) {
        self.id = id
        self.player = player
        self.match = match
        
        // 初始化时，将传入的 Enum 转换为 Bool 存储
        self.isHomeTeam = (team == .home)
        
        self.goals = 0
        self.assists = 0
        self.saves = 0
        self.fouls = 0
        self.minutesPlayed = 0
        self.distance = 0.0
        self.score = 6.0
    }

    /// 更新单场评分算法
    func updateScore() {
        let firstGoalScore = goals > 0 ? 2.4 : 0.0
        let extraGoalScore = goals > 1 ? 1.9 * (1 - exp(-0.95 * Double(goals - 1))) : 0.0

        let firstAssistScore = assists > 0 ? 1.5 : 0.0
        let extraAssistScore = assists > 1 ? 1.3 * (1 - exp(-0.75 * Double(assists - 1))) : 0.0

        let firstSaveScore = saves > 0 ? 1.3 : 0.0
        let extraSaveScore = saves > 1 ? 1.0 * (1 - exp(-0.6 * Double(saves - 1))) : 0.0
        
        // 扣分项 (例如犯规)
        let foulPenalty = Double(fouls) * 0.5

        let rawScore = 4.0 + firstGoalScore + extraGoalScore + firstAssistScore + extraAssistScore + firstSaveScore + extraSaveScore - foulPenalty
        self.score = max(min(rawScore, 10.0), 0.0) // 限制在 0-10 分
    }
}
