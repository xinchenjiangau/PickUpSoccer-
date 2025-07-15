//
//  WatchConnectivityManager.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import Foundation
import WatchConnectivity
import SwiftData

@MainActor
class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityManager()

    private var session: WCSession?
    private var modelContainer: ModelContainer?

    // Allows external injection of ModelContainer
    func configure(with container: ModelContainer) {
        self.modelContainer = container
    }

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    // MARK: - Sending Data to Watch

    /// Sends initial match data to the Watch.
    func sendStartMatchToWatch(match: Match) {
        guard let session = session, session.isPaired, session.isWatchAppInstalled else {
            print("WCSession not available or watch app not installed.")
            return
        }

        let playersPayload = match.playerStats.map { stats in
            [
                "id": stats.player!.id.uuidString,
                "name": stats.player!.name,
                "isHomeTeam": stats.isHomeTeam
            ]
        }
        let payload: [String: Any] = [
            "command": "startMatch",
            "matchId": match.id.uuidString,
            "homeTeamName": match.homeTeamName,
            "awayTeamName": match.awayTeamName,
            "players": playersPayload
        ]
        session.transferUserInfo(payload)
        print("✅ 已通过 transferUserInfo 发送比赛开始指令，尝试唤醒手表App。")
    }
    
    // MARK: - New unified function to send complete match end data to Watch
    /// Sends comprehensive match end data including scores and all events to the Watch.
    func sendFullMatchEndToWatch(match: Match) {
        guard let session = session, session.isReachable else {
            print("WCSession not reachable for sending full match end data.")
            return
        }

        let eventsPayload = match.events.map { event in
            [
                "eventType": event.eventType.rawValue,
                "timestamp": event.timestamp.timeIntervalSince1970,
                "isHomeTeam": event.isHomeTeam,
                "playerId": event.scorer?.id.uuidString ?? "", // Scorer or Goalkeeper for saves
                "assistantId": event.assistant?.id.uuidString ?? ""
            ]
        }

        let payload: [String: Any] = [
            "command": "matchEndedFromPhone",
            "matchId": match.id.uuidString,
            "homeScore": match.homeScore,
            "awayScore": match.awayScore,
            "events": eventsPayload // Include all events
        ]
        
        session.sendMessage(payload, replyHandler: nil) { error in
            print("❌ Failed to send full match end message to watch: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate (iOS side)

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // 此函数保持不变
        print("📱 iPhone WCSession 激活状态: \(activationState.rawValue)")
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // 可选: 处理 session 变为非活动状态
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // 用户可能更换了手表，需要重新激活
        session.activate()
    }

    // 在 PickUpSoccer/Managers/WatchConnectivityManager.swift 文件中

    // 这个代理方法会在后台被唤醒，非常适合处理比赛结束的最终数据
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let command = userInfo["command"] as? String else {
            return
        }

        print("📨 Phone received userInfo with command: \(command)")

        // 使用 Task.detached 确保在主线程外执行数据处理
        Task.detached(priority: .userInitiated) {
            await MainActor.run {
                guard let context = self.modelContainer?.mainContext else {
                    print("⚠️ [WatchKit] 无法获取 ModelContext")
                    return
                }

                // 根据命令分发任务
                switch command {
                case "matchEndedFromWatch":
                    // 调用我们全新的、安全的统计函数
                    self.handleFinalSyncAndEndMatch(from: userInfo, context: context)
                
                case "newEventBackup":
                    // 这里可以保留您之前的单个事件备份逻辑（如果需要）
                    self.handleNewEvent(from: userInfo, context: context)

                default:
                    print("⚠️ [WatchKit] 收到未知的 userInfo command: \(command)")
                }
            }
        }
    }

    // MARK: - Message Handlers

    // In xinchenjiangau/pickupsoccer/PickUpSoccer-46a3117d7232204197ff70efc5a54e3337afc15c/Managers/WatchConnectivityManager.swift

    private func handleNewEvent(from message: [String: Any], context: ModelContext) {
        // 1. 验证收到的消息是否完整
        guard let matchIdStr = message["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdStr),
              let eventTypeStr = message["eventType"] as? String else {
            print("❌ [WatchKit] 收到不完整的新事件数据。")
            return
        }

        // 2. 根据ID查找对应的比赛
        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? context.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else {
            print("❌ [WatchKit] 无法找到比赛，ID: \(matchIdStr)")
            return
        }

        // 3. 将字符串类型的事件转换为枚举类型
        let eventType = translatedEventType(from: eventTypeStr)
        let newEvent = MatchEvent(eventType: eventType, timestamp: Date(), isHomeTeam: false, match: match)

        // 4. 根据事件类型，分别处理数据
        if eventType == .goal {
            // --- 处理进球者 ---
            if let scorerIdStr = message["playerId"] as? String,
               let scorerId = UUID(uuidString: scorerIdStr),
               let scorerStats = match.playerStats.first(where: { $0.player?.id == scorerId }) {

                newEvent.scorer = scorerStats.player
                // [修复] 关键修复：正确设置事件属于主队还是客队
                newEvent.isHomeTeam = scorerStats.isHomeTeam
                scorerStats.goals += 1

                // [修复] 实时更新比赛比分
                if scorerStats.isHomeTeam {
                    match.homeScore += 1
                } else {
                    match.awayScore += 1
                }
            }

            // --- 处理助攻者 ---
            if let assistantIdStr = message["assistantId"] as? String,
               let assistantId = UUID(uuidString: assistantIdStr),
               let assistantStats = match.playerStats.first(where: { $0.player?.id == assistantId }) {
                newEvent.assistant = assistantStats.player
                // [修复] 增加助攻者的助攻统计
                assistantStats.assists += 1
            }

        } else if eventType == .save {
            // --- 处理扑救者 ---
            // 优先使用 "goalkeeperId" 字段
            if let goalkeeperIdStr = message["goalkeeperId"] as? String,
               let goalkeeperId = UUID(uuidString: goalkeeperIdStr),
               let goalkeeperStats = match.playerStats.first(where: { $0.player?.id == goalkeeperId }) {

                newEvent.goalkeeper = goalkeeperStats.player
                // [修复] 正确设置事件属于主队还是客队
                newEvent.isHomeTeam = goalkeeperStats.isHomeTeam
                // [修复] 增加扑救者的扑救统计
                goalkeeperStats.saves += 1
                
            // 如果没有 "goalkeeperId"，则尝试使用 "playerId" 作为备用
            } else if let playerIdStr = message["playerId"] as? String,
                      let playerId = UUID(uuidString: playerIdStr),
                      let playerStats = match.playerStats.first(where: { $0.player?.id == playerId }) {

                // 在扑救事件中，将扑救者信息存入goalkeeper字段
                newEvent.goalkeeper = playerStats.player
                newEvent.isHomeTeam = playerStats.isHomeTeam
                playerStats.saves += 1
            }
        }

        // 5. 插入新事件并保存
        context.insert(newEvent)
        //match.events.append(newEvent)

        do {
            try context.save()
            print("✅ [WatchKit] 已成功保存事件: \(eventType.rawValue)。比赛 \(match.id) 现在有 \(match.events.count) 个事件。")
        } catch {
            print("❌ [WatchKit] 保存上下文时出错: \(error)")
            // 如果保存失败，打印出更详细的错误
            print("Error details: \((error as NSError).userInfo)")
        }
    }

    private func translatedEventType(from raw: String) -> EventType {
        switch raw {
        case "goal": return .goal
        
        case "foul": return .foul
        case "save": return .save
        case "yellowCard": return .yellowCard
        case "redCard": return .redCard
        default: return .goal
        }
    }
    
    // 在 PickUpSoccer/Managers/WatchConnectivityManager.swift 文件中

    // 新增这个函数来替代旧的、有问题的 handleMatchEnded
    private func handleFinalSyncAndEndMatch(from userInfo: [String: Any], context: ModelContext) {
        // 1. 解析比赛ID
        guard let matchIdStr = userInfo["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdStr) else {
            print("❌ [Sync] 无法解析 matchId")
            return
        }

        // 2. 查找手机本地的比赛对象
        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? context.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else {
            print("❌ [Sync] 手机上未找到比赛，ID: \(matchIdStr)")
            return
        }
        
        // 如果比赛已经结束，则不再处理，防止重复执行
        guard match.status != .finished else {
            print("ℹ️ [Sync] 比赛已结束，忽略重复的结束指令。")
            return
        }

        // 3. 获取手机本地已有的事件ID集合，用于去重
        let localEventIds = Set(match.events.map { $0.id })

        // 4. 解析手表发来的事件列表
        guard let watchEventsPayload = userInfo["events"] as? [[String: Any]] else {
            print("⚠️ [Sync] 手表发来的数据中缺少事件列表。")
            // 即使没有事件，也应该结束比赛
            match.status = .finished
            match.updateMatchStats()
            try? context.save()
            return
        }

        // 5. 【核心同步逻辑】遍历手表事件，只添加手机没有的事件
        for eventPayload in watchEventsPayload {
            guard let eventIdStr = eventPayload["eventId"] as? String,
                  let eventId = UUID(uuidString: eventIdStr) else { continue }

            // 如果手机本地没有这个事件，就根据手表的数据创建一个新的
            if !localEventIds.contains(eventId) {
                print("🔄 [Sync] 发现并同步一个缺失的事件: \(eventIdStr)")
                
                guard let eventTypeStr = eventPayload["eventType"] as? String,
                      let eventType = EventType(rawValue: eventTypeStr),
                      let timestamp = eventPayload["timestamp"] as? TimeInterval,
                      let isHomeTeam = eventPayload["isHomeTeam"] as? Bool else { continue }
                
                let newEvent = MatchEvent(
                    id: eventId, // 使用手表传来的ID，保持一致
                    eventType: eventType,
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    isHomeTeam: isHomeTeam,
                    match: match
                )

                // 根据事件类型，关联正确的球员
                if eventType == .goal, let scorerIdStr = eventPayload["playerId"] as? String, let scorerId = UUID(uuidString: scorerIdStr) {
                    newEvent.scorer = match.playerStats.first(where: { $0.player?.id == scorerId })?.player
                    if let assistantIdStr = eventPayload["assistantId"] as? String, let assistantId = UUID(uuidString: assistantIdStr) {
                        newEvent.assistant = match.playerStats.first(where: { $0.player?.id == assistantId })?.player
                    }
                } else if eventType == .save, let goalkeeperIdStr = eventPayload["playerId"] as? String, let goalkeeperId = UUID(uuidString: goalkeeperIdStr) {
                    newEvent.goalkeeper = match.playerStats.first(where: { $0.player?.id == goalkeeperId })?.player
                }
                
                context.insert(newEvent)
            }
        }

        // 6. 【最终统计】在数据完全同步后，调用统计函数
        print("✅ [Sync] 数据同步完成，开始最终统计...")
        match.updateMatchStats()
        match.status = .finished

        // 7. 保存所有更改
        do {
            try context.save()
            print("🎉 [Sync] 比赛已成功结束，统计数据已更新！事件总数: \(match.events.count)")
        } catch {
            print("❌ [Sync] 保存最终比赛数据失败: \(error)")
        }
    }

    // !! 重要：你可以删除旧的 `handleMatchEnded` 函数了，因为它已经被 `handleFinalSyncAndEndMatch` 替代。

    private func handleScoreUpdate(from message: [String: Any]) {
        guard let matchIdStr = message["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdStr),
              let homeScore = message["homeScore"] as? Int,
              let awayScore = message["awayScore"] as? Int else { return }
        
        let matchPredicate = #Predicate<Match> { $0.id == matchId }
        guard let match = (try? modelContainer?.mainContext.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else { return }
        
        // Update score
        match.homeScore = homeScore
        match.awayScore = awayScore
        
        // Save and notify UI update
        try? modelContainer?.mainContext.save()
        print("iOS received score update: \(homeScore)-\(awayScore)")
    }
    
    func syncPlayerToWatchIfNeeded(player: Player, match: Match) {
        guard let isHomeTeam = match.playerStats.first(where: { $0.player?.id == player.id })?.isHomeTeam else {
            print("⚠️ Unable to determine player's team, skipping sync: \(player.name)")
            return
        }
        sendNewPlayerToWatch(player: player, isHomeTeam: isHomeTeam, matchId: match.id)
    }
    
    func sendNewPlayerToWatch(player: Player, isHomeTeam: Bool, matchId: UUID) {
        let payload: [String: Any] = [
            "command": "newPlayer",
            "playerId": player.id.uuidString, // ✅ This is SwiftData's ID
            "name": player.name,
            "isHomeTeam": isHomeTeam,
            "matchId": matchId.uuidString
        ]

        WCSession.default.sendMessage(payload, replyHandler: nil) { error in
            print("❌ Failed to sync new player: \(error.localizedDescription)")
        }
    }
    
    // In xinchenjiangau/pickupsoccer/PickUpSoccer-46a3117d7232204197ff70efc5a54e3337afc15c/Managers/WatchConnectivityManager.swift

    /// 将手机端创建的单个比赛事件实时同步到手表。
    func sendEventToWatch(_ event: MatchEvent, matchId: UUID) {
        guard let session = session, session.isReachable else {
            print("❌ [WatchKit] WCSession 不可达，无法发送事件。")
            return
        }

        var payload: [String: Any] = [
            "command": "newEvent", // 复用手表端已有的 "newEvent" 命令
            "matchId": matchId.uuidString,
            "eventType": event.eventType.rawValue,
            "isHomeTeam": event.isHomeTeam,
            "timestamp": event.timestamp.timeIntervalSince1970
        ]

        // 根据事件类型，添加不同的球员ID
        switch event.eventType {
        case .goal:
            payload["playerId"] = event.scorer?.id.uuidString
            if let assistantId = event.assistant?.id.uuidString {
                payload["assistantId"] = assistantId
            }
        case .save:
            // 对于扑救事件，我们将扑救者ID放在 "goalkeeperId" 字段
            payload["goalkeeperId"] = event.goalkeeper?.id.uuidString
        default:
            // 为其他未来可能出现的事件类型准备
            payload["playerId"] = event.scorer?.id.uuidString
        }

        session.sendMessage(payload, replyHandler: nil) { error in
            print("❌ [WatchKit] 发送新事件到手表失败: \(error.localizedDescription)")
        }
        print("✅ [WatchKit] 成功发送事件到手表: \(event.eventType.rawValue)")
    }
    // MARK: - 统一的消息接收与处理 (核心修正)

    // MARK: - 统一的消息接收与处理 (核心修正)

    // 1. 这是接收通过 sendMessage 发送的前台消息
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📨 Phone received message: \(message)")
        // MARK: - 核心修正
        // 使用 Task 将任务派发到 MainActor (主线程)
        Task {
            await handleReceivedMessage(message)
        }
    }

    

    // 3. 创建一个私有的、统一的消息处理器
    //    这个函数现在被标记为 async，并且因为它在 MainActor 类中，所以它会在主线程上执行
    private func handleReceivedMessage(_ message: [String: Any]) async {
        guard let command = message["command"] as? String else {
            print("❌ 接收到的消息中缺少 'command' 字段")
            return
        }

        // 因为调用它的地方已经确保了在主线程，所以这里不再需要 Task 或 @MainActor 块
        guard let context = self.modelContainer?.mainContext else {
            print("⚠️ [WatchKit] 无法获取 ModelContext")
            return
        }

        switch command {
        case "newEvent", "newEventBackup":
            self.handleNewEvent(from: message, context: context)
            
        case "matchEndedFromWatch":
            // 注意：因为 handleFinalSyncAndEndMatch 也需要访问 context，
            // 并且内部已经是 MainActor 安全的，所以可以直接调用。
            self.handleFinalSyncAndEndMatch(from: message, context: context)

        case "updateScore":
            self.handleScoreUpdate(from: message)

        default:
            print("⚠️ [WatchKit] 收到未知的 command: \(command)")
        }
    }
}
