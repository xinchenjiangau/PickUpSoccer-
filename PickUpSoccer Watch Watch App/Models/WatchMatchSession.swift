//
//  WatchMatchSession.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

// Models/WatchMatchSession.swift
import Foundation
import SwiftData

@Model
final class WatchMatchSession {
    @Attribute(.unique) var matchId: UUID
    var homeTeamName: String
    var awayTeamName: String
    var startTime: Date
    var isActive: Bool
    
    @Relationship(deleteRule: .cascade, inverse: \WatchPlayer.matchSession)
    var players: [WatchPlayer] = []
    
    @Relationship(deleteRule: .cascade, inverse: \WatchMatchEvent.matchSession)
    var events: [WatchMatchEvent] = []
    
    init(matchId: UUID, homeTeamName: String, awayTeamName: String) {
        self.matchId = matchId
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.startTime = Date()
        self.isActive = true
    }
}