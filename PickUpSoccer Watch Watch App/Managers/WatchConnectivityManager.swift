//
//  WatchConnectivityManager.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//

import Foundation
import WatchConnectivity
import SwiftData
import UserNotifications

@MainActor
class WatchConnectivityManager: NSObject, WCSessionDelegate, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    private let modelContainer: ModelContainer
    
    override init() {
        // 1. 设置独立的 SwiftData 容器
        self.modelContainer = try! ModelContainer(for: 
            WatchMatchSession.self,
            WatchPlayer.self,
            WatchMatchEvent.self
        )
        
        super.init()
        
        // 2. 激活 WCSession
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
        
        print("Watch端WCSession激活状态: \(WCSession.default.activationState.rawValue)")
    }

    // MARK: - WCSessionDelegate Methods
    
    

    
    private func handleNewPlayerFromPhone(_ message: [String: Any]) {
        guard let matchIdStr = message["matchId"] as? String,
            let matchId = UUID(uuidString: matchIdStr),
            let name = message["name"] as? String,
            let playerIdStr = message["playerId"] as? String,
            let playerId = UUID(uuidString: playerIdStr),
            let isHomeTeam = message["isHomeTeam"] as? Bool else {
            print("❌ 新球员数据解析失败")
            return
        }

        let modelContext = self.modelContainer.mainContext
        let matchPredicate = #Predicate<WatchMatchSession> { $0.matchId == matchId }

        guard let session = (try? modelContext.fetch(FetchDescriptor(predicate: matchPredicate)))?.first else {
            print("❌ 未找到匹配的比赛")
            return
        }

        // 查重：是否已有该球员
        let existing = try? modelContext.fetch(FetchDescriptor<WatchPlayer>())
            .first(where: { $0.playerId == playerId && $0.matchSession?.matchId == matchId })

        if existing != nil {
            print("⚠️ 已存在该球员，跳过添加：\(name)")
            return
        }

        // 若无重复，才添加
        let newPlayer = WatchPlayer(playerId: playerId, name: name, isHomeTeam: isHomeTeam)
        newPlayer.matchSession = session
        modelContext.insert(newPlayer)

        try? modelContext.save()
        print("✅ 手表端添加新球员成功：\(name)")

    }



    // MARK: - Data Handlers
    private func handleStartMatch(from payload: [String: Any]) {
        print("Watch端开始处理startMatch，payload: \(payload)")
        guard let command = payload["command"] as? String, command == "startMatch" else {
            return
        }
        
        let modelContext = self.modelContainer.mainContext
        
        // 1. 开始新比赛前，先清理掉所有旧数据
        try? modelContext.delete(model: WatchMatchSession.self)
        
        // 2. 解析收到的比赛数据
        guard let matchIdString = payload["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdString),
              let homeTeamName = payload["homeTeamName"] as? String,
              let awayTeamName = payload["awayTeamName"] as? String,
              let playersData = payload["players"] as? [[String: Any]] else {
            print("WatchConnectivityManager: Failed to parse start match payload.")
            return
        }
        
        // 3. 创建并保存新的比赛会话和球员信息
        let newSession = WatchMatchSession(matchId: matchId, homeTeamName: homeTeamName, awayTeamName: awayTeamName)
        modelContext.insert(newSession)
        
        for playerData in playersData {
            guard let playerIdStr = playerData["id"] as? String,
                  let playerId = UUID(uuidString: playerIdStr),
                  let name = playerData["name"] as? String,
                  let isHomeTeam = playerData["isHomeTeam"] as? Bool else { continue }
            let player = WatchPlayer(playerId: playerId, name: name, isHomeTeam: isHomeTeam)
            player.matchSession = newSession
            modelContext.insert(player)
        }
        
        try? modelContext.save()
        print("✅ Watch: New match session started and saved.")
        scheduleMatchStartNotification()
    }
    
    private func scheduleMatchStartNotification() {
        let content = UNMutableNotificationContent()
        content.title = "比赛已开始！"
        content.body = "点击查看实时统计数据。"
        content.sound = .default // 使用默认的提示音和震动

        // 创建一个触发器，让通知立即发送
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        // 创建通知请求
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        // 将请求添加到通知中心
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ 发送本地通知失败: \(error.localizedDescription)")
            } else {
                print("✅ 本地通知已成功发送")
            }
        }
    }

    // 清理手表上的所有比赛数据
    private func clearMatchData() {
        let modelContext = self.modelContainer.mainContext
        try? modelContext.delete(model: WatchMatchSession.self)
        try? modelContext.save()
        print("🧹 Watch: All match data cleared.")
    }

    // MARK: - Sending Data to Phone
    
    // 当在手表上结束比赛时调用
    func endMatchFromWatch() {
        guard let session = try? modelContainer.mainContext.fetch(FetchDescriptor<WatchMatchSession>()).first else {
            clearMatchData()
            return
        }
        
        let events = (try? modelContainer.mainContext.fetch(FetchDescriptor<WatchMatchEvent>())) ?? []
        print("🧪 全部事件数：\(events.count)")
        let sessionEvents = events.filter { $0.matchSession?.matchId == session.matchId }
        print("✅ 匹配当前比赛的事件数：\(sessionEvents.count)")
        
        let homeScore = sessionEvents.filter { $0.eventType == "goal" && ($0.scorer?.isHomeTeam ?? false) }.count
        let awayScore = sessionEvents.filter { $0.eventType == "goal" && !($0.scorer?.isHomeTeam ?? true) }.count
        

        let message: [String: Any] = [
            "command": "matchEndedFromWatch",
            "matchId": session.matchId.uuidString,
            "homeScore": homeScore,
            "awayScore": awayScore,
            "events": sessionEvents.map { event in
                [
                    "eventType": event.eventType,
                    "playerId": event.scorer?.playerId.uuidString ?? "",
                    "assistantId": event.assistant?.playerId.uuidString ?? "",
                    "isHomeTeam": event.scorer?.isHomeTeam ?? false,
                    "timestamp": event.timestamp.timeIntervalSince1970
                ]
            }
        ]
        
        // 1. 立即本地清理比赛数据和跳转
        clearMatchData()
        // 你可以在这里加一个提示，比如弹窗或跳转到"等待比赛"页面

        // 2. 发送消息到手机
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("❌ 手表端发送 matchEnded 消息失败: \(error.localizedDescription)")
        }
        
        
    }
    


    func sendNewEventToPhone(_ event: WatchMatchEvent) {
        guard WCSession.default.isReachable, let matchSession = event.matchSession else { return }
        guard WCSession.default.isReachable else {
            print("❌ Watch 无法连接到 Phone（isReachable == false）")
            return
        }

        


        var payload: [String: Any] = [
            "command": "newEvent",
            "matchId": matchSession.matchId.uuidString,
            "eventId": event.eventId.uuidString,
            "eventType": event.eventType,
            "timestamp": event.timestamp,
            // The phone-side logic will use isHomeTeam from the scorer/goalkeeper
        ]
        
        let isHome = event.scorer?.isHomeTeam ?? false
        let playerId: String
        if event.eventType == "save" {
            playerId = event.goalkeeper?.playerId.uuidString ?? ""
        } else {
            playerId = event.scorer?.playerId.uuidString ?? ""
        }
        payload["playerId"] = playerId // ✅ 添加这一行

        if let assistant = event.assistant { payload["assistantId"] = assistant.playerId.uuidString }
        if let goalkeeper = event.goalkeeper { payload["goalkeeperId"] = goalkeeper.playerId.uuidString }
        
        print("发送事件 payload: \(payload)")
        
        WCSession.default.sendMessage(payload, replyHandler: nil) { error in
            print("Error sending event: \(error.localizedDescription)")
        }
        
        backupEventToPhone(event)
    }
    
    
    func backupEventToPhone(_ event: WatchMatchEvent) {
        guard let matchSession = event.matchSession else { return }

        var payload: [String: Any] = [
            "command": "newEventBackup",
            "matchId": matchSession.matchId.uuidString,
            "eventId": event.eventId.uuidString,
            "eventType": event.eventType,
            "timestamp": event.timestamp
        ]
        
        payload["playerId"] = event.scorer?.playerId.uuidString ?? ""
        
        if let assistant = event.assistant {
            payload["assistantId"] = assistant.playerId.uuidString
        }
        if let goalkeeper = event.goalkeeper {
            payload["goalkeeperId"] = goalkeeper.playerId.uuidString
        }
        
        WCSession.default.transferUserInfo(payload)
        print("📦 事件备份已提交: \(payload)")
    }


    func sendNewPlayerToWatch(player: WatchPlayer, isHomeTeam: Bool, matchId: UUID) {
        let payload: [String: Any] = [
            "command": "newPlayer",
            "playerId": player.playerId.uuidString,
            "name": player.name,
            "isHomeTeam": isHomeTeam,
            "matchId": matchId.uuidString
        ]

        WCSession.default.sendMessage(payload, replyHandler: nil) { error in
            print("❌ 同步新球员失败：\(error.localizedDescription)")
        }
    }


    // ... WCSessionDelegate methods for iOS (not used on watchOS)

    // 新增：处理 iOS 端结束比赛
    private func handleMatchEndedFromPhone(_ message: [String: Any]) {
        print("手表端收到iOS端结束比赛消息")
        guard let matchIdStr = message["matchId"] as? String,
              let matchId = UUID(uuidString: matchIdStr) else { return }
        let modelContext = self.modelContainer.mainContext
        let sessionPredicate = #Predicate<WatchMatchSession> { $0.matchId == matchId }
        guard let session = (try? modelContext.fetch(FetchDescriptor(predicate: sessionPredicate)))?.first else { return }
        session.isActive = false
        try? modelContext.save()
        // 可选：跳转到主页面或显示提示
    }

    
}

// 修改后的代码
extension WatchConnectivityManager {
    // 这个方法您已经有了，保持不变
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            handleMessage(message)
        }
    }
    
    // MARK: - 新增的代理方法
    /// 当接收到来自手机的 transferUserInfo 数据时调用此方法。
    /// 这个方法可以在手表 App 未运行时，在后台被系统唤醒并执行。
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("⌚️ 手表端收到 userInfo (可能在后台被唤醒): \(userInfo)")
        // 我们直接复用处理前台消息的函数即可
        Task { @MainActor in
            handleMessage(userInfo)
        }
    }

    // 这个方法您已经有了，保持不变
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("📡 手表 session 激活完成: \(activationState.rawValue)")
        if let error = error {
            print("❌ 激活失败: \(error.localizedDescription)")
        }
        if activationState != .activated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                print("🔁 session 未激活，尝试重新激活")
                WCSession.default.activate()
            }
        }
    }
    
    // 这个方法您已经有了，保持不变
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        print("📶 Reachability 状态变化: \(session.isReachable)")
    }

    // 这个方法您已经有了，保持不变
    private func handleMessage(_ message: [String: Any]) {
        guard let command = message["command"] as? String else {
            print("❌ 未收到 command 字段")
            return
        }

        print("📨 手表端收到命令: \(command)")

        switch command {
        case "endMatch": clearMatchData()
        case "startMatch": handleStartMatch(from: message)
        case "matchEndedFromPhone": handleMatchEndedFromPhone(message)
        case "newPlayer": handleNewPlayerFromPhone(message)
        default: print("⚠️ 未知命令: \(command)")
        }
    }
}


