import Foundation

enum MatchStatus: String, Codable, CaseIterable {
    case notStarted = "未开始"
    case inProgress = "进行中"
    case finished = "已结束"
    case cancelled = "已取消"
}

enum PlayerPosition: String, Codable, CaseIterable {
    case forward = "前锋"
    case midfielder = "中场"
    case defender = "后卫"
    case goalkeeper = "守门员"
}

enum EventType: String, Codable {
    case goal = "进球"
//    case assist = "助攻"
    case foul = "犯规"
    case save = "扑救"
    case yellowCard = "黄牌"
    case redCard = "红牌"
} 
