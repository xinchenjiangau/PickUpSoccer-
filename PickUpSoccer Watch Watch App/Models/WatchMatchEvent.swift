//
//  WatchMatchEvent.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import Foundation
import SwiftData

@Model
final class WatchMatchEvent {
    @Attribute(.unique) var eventId: UUID = UUID()
    var eventType: String // "goal", "save"
    var timestamp: Date = Date()
    
    // Relationships to players involved
    @Relationship var scorer: WatchPlayer?
    @Relationship var assistant: WatchPlayer?
    @Relationship var goalkeeper: WatchPlayer?
    
    var matchSession: WatchMatchSession?

    init(eventType: String, scorer: WatchPlayer? = nil, assistant: WatchPlayer? = nil, goalkeeper: WatchPlayer? = nil) {
        self.eventType = eventType
        self.scorer = scorer
        self.assistant = assistant
        self.goalkeeper = goalkeeper
    }
}

