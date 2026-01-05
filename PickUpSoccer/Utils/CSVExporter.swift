import Foundation

struct CSVExporter {
    
    // MARK: - 🛡️ 安全核心：防崩溃白名单
    /// 建立有效球员的内存地址集合。
    /// 只有在这个名单里的对象，我们才敢去访问它的 ID 或 Name。
    /// 这是防止访问“已删除僵尸对象”导致崩溃的唯一有效手段。
    private static func createSafePlayerSet(_ players: [Player]) -> Set<ObjectIdentifier> {
        return Set(players.map { ObjectIdentifier($0) })
    }
    
    // MARK: - 1. 导出球员列表 (含生涯统计)
    static func exportPlayers(_ players: [Player]) -> String {
        // 新增统计列：总进球, 总助攻, 场均评分, MVP次数等
        let header = "id,姓名,号码,位置,电话,邮箱,年龄,性别,身高,体重,总进球,总助攻,总扑救,总场次,场均评分,MVP次数\n"
        var csv = header
        
        for player in players {
            // 基础防崩溃过滤
            guard !player.isDeleted else { continue }
            
            // 计算统计数据
            let totalGoals = player.totalGoals
            let totalAssists = player.totalAssists
            let totalSaves = player.totalSaves
            let totalMatches = player.totalMatches
            let avgScore = String(format: "%.1f", player.averageScoreForSeason(nil))
            let mvpCount = player.mvpCountForSeason(nil)
            
            let row = [
                player.id.uuidString,
                "\"\(player.name)\"", // 加引号防止名字含逗号破坏格式
                "\(player.number ?? 0)",
                player.position.rawValue,
                player.phone ?? "",
                player.email ?? "",
                "\(player.age ?? 0)",
                player.gender ?? "",
                "\(player.height ?? 0)",
                "\(player.weight ?? 0)",
                // --- 新增数据 ---
                "\(totalGoals)",
                "\(totalAssists)",
                "\(totalSaves)",
                "\(totalMatches)",
                avgScore,
                "\(mvpCount)"
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    // MARK: - 2. 导出比赛 (含MVP/最佳射手名字)
    static func exportMatches(_ matches: [Match], validPlayerSet: Set<ObjectIdentifier>) -> String {
        let header = "id,状态,主队,客队,日期,地点,天气,裁判,时长,主队得分,客队得分,赛季id,MVP,最佳射手,最佳门将,最佳组织者\n"
        var csv = header
        let formatter = ISO8601DateFormatter()
        
        for match in matches {
            // 安全获取名字的闭包（必须在白名单内才读取）
            let getSafeName: (Player?) -> String = { p in
                if let player = p, validPlayerSet.contains(ObjectIdentifier(player)) {
                    return "\"\(player.name)\""
                }
                return ""
            }
            
            let row = [
                match.id.uuidString,
                match.status.rawValue,
                match.homeTeamName,
                match.awayTeamName,
                formatter.string(from: match.matchDate),
                match.location ?? "",
                match.weather ?? "",
                match.referee ?? "",
                "\(match.duration ?? 0)",
                "\(match.homeScore)",
                "\(match.awayScore)",
                match.season?.id.uuidString ?? "",
                // --- 新增数据 ---
                getSafeName(match.mvp),
                getSafeName(match.topScorer),
                getSafeName(match.topGoalkeeper),
                getSafeName(match.topPlaymaker)
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    // MARK: - 3. 导出统计 (含单场评分)
    static func exportPlayerMatchStats(_ stats: [PlayerMatchStats], validPlayerSet: Set<ObjectIdentifier>) -> String {
        let header = "id,球员id,球员姓名,比赛id,主队,进球,助攻,扑救,犯规,上场分钟,跑动距离,评分\n"
        var csv = header
        
        for stat in stats {
            // 安全获取ID和名字
            let playerId: String
            let playerName: String
            
            if let player = stat.player, validPlayerSet.contains(ObjectIdentifier(player)) {
                playerId = player.id.uuidString
                playerName = "\"\(player.name)\""
            } else {
                playerId = ""
                playerName = "未知/已删除"
            }

            let scoreStr = String(format: "%.1f", stat.score)
            
            let row = [
                stat.id.uuidString,
                playerId,
                playerName,
                stat.match?.id.uuidString ?? "",
                stat.isHomeTeam ? "1" : "0",
                "\(stat.goals)",
                "\(stat.assists)",
                "\(stat.saves)",
                "\(stat.fouls)",
                "\(stat.minutesPlayed)",
                "\(stat.distance ?? 0)",
                scoreStr // --- 新增评分 ---
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    // MARK: - 4. 导出事件 (含门将ID)
    static func exportMatchEvents(_ events: [MatchEvent], validPlayerSet: Set<ObjectIdentifier>) -> String {
        let header = "id,类型,时间,主队,比赛id,进球者id,助攻者id,门将id\n"
        var csv = header
        let formatter = ISO8601DateFormatter()
        
        for event in events {
            let getSafeID: (Player?) -> String = { p in
                if let player = p, validPlayerSet.contains(ObjectIdentifier(player)) {
                    return player.id.uuidString
                }
                return ""
            }
            
            let row = [
                event.id.uuidString,
                event.eventType.rawValue,
                formatter.string(from: event.timestamp),
                event.isHomeTeam ? "1" : "0",
                event.match?.id.uuidString ?? "",
                getSafeID(event.scorer),
                getSafeID(event.assistant),
                getSafeID(event.goalkeeper) // --- 新增门将 ---
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }
    
    // MARK: - 5. 🆕 导出配合统计 (最佳喂饼/终结)
    static func exportPlayerPartnerships(players: [Player], matches: [Match], validPlayerSet: Set<ObjectIdentifier>) -> String {
        // 1. 准备统计容器
        var receivedAssistFrom: [UUID: [UUID: Int]] = [:] // A被B助攻多少次
        var givenAssistTo: [UUID: [UUID: Int]] = [:]      // A助攻给B多少次
        
        let allEvents = matches.flatMap { $0.events }
        
        // 2. 遍历所有进球，建立关系网
        for event in allEvents {
            // 必须是进球，且助攻者和进球者都必须在“安全白名单”里
            guard event.eventType == .goal,
                  let scorer = event.scorer, validPlayerSet.contains(ObjectIdentifier(scorer)),
                  let assistant = event.assistant, validPlayerSet.contains(ObjectIdentifier(assistant)) else {
                continue
            }
            
            let scorerID = scorer.id
            let assistantID = assistant.id
            
            // 记录数据
            receivedAssistFrom[scorerID, default: [:]][assistantID, default: 0] += 1
            givenAssistTo[assistantID, default: [:]][scorerID, default: 0] += 1
        }
        
        // 名字查找表
        var playerNames: [UUID: String] = [:]
        for p in players where validPlayerSet.contains(ObjectIdentifier(p)) {
            playerNames[p.id] = p.name
        }
        
        let header = "id,姓名,最佳喂饼人(谁给他助攻最多),被助攻次数,最佳终结者(他给谁助攻最多),助攻次数\n"
        var csv = header
        
        for player in players {
            // 只处理有效球员
            guard validPlayerSet.contains(ObjectIdentifier(player)) else { continue }
            
            // A. 最佳喂饼人 (谁助攻给他最多?)
            let receivedStats = receivedAssistFrom[player.id]
            let bestProviderStat = receivedStats?.max { $0.value < $1.value }
            let bestProviderName = bestProviderStat.flatMap { playerNames[$0.key] } ?? "无"
            let bestProviderCount = bestProviderStat?.value ?? 0
            
            // B. 最佳终结者 (他助攻给谁最多?)
            let givenStats = givenAssistTo[player.id]
            let bestReceiverStat = givenStats?.max { $0.value < $1.value }
            let bestReceiverName = bestReceiverStat.flatMap { playerNames[$0.key] } ?? "无"
            let bestReceiverCount = bestReceiverStat?.value ?? 0
            
            let row = [
                player.id.uuidString,
                "\"\(player.name)\"",
                "\"\(bestProviderName)\"",
                "\(bestProviderCount)",
                "\"\(bestReceiverName)\"",
                "\(bestReceiverCount)"
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    // MARK: - 辅助：保存临时文件
    static func saveTempFile(content: String, fileName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        do {
            let bom = "\u{FEFF}" // 加 BOM 防乱码
            let fullContent = bom + content
            try fullContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("保存文件失败 \(fileName): \(error)")
            return nil
        }
    }

    // MARK: - 6. 🚀 终极一键导出 (生成 URL 数组)
    // 这是 UI 层实现“一次性分享所有文件”的关键接口
    static func exportAllDataToURLs(players: [Player], matches: [Match]) -> [URL] {
        // [关键] 1. 过滤已删除球员
        let validPlayers = players.filter { !$0.isDeleted }
        // [关键] 2. 创建白名单 (Crash Protection)
        let validPlayerSet = createSafePlayerSet(validPlayers)
        
        // 准备关联数据
        let allStats = validPlayers.flatMap { player -> [PlayerMatchStats] in
            return player.matchStats.filter { $0.match != nil }
        }
        let allEvents = matches.flatMap { $0.events }
        
        // 生成所有 CSV 内容
        let csvs: [(name: String, content: String)] = [
            ("players.csv", exportPlayers(validPlayers)),
            ("matches.csv", exportMatches(matches, validPlayerSet: validPlayerSet)),
            ("player_match_stats.csv", exportPlayerMatchStats(allStats, validPlayerSet: validPlayerSet)),
            ("match_events.csv", exportMatchEvents(allEvents, validPlayerSet: validPlayerSet)),
            // 包含您要的新统计
            ("player_partnerships.csv", exportPlayerPartnerships(players: validPlayers, matches: matches, validPlayerSet: validPlayerSet))
        ]
        
        // 保存并返回 URLs
        var urls: [URL] = []
        for item in csvs {
            if let url = saveTempFile(content: item.content, fileName: item.name) {
                urls.append(url)
            }
        }
        return urls
    }
    
    // 兼容旧接口 (如果其他地方还在用)
    static func exportAllData(players: [Player], matches: [Match]) -> [String: String] {
        let validPlayers = players.filter { !$0.isDeleted }
        let validPlayerSet = createSafePlayerSet(validPlayers)
        let allStats = validPlayers.flatMap { $0.matchStats.filter { $0.match != nil } }
        let allEvents = matches.flatMap { $0.events }
        
        return [
            "players.csv": exportPlayers(validPlayers),
            "matches.csv": exportMatches(matches, validPlayerSet: validPlayerSet),
            "player_match_stats.csv": exportPlayerMatchStats(allStats, validPlayerSet: validPlayerSet),
            "match_events.csv": exportMatchEvents(allEvents, validPlayerSet: validPlayerSet),
            "player_partnerships.csv": exportPlayerPartnerships(players: validPlayers, matches: matches, validPlayerSet: validPlayerSet)
        ]
    }
}
