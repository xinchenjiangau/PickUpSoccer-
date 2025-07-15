import Foundation

struct CSVExporter {
    /// 将所有 Player 对象转换为 CSV 字符串
    static func exportPlayers(_ players: [Player]) -> String {
        let header = "id,姓名,号码,位置,电话,邮箱,年龄,性别,身高,体重\n"
        var csv = header
        for player in players {
            let row = [
                player.id.uuidString,
                "\"\(player.name)\"",
                "\(player.number ?? 0)",
                player.position.rawValue,
                player.phone ?? "",
                player.email ?? "",
                "\(player.age ?? 0)",
                player.gender ?? "",
                "\(player.height ?? 0)",
                "\(player.weight ?? 0)"
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }
    
    /// 将 CSV 字符串写入文件并返回文件 URL
    static func saveToFile(_ csv: String) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "球员列表_\(timestamp).csv"
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            // 添加 BOM 以支持中文
            if let bomData = "\u{FEFF}".data(using: .utf8),
               let csvData = csv.data(using: .utf8) {
                let data = bomData + csvData
                try data.write(to: url)
                return url
            }
        } catch {
            print("写入 CSV 文件失败: \(error)")
        }
        return nil
    }

    // 2. 导出比赛
    static func exportMatches(_ matches: [Match]) -> String {
        let header = "id,状态,主队,客队,日期,地点,天气,裁判,时长,主队得分,客队得分,赛季id\n"
        var csv = header
        let formatter = ISO8601DateFormatter()
        for match in matches {
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
                match.season?.id.uuidString ?? ""
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    // 3. 导出球员-比赛统计
    static func exportPlayerMatchStats(_ stats: [PlayerMatchStats]) -> String {
        let header = "id,球员id,比赛id,主队,进球,助攻,扑救,犯规,上场分钟,跑动距离\n"
        var csv = header
        for stat in stats {
            let row = [
                stat.id.uuidString,
                stat.player?.id.uuidString ?? "",
                stat.match?.id.uuidString ?? "",
                stat.isHomeTeam ? "1" : "0",
                "\(stat.goals)",
                "\(stat.assists)",
                "\(stat.saves)",
                "\(stat.fouls)",
                "\(stat.minutesPlayed)",
                "\(stat.distance ?? 0)"
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    // 4. 导出比赛事件
    static func exportMatchEvents(_ events: [MatchEvent]) -> String {
        let header = "id,类型,时间,主队,比赛id,进球者id,助攻者id\n"
        var csv = header
        let formatter = ISO8601DateFormatter()
        for event in events {
            let row = [
                event.id.uuidString,
                event.eventType.rawValue,
                formatter.string(from: event.timestamp),
                event.isHomeTeam ? "1" : "0",
                event.match?.id.uuidString ?? "",
                event.scorer?.id.uuidString ?? "",
                event.assistant?.id.uuidString ?? ""
            ].joined(separator: ",")
            csv += row + "\n"
        }
        return csv
    }

    // 5. 一键导出所有数据
    static func exportAllData(players: [Player], matches: [Match]) -> [String: String] {
        let allStats = players.flatMap { $0.matchStats }
        let allEvents = matches.flatMap { $0.events }
        return [
            "players.csv": exportPlayers(players),
            "matches.csv": exportMatches(matches),
            "player_match_stats.csv": exportPlayerMatchStats(allStats),
            "match_events.csv": exportMatchEvents(allEvents)
        ]
    }
} 