import Foundation
import SwiftData

@Model
final class MatchEvent {
    var id: UUID
    var eventType: EventType
    var timestamp: Date
    var isHomeTeam: Bool = false
    
    //@Relationship var match: Match?
    @Relationship(inverse: \Match.events) var match: Match?
    @Relationship var scorer: Player? // 进球者
    @Relationship var assistant: Player? // 助攻者
    @Relationship var goalkeeper: Player?

    
    init(
        id: UUID = UUID(),
         eventType: EventType,
         timestamp: Date,
        isHomeTeam: Bool,
         match: Match? = nil,
         scorer: Player? = nil,
        assistant: Player? = nil,
        goalkeeper: Player? = nil
    ) {
        self.id = id
        self.eventType = eventType
        self.timestamp = timestamp
        self.isHomeTeam = isHomeTeam
        self.match = match
        self.scorer = scorer
        self.assistant = assistant
        self.goalkeeper = goalkeeper
    }
} 
