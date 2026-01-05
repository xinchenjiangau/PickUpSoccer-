import Foundation
import SwiftData

@Model
final class Season {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var isCurrent: Bool // 标记是否为当前默认赛季
    
    // 关系
    // 级联删除：如果赛季被删，比赛也被删（根据需求可调整，目前保持级联以防孤儿数据）
    @Relationship(deleteRule: .cascade) var matches: [Match]? = []
    
    // 球员与赛季是多对多关系
    @Relationship(inverse: \Player.seasons) var players: [Player]? = []
    
    init(id: UUID = UUID(),
         name: String,
         startDate: Date,
         endDate: Date,
         isCurrent: Bool = false) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrent = isCurrent
    }
}
