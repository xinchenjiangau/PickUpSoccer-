import Foundation
import SwiftData

struct CSVImporter {
    enum ImportError: LocalizedError {
        case invalidFormat
        case invalidData
        case missingRequiredFields
        case emptyFile
        case invalidHeader
        case invalidLine(Int, String)
        
        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "CSV 文件格式无效"
            case .invalidData:
                return "无法读取文件数据"
            case .missingRequiredFields:
                return "缺少必需的字段"
            case .emptyFile:
                return "文件为空"
            case .invalidHeader:
                return "表头格式不正确"
            case .invalidLine(let line, let detail):
                return "第 \(line) 行数据无效: \(detail)"
            }
        }
    }
    
    static func importPlayers(from csvString: String, modelContext: ModelContext) throws {
        print("开始导入 CSV 数据...")
        
        // 移除 BOM 标记并清理字符串
        let cleanString = csvString.replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 按行分割
        var lines = cleanString.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        guard !lines.isEmpty else {
            print("错误：文件为空")
            throw ImportError.emptyFile
        }
        
        // 获取并验证表头
        let header = lines.removeFirst().split(separator: ",").map(String.init)
        print("表头: \(header)")
        
        // 验证必需的字段
        let requiredFields = ["姓名", "号码", "位置"]
        for field in requiredFields {
            guard header.contains(field) else {
                print("错误：缺少必需字段 '\(field)'")
                throw ImportError.missingRequiredFields
            }
        }
        
        // 处理每一行数据
        for (index, line) in lines.enumerated() {
            do {
                let fields = parseCSVLine(line)
                print("处理第 \(index + 1) 行: \(fields)")
                
                guard fields.count >= header.count else {
                    throw ImportError.invalidLine(index + 1, "字段数量不匹配")
                }
                
                // 创建新球员
                let player = try createPlayer(from: fields)
                modelContext.insert(player)
                print("成功创建球员: \(player.name)")
            } catch {
                print("处理第 \(index + 1) 行时出错: \(error.localizedDescription)")
                throw error
            }
        }
        
        try modelContext.save()
        print("CSV 导入完成")
    }
    
    private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            switch char {
            case "\"":
                insideQuotes.toggle()
            case ",":
                if !insideQuotes {
                    fields.append(currentField.trimmingCharacters(in: .whitespaces))
                    currentField = ""
                } else {
                    currentField.append(char)
                }
            default:
                currentField.append(char)
            }
        }
        
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        return fields
    }
    
    private static func createPlayer(from fields: [String]) throws -> Player {
        // 解析必需字段
        let name = fields[0].replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw ImportError.invalidLine(0, "姓名不能为空")
        }
        
        guard let number = Int(fields[1].trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw ImportError.invalidLine(0, "号码必须是数字")
        }
        
        let positionStr = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let position = PlayerPosition(rawValue: positionStr) else {
            throw ImportError.invalidLine(0, "无效的位置: \(positionStr)")
        }
        
        // 创建球员
        let player = Player(name: name, number: number, position: position)
        
        // 设置可选字段
        if fields.count > 3 { player.phone = fields[3].isEmpty ? nil : fields[3] }
        if fields.count > 4 { player.email = fields[4].isEmpty ? nil : fields[4] }
        if fields.count > 5 { player.age = Int(fields[5]) }
        if fields.count > 6 { player.gender = fields[6].isEmpty ? nil : fields[6] }
        if fields.count > 7 { player.height = Double(fields[7]) }
        if fields.count > 8 { player.weight = Double(fields[8]) }
        
        // 创建初始统计数据
        if fields.count > 9 {
            let goals = Int(fields[9]) ?? 0
            let assists = Int(fields[10]) ?? 0
            let saves = Int(fields[11]) ?? 0
            let matches = Int(fields[12]) ?? 0
            
            if goals > 0 || assists > 0 || saves > 0 || matches > 0 {
                let stats = PlayerMatchStats(player: player)
                stats.goals = goals
                stats.assists = assists
                stats.saves = saves
                player.matchStats = [stats]
            }
        }
        
        return player
    }
} 