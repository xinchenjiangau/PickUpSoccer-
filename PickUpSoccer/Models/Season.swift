import Foundation
import SwiftData

@Model
final class Season {
    var id: UUID
    var name: String
    var startDate: Date
    var endDate: Date
    var notes: String?
    var resources: [Resource]?
    @Relationship(deleteRule: .cascade) var matches: [Match]
    // ✅ 新增：用于存储管理员的appleUserID
    // 允许多个管理员，所以使用数组
    var administratorIDs: [String] = []
    @Relationship var players: [Player] = []
    
    init(id: UUID = UUID(),
         name: String,
         startDate: Date,
         endDate: Date,
         notes: String? = nil) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.matches = []
        self.players = []
    }
}

@Model
final class Resource {
    var id: UUID
    var type: String // "document", "image", "url"
    var url: URL
    var resourceDescription: String?
    
    init(id: UUID = UUID(), type: String, url: URL, resourceDescription: String? = nil) {
        self.id = id
        self.type = type
        self.url = url
        self.resourceDescription = resourceDescription
    }
} 
