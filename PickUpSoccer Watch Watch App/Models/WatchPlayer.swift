//
//  WatchPlayer.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import Foundation
import SwiftData

@Model
final class WatchPlayer {
    @Attribute(.unique) var playerId: UUID
    var name: String
    var isHomeTeam: Bool
    
    var matchSession: WatchMatchSession?

    init(playerId: UUID, name: String, isHomeTeam: Bool) {
        self.playerId = playerId
        self.name = name
        self.isHomeTeam = isHomeTeam
    }
}

