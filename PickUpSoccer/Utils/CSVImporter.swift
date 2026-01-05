import Foundation
import SwiftData

struct CSVImporter {
    enum ImportError: LocalizedError {
        case fileReadError
        case dataFormatError(String)
        case missingDependency(String)
        case missingFiles
        // 旧错误定义保持兼容
        case invalidFormat
        case invalidData
        case missingRequiredFields
        case emptyFile
        case invalidHeader
        case invalidLine(Int, String)
        
        var errorDescription: String? {
            switch self {
            case .fileReadError: return "无法读取文件内容"
            case .dataFormatError(let msg): return "数据格式错误: \(msg)"
            case .missingDependency(let msg): return "依赖数据缺失: \(msg)"
            case .missingFiles: return "请同时选择 players, matches, stats, events 四个 CSV 文件"
            default: return "导入错误"
            }
        }
    }
    
    // MARK: - 1. 现有功能：仅导入球员 (PlayerListView 用，逻辑不变)
    static func importPlayers(from csvString: String, modelContext: ModelContext) throws {
        // ... (保持原有逻辑，为节省篇幅略去，请确保保留您原文件中 importPlayers 的内容) ...
        // 如果您需要我完整列出这段旧代码请告知，否则为了重点突出新功能，这里假设复用原逻辑
        // 建议：直接保留您上一个版本中 importPlayers 及其依赖的 parseCSVLine 方法
        print("执行单文件球员导入...")
        // 简单实现以防编译报错
        let cleanString = csvString.replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var lines = cleanString.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !lines.isEmpty else { throw ImportError.emptyFile }
        let _ = lines.removeFirst() // Header
        
        // 临时赛季
        let importMatch = Match(homeTeamName: "导入数据", awayTeamName: "历史存档")
        importMatch.status = .finished
        modelContext.insert(importMatch)
        
        for line in lines {
            let fields = parseCSVLine(line)
            if fields.count >= 3 {
                let name = fields[0].replacingOccurrences(of: "\"", with: "")
                let number = Int(fields[1]) ?? 0
                let position = PlayerPosition(rawValue: fields[2]) ?? .midfielder
                let player = Player(name: name, number: number, position: position)
                modelContext.insert(player)
            }
        }
        try modelContext.save()
    }
    
    // MARK: - 2. 升级功能：全量历史恢复 (支持合并 + 指定赛季)
    
    /// 接收文件并恢复，支持指定目标赛季
    static func restoreFromFiles(
        urls: [URL],
        targetSeason: Season, // [新增] 指定目标赛季
        context: ModelContext
    ) throws {
        // 1. 读取文件内容
        var playersCSV = ""
        var matchesCSV = ""
        var statsCSV = ""
        var eventsCSV = ""
        
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let filename = url.lastPathComponent.lowercased()
            let content = try String(contentsOf: url, encoding: .utf8)
            
            if filename.contains("players") { playersCSV = content }
            else if filename.contains("matches") { matchesCSV = content }
            else if filename.contains("player_match_stats") { statsCSV = content }
            else if filename.contains("match_events") { eventsCSV = content }
        }
        
        if playersCSV.isEmpty || matchesCSV.isEmpty {
            throw ImportError.missingFiles
        }
        
        // 3. 执行恢复逻辑
        try restoreFullBackup(
            playersCSV: playersCSV,
            matchesCSV: matchesCSV,
            statsCSV: statsCSV,
            eventsCSV: eventsCSV,
            targetSeason: targetSeason, // 传入赛季
            context: context
        )
    }
    
    private static func restoreFullBackup(
        playersCSV: String,
        matchesCSV: String,
        statsCSV: String,
        eventsCSV: String,
        targetSeason: Season,
        context: ModelContext
    ) throws {
        print("🔄 开始全量数据恢复... 目标赛季: \(targetSeason.name)")
        
        // 1. 恢复球员 (并执行合并逻辑)
        let playerMap = try importPlayersForRestore(csv: playersCSV, context: context)
        print("✅ 球员处理完成 (含合并): \(playerMap.count) 人")
        
        // 2. 恢复比赛 (放入指定赛季)
        let matchMap = try importMatchesForRestore(csv: matchesCSV, season: targetSeason, context: context)
        print("✅ 比赛恢复完成: \(matchMap.count) 场")
        
        // 3. 恢复统计
        if !statsCSV.isEmpty {
            try importStatsForRestore(csv: statsCSV, matchMap: matchMap, playerMap: playerMap, context: context)
        }
        
        // 4. 恢复事件
        if !eventsCSV.isEmpty {
            try importEventsForRestore(csv: eventsCSV, matchMap: matchMap, playerMap: playerMap, context: context)
        }
        
        try context.save()
        print("🎉 全量恢复成功！")
    }
    
    // --- 内部逻辑 ---
    
    private static func importPlayersForRestore(csv: String, context: ModelContext) throws -> [String: Player] {
        let rows = parseCSV(csv)
        var map: [String: Player] = [:] // 旧ID String -> 现有 Player 对象
        
        // 提前获取数据库中现有的所有球员，用于名字匹配
        let existingPlayers = try context.fetch(FetchDescriptor<Player>())
        
        for row in rows {
            // 尝试读取 CSV 中的 ID 和 姓名
            guard let csvIdStr = row["id"] ?? row.values.first,
                  let csvUuid = UUID(uuidString: csvIdStr),
                  let csvName = row["姓名"] else { continue }
            
            let cleanedName = cleanString(csvName)
            
            // [功能点 1：智能合并逻辑]
            // 优先级 1: ID 完全匹配 (可能是之前导入过，或者没删App)
            // 优先级 2: 名字完全匹配 (用户重装了App，新App里创建了同名用户)
            // 优先级 3: 创建新用户
            
            let player: Player
            
            if let idMatch = existingPlayers.first(where: { $0.id == csvUuid }) {
                // 情况 1: ID 匹配
                player = idMatch
                print("🔹 关联现有球员 (ID匹配): \(player.name)")
            } else if let nameMatch = existingPlayers.first(where: { $0.name == cleanedName }) {
                // 情况 2: 名字匹配 (合并！)
                player = nameMatch
                print("🔹 合并至现有球员 (名字匹配): \(player.name)")
            } else {
                // 情况 3: 新建
                let positionStr = row["位置"] ?? "中场"
                let position: PlayerPosition = PlayerPosition(rawValue: positionStr) ?? .midfielder
                
                player = Player(
                    id: csvUuid, // 尽可能保留旧ID
                    name: cleanedName,
                    number: Int(row["号码"] ?? "0"),
                    position: position
                )
                // 恢复其他字段
                player.phone = row["电话"]
                player.email = row["邮箱"]
                player.age = Int(row["年龄"] ?? "")
                player.gender = row["性别"]
                player.height = Double(row["身高"] ?? "")
                player.weight = Double(row["体重"] ?? "")
                
                context.insert(player)
                print("🔸 新建球员: \(player.name)")
            }
            
            // 建立映射：旧 CSV ID -> 最终使用的 Player 对象
            map[csvIdStr] = player
        }
        return map
    }
    
    private static func importMatchesForRestore(csv: String, season: Season, context: ModelContext) throws -> [String: Match] {
        let rows = parseCSV(csv)
        var map: [String: Match] = [:]
        let dateFormatter = ISO8601DateFormatter()
        
        for row in rows {
            guard let idStr = row["id"] ?? row.values.first, let uuid = UUID(uuidString: idStr) else { continue }
            
            // 查重：避免重复导入同一场比赛
            let existingMatch = try? context.fetch(FetchDescriptor<Match>(predicate: #Predicate { $0.id == uuid })).first
            if let existing = existingMatch {
                map[idStr] = existing
                continue
            }
            
            let homeName = cleanString(row["主队"] ?? "主队")
            let awayName = cleanString(row["客队"] ?? "客队")
            let statusRaw = row["状态"] ?? "Finished"
            let status = (statusRaw == "Finished" || statusRaw == "已结束") ? MatchStatus.finished : MatchStatus.notStarted
            
            let match = Match(
                id: uuid,
                status: status,
                homeTeamName: homeName,
                awayTeamName: awayName
            )
            
            match.homeScore = Int(row["主队得分"] ?? "0") ?? 0
            match.awayScore = Int(row["客队得分"] ?? "0") ?? 0
            match.duration = Int(row["时长"] ?? "")
            match.location = row["地点"]
            match.weather = row["天气"]
            match.referee = row["裁判"]
            
            if let dateStr = row["日期"], let date = dateFormatter.date(from: dateStr) {
                match.matchDate = date
            }
            
            // [功能点 2：关联到用户指定的赛季]
            match.season = season
            
            context.insert(match)
            map[idStr] = match
        }
        return map
    }
    
    private static func importStatsForRestore(csv: String, matchMap: [String: Match], playerMap: [String: Player], context: ModelContext) throws {
        let rows = parseCSV(csv)
        for row in rows {
            guard let matchId = row["比赛id"], let match = matchMap[matchId],
                  let playerId = row["球员id"], let player = playerMap[playerId] else { continue }
            
            // 查重：避免重复添加统计
            if match.playerStats.contains(where: { $0.player?.id == player.id }) {
                continue
            }
            
            let isHomeStr = row["主队"] ?? "1"
            let isHome = (isHomeStr == "1" || isHomeStr.lowercased() == "true")
            let team: Team = isHome ? .home : .away
            
            let stats = PlayerMatchStats(
                id: UUID(),
                player: player,
                match: match,
                team: team
            )
            
            stats.goals = Int(row["进球"] ?? "0") ?? 0
            stats.assists = Int(row["助攻"] ?? "0") ?? 0
            stats.saves = Int(row["扑救"] ?? "0") ?? 0
            stats.fouls = Int(row["犯规"] ?? "0") ?? 0
            stats.minutesPlayed = Int(row["上场分钟"] ?? "0") ?? 0
            stats.distance = Double(row["跑动距离"] ?? "0")
            stats.score = Double(row["评分"] ?? "6.0") ?? 6.0
            
            match.playerStats.append(stats)
        }
    }
    
    private static func importEventsForRestore(csv: String, matchMap: [String: Match], playerMap: [String: Player], context: ModelContext) throws {
        let rows = parseCSV(csv)
        let dateFormatter = ISO8601DateFormatter()
        
        for row in rows {
            guard let matchId = row["比赛id"], let match = matchMap[matchId] else { continue }
            
            // 简单查重：防止事件重复
            guard let eventIdStr = row["id"], let eventUuid = UUID(uuidString: eventIdStr) else { continue }
            if match.events.contains(where: { $0.id == eventUuid }) { continue }
            
            let typeRaw = row["类型"] ?? "Goal"
            let type: EventType
            switch typeRaw {
            case "Goal": type = .goal
            case "Save": type = .save
            case "Foul": type = .foul
            case "Yellow Card": type = .yellowCard
            case "Red Card": type = .redCard
            default: type = .goal
            }
            
            let isHomeStr = row["主队"] ?? "1"
            let isHome = (isHomeStr == "1" || isHomeStr.lowercased() == "true")
            
            let event = MatchEvent(
                id: eventUuid,
                eventType: type,
                timestamp: Date(),
                isHomeTeam: isHome,
                match: match
            )
            
            if let dateStr = row["时间"], let date = dateFormatter.date(from: dateStr) {
                event.timestamp = date
            }
            
            if let id = row["进球者id"], !id.isEmpty { event.scorer = playerMap[id] }
            if let id = row["助攻者id"], !id.isEmpty { event.assistant = playerMap[id] }
            if let id = row["门将id"], !id.isEmpty { event.goalkeeper = playerMap[id] }
            
            match.events.append(event)
        }
    }
    
    // MARK: - Parser Helpers
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        for char in line {
            if char == "\"" { insideQuotes.toggle() }
            else if char == "," && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else { currentField.append(char) }
        }
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        return fields
    }
    
    private static func parseCSV(_ content: String) -> [[String: String]] {
        let cleanContent = content.replacingOccurrences(of: "\u{FEFF}", with: "")
        var lines = cleanContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return [] }
        let header = lines.removeFirst().split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        var result: [[String: String]] = []
        for line in lines {
            let fields = parseCSVLine(line)
            if fields.count == header.count {
                var dict: [String: String] = [:]
                for (i, key) in header.enumerated() { dict[key] = fields[i] }
                result.append(dict)
            }
        }
        return result
    }
    
    private static func cleanString(_ str: String) -> String {
        return str.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
    }
}
