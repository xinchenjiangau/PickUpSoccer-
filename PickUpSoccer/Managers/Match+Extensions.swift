//
//  Match+Extensions.swift
//  PickUpSoccer
//
//  Created by xc j on 6/30/25.
//

import Foundation

//func updateMatchStats(for event: MatchEvent, in match: Match) {
//    if event.eventType == .goal {
//        if event.isHomeTeam {
//            match.homeScore += 1
//        } else {
//            match.awayScore += 1
//        }
//
//        if let stats = match.playerStats.first(where: { $0.player?.id == event.scorer?.id }) {
//            stats.goals += 1
//        }
//    } else if event.eventType == .save {
//        if let stats = match.playerStats.first(where: { $0.player?.id == event.scorer?.id }) {
//            stats.saves += 1
//        }
//    }
//}
// MARK: - Safe Player Access
extension Player {
    /// 安全获取球员名字，防止访问已删除对象导致崩溃
    var safeName: String {
        if self.isDeleted {
            return "未知球员"
        }
        return self.name
    }
    
    /// 判断球员是否有效（未被删除）
    var isValid: Bool {
        return !self.isDeleted
    }
}

extension MatchEvent {
    /// 安全获取进球者名字
    var safeScorerName: String {
        guard let scorer = scorer, !scorer.isDeleted else {
            return "未知球员"
        }
        return scorer.name
    }
    
    /// 安全获取门将名字
    var safeGoalkeeperName: String {
        guard let goalkeeper = goalkeeper, !goalkeeper.isDeleted else {
            return "未知球员"
        }
        return goalkeeper.name
    }
}
