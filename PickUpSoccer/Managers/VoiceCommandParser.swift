import Foundation
import NaturalLanguage

class VoiceCommandParser {
    // 定义事件关键词
    private static let goalKeywords = [
        "进球", "得分", "射门", "破门", "打进", "进了", "射进",
        "打入", "踢进", "头球", "点球", "进网", "攻门成功"
    ]
    
    private static let saveKeywords = [
        "扑救", "救球", "扑出", "拦截", "挡出", "封堵", "没收",
        "抱住", "接住", "扑到", "守住", "防守", "拦下"
    ]
    
    // 相似度匹配阈值
    private static let similarityThreshold: Double = 0.7
    // 句子结构中名字和关键词的最大距离
    private static let maxWordDistance = 8
    
    static func parseCommand(_ text: String, match: Match) -> MatchEvent? {
        // 将文本转换为小写并移除空格
        let normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 使用NL框架进行分词
        let tokens = tokenizeText(normalizedText)
        
        // 解析进球命令
        if let goalEvent = parseGoalCommand(normalizedText, tokens: tokens, match: match) {
            return goalEvent
        }
        
        // 解析扑救命令
        if let saveEvent = parseSaveCommand(normalizedText, tokens: tokens, match: match) {
            return saveEvent
        }
        
        return nil
    }
    
    // 使用NL框架进行分词
    private static func tokenizeText(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange])
            tokens.append(token)
            return true
        }
        
        return tokens
    }
    
    private static func parseGoalCommand(_ text: String, tokens: [String], match: Match) -> MatchEvent? {
        // 获取主队和客队的球员
        let homeTeamPlayers = match.playerStats.filter { $0.isHomeTeam }.map { $0.player! }
        let awayTeamPlayers = match.playerStats.filter { !$0.isHomeTeam }.map { $0.player! }
        
        // 为每个球员创建可能的名字变体（包括同音字和昵称）
        let playerNameVariants = (homeTeamPlayers + awayTeamPlayers).flatMap { player -> [(Player, String)] in
            var variants = [
                (player, player.name),
                (player, player.name.lowercased()),
                // 添加常见的同音字变体
                (player, player.name.replacingOccurrences(of: "华", with: "花")),
                (player, player.name.replacingOccurrences(of: "伟", with: "威")),
                (player, player.name.replacingOccurrences(of: "军", with: "君")),
                (player, player.name.replacingOccurrences(of: "强", with: "墙")),
                // 如果有号码，添加号码识别
                (player, "\(player.number ?? 0)号"),
                (player, "号码\(player.number ?? 0)")
            ]
            // 如果有昵称，添加昵称识别
            if let nickname = player.nickname {
                variants.append((player, nickname))
            }
            return variants
        }
        
        // 使用模糊匹配查找最佳匹配的球员
        var bestMatch: (player: Player, similarity: Double, namePosition: Int)? = nil
        
        for (player, nameVariant) in playerNameVariants {
            // 查找最佳匹配位置
            if let (similarity, position) = findBestMatch(nameVariant, in: tokens) {
                if similarity >= similarityThreshold && (bestMatch == nil || similarity > bestMatch!.similarity) {
                    bestMatch = (player, similarity, position)
                }
            }
        }
        
        // 如果找到球员匹配
        if let (player, _, namePosition) = bestMatch {
            // 检查是否包含进球相关关键词
            if let (keyword, keywordPosition) = findClosestKeyword(tokens, keywords: goalKeywords) {
                // 计算名字和关键词之间的距离
                let distance = abs(namePosition - keywordPosition)
                
                if distance <= maxWordDistance {
                    let stats = match.playerStats.first(where: { $0.player?.id == player.id })
                    // 创建事件
                    let event = MatchEvent(
                        eventType: .goal,
                        timestamp: Date(),
                        isHomeTeam: stats?.isHomeTeam ?? false, // 这里要传递
                        match: match,
                        scorer: player,
                        assistant: nil
                    )
                    
                    // 设置事件所属队伍
                    if let stats = match.playerStats.first(where: { $0.player?.id == player.id }) {
                        event.isHomeTeam = stats.isHomeTeam
                    }
                    
                    // 尝试查找助攻球员
                    if let assistant = findAssistant(text, tokens: tokens, match: match, excludingPlayer: player) {
                        event.assistant = assistant
                    }
                    
                    return event
                }
            }
        }
        return nil
    }
    
    private static func parseSaveCommand(_ text: String, tokens: [String], match: Match) -> MatchEvent? {
        // 获取主队和客队的球员
        let homeTeamPlayers = match.playerStats.filter { $0.isHomeTeam }.map { $0.player! }
        let awayTeamPlayers = match.playerStats.filter { !$0.isHomeTeam }.map { $0.player! }
        
        // 为每个球员创建可能的名字变体（包括同音字和昵称）
        let playerNameVariants = (homeTeamPlayers + awayTeamPlayers).flatMap { player -> [(Player, String)] in
            var variants = [
                (player, player.name),
                (player, player.name.lowercased()),
                // 添加常见的同音字变体
                (player, player.name.replacingOccurrences(of: "华", with: "花")),
                (player, player.name.replacingOccurrences(of: "伟", with: "威")),
                (player, player.name.replacingOccurrences(of: "军", with: "君")),
                (player, player.name.replacingOccurrences(of: "强", with: "墙")),
                // 如果有号码，添加号码识别
                (player, "\(player.number ?? 0)号"),
                (player, "号码\(player.number ?? 0)")
            ]
            // 如果有昵称，添加昵称识别
            if let nickname = player.nickname {
                variants.append((player, nickname))
            }
            return variants
        }
        
        // 使用模糊匹配查找最佳匹配的球员
        var bestMatch: (player: Player, similarity: Double, namePosition: Int)? = nil
        
        for (player, nameVariant) in playerNameVariants {
            // 查找最佳匹配位置
            if let (similarity, position) = findBestMatch(nameVariant, in: tokens) {
                if similarity >= similarityThreshold && (bestMatch == nil || similarity > bestMatch!.similarity) {
                    bestMatch = (player, similarity, position)
                }
            }
        }
        
        // 如果找到球员匹配
        if let (player, _, namePosition) = bestMatch {
            // 检查是否包含扑救相关关键词
            if let (_, keywordPosition) = findClosestKeyword(tokens, keywords: saveKeywords) {
                // 计算名字和关键词之间的距离
                let distance = abs(namePosition - keywordPosition)
                
                if distance <= maxWordDistance {
                    let stats = match.playerStats.first(where: { $0.player?.id == player.id })
                    // 创建事件
                    let event = MatchEvent(
                        eventType: .save,
                        timestamp: Date(),
                        isHomeTeam: stats?.isHomeTeam ?? false, // 这里要传递
                        match: match,
                        scorer: player,
                        assistant: nil
                    )
                    
                    // 设置事件所属队伍
                    if let stats = match.playerStats.first(where: { $0.player?.id == player.id }) {
                        event.isHomeTeam = stats.isHomeTeam
                    }
                    
                    return event
                }
            }
        }
        return nil
    }
    
    // 查找助攻球员
    private static func findAssistant(_ text: String, tokens: [String], match: Match, excludingPlayer: Player) -> Player? {
        // 助攻关键词
        let assistKeywords = ["助攻", "传球", "传中", "传给", "传", "给"]
        
        // 获取所有球员
        let allPlayers = match.playerStats.map { $0.player! }
        
        // 为每个球员创建可能的名字变体
        let playerNameVariants = allPlayers.filter { $0.id != excludingPlayer.id }.flatMap { player -> [(Player, String)] in
            var variants = [
                (player, player.name),
                (player, player.name.lowercased()),
                // 添加常见的同音字变体
                (player, player.name.replacingOccurrences(of: "华", with: "花")),
                (player, player.name.replacingOccurrences(of: "伟", with: "威")),
                // 如果有号码，添加号码识别
                (player, "\(player.number ?? 0)号")
            ]
            // 如果有昵称，添加昵称识别
            if let nickname = player.nickname {
                variants.append((player, nickname))
            }
            return variants
        }
        
        // 使用模糊匹配查找最佳匹配的助攻球员
        var bestMatch: (player: Player, similarity: Double, namePosition: Int)? = nil
        
        for (player, nameVariant) in playerNameVariants {
            // 查找最佳匹配位置
            if let (similarity, position) = findBestMatch(nameVariant, in: tokens) {
                if similarity >= similarityThreshold && (bestMatch == nil || similarity > bestMatch!.similarity) {
                    bestMatch = (player, similarity, position)
                }
            }
        }
        
        // 如果找到球员匹配
        if let (player, _, namePosition) = bestMatch {
            // 检查是否包含助攻相关关键词
            if let (_, keywordPosition) = findClosestKeyword(tokens, keywords: assistKeywords) {
                // 计算名字和关键词之间的距离
                let distance = abs(namePosition - keywordPosition)
                
                if distance <= maxWordDistance {
                    return player
                }
            }
        }
        
        return nil
    }
    
    // 查找最接近的关键词及其位置
    private static func findClosestKeyword(_ tokens: [String], keywords: [String]) -> (keyword: String, position: Int)? {
        for (index, token) in tokens.enumerated() {
            for keyword in keywords {
                if calculateSimilarity(token, keyword) >= similarityThreshold {
                    return (keyword, index)
                }
            }
        }
        return nil
    }
    
    // 查找字符串在分词中的最佳匹配位置
    private static func findBestMatch(_ target: String, in tokens: [String]) -> (similarity: Double, position: Int)? {
        var bestMatch: (similarity: Double, position: Int)? = nil
        
        // 单个词匹配
        for (index, token) in tokens.enumerated() {
            let similarity = calculateSimilarity(token, target)
            if similarity >= similarityThreshold && (bestMatch == nil || similarity > bestMatch!.similarity) {
                bestMatch = (similarity, index)
            }
        }
        
        // 连续词组匹配（处理多字名字，如"张三"可能被分词为"张"和"三"）
        if target.count > 1 {
            for startIndex in 0..<tokens.count-1 {
                let combinedToken = tokens[startIndex...min(startIndex+1, tokens.count-1)].joined()
                let similarity = calculateSimilarity(combinedToken, target)
                if similarity >= similarityThreshold && (bestMatch == nil || similarity > bestMatch!.similarity) {
                    bestMatch = (similarity, startIndex)
                }
            }
        }
        
        return bestMatch
    }
    
    // 计算两个字符串的相似度（Levenshtein距离的归一化版本）
    private static func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        let distance = levenshteinDistance(s1, s2)
        let maxLength = max(s1.count, s2.count)
        return maxLength > 0 ? 1.0 - Double(distance) / Double(maxLength) : 1.0
    }
    
    // 计算Levenshtein距离
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let m = s1Array.count
        let n = s2Array.count
        
        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            dp[i][0] = i
        }
        
        for j in 0...n {
            dp[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                if s1Array[i-1] == s2Array[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = min(dp[i-1][j-1] + 1, min(dp[i][j-1] + 1, dp[i-1][j] + 1))
                }
            }
        }
        
        return dp[m][n]
    }
} 