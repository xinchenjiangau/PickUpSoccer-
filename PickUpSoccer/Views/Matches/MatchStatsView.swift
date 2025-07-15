import SwiftUI
import SwiftData

struct MatchStatsView: View {
    let match: Match
    @Environment(\.dismiss) private var dismiss
    @State private var showingDatePicker = false
    @State private var selectedDate: Date = Date()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 比赛基本信息
                VStack(spacing: 8) {
                    HStack {
                        Text("比赛时间：")
                        .foregroundColor(.gray)
                        Button(action: {
                            selectedDate = match.matchDate
                            showingDatePicker = true
                        }) {
                            Text(match.matchDate.formatted(date: .numeric, time: .shortened))
                                .foregroundColor(.blue)
                                .underline()
                        }
                    }
                    .sheet(isPresented: $showingDatePicker) {
                        VStack {
                            DatePicker(
                                "选择比赛时间",
                                selection: $selectedDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.graphical)
                            .padding()
                            HStack {
                                Button("取消") {
                                    showingDatePicker = false
                                }
                                Spacer()
                                Button("确定") {
                                    match.matchDate = selectedDate
                                    try? modelContext.save()
                                    showingDatePicker = false
                                }
                            }
                            .padding()
                        }
                        .presentationDetents([.medium])
                    }
                    
                    // 比分区域
                    HStack(spacing: 20) {
                        Text(match.homeTeamName)
                            .foregroundColor(.red)
                        Text("\(match.homeScore) - \(match.awayScore)")
                            .font(.title.bold())
                        Text(match.awayTeamName)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                
                // 比赛数据
                VStack(alignment: .leading, spacing: 15) {
                    DataRow(title: "人数", value: "\(match.playerCount)")
                    if let duration = match.duration {
                        DataRow(title: "比赛时长", value: "\(duration)分钟")
                    }
                    if let referee = match.referee {
                        DataRow(title: "比赛裁判", value: referee)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                
                // 比赛事件列表
                if !match.events.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("比赛事件")
                            .font(.headline)
                            .padding(.bottom, 4)
                        ForEach(match.events.sorted(by: { $0.timestamp < $1.timestamp })) { event in
                            MatchEventRow(event: event)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
                
                // 最佳球员
                VStack(alignment: .leading, spacing: 15) {
                    if let mvp = match.mvp {
                        PlayerAwardRow(title: "MVP", player: mvp)
                    }
                    if let topScorer = match.topScorer {
                        PlayerAwardRow(title: "最佳射手", player: topScorer)
                    }
                    if let topGoalkeeper = match.topGoalkeeper {
                        PlayerAwardRow(title: "最佳门将", player: topGoalkeeper)
                    }
                    if let topPlaymaker = match.topPlaymaker {
                        PlayerAwardRow(title: "最佳组织", player: topPlaymaker)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                
                // 球员评分列表
                if !match.playerStats.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("球员评分")
                            .font(.headline)
                            .padding(.bottom, 4)
                        ForEach(match.playerStats.sorted(by: { $0.score > $1.score })) { stats in
                            HStack {
                                Text(stats.player?.name ?? "未知球员")
                                    .frame(width: 80, alignment: .leading)
                                Spacer()
                                Text(String(format: "%.2f", stats.score))
                                    .fontWeight(stats.score >= 8.0 ? .bold : .regular)
                                    .foregroundColor(stats.score >= 8.0 ? .orange : .primary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
                
                if match.status == .finished {
                    Text("比赛已结束，事件仅供查看，无法编辑。")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.bottom, 4)
                }
            }
            .padding()
        }
        .background(ThemeColor.background)
        .navigationTitle("比赛数据")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            for stats in match.playerStats {
                print("🎯 评分检查：\(stats.player?.name ?? "未知")：\(stats.score)")
            }
        }
        .onAppear {
            print("⚠️ 总比分：\(match.homeScore + match.awayScore)")
            print("📦 实际事件数：\(match.events.count)")
            for event in match.events {
                print("📝 \(event.eventType.rawValue) - \(event.timestamp) - \(event.scorer?.name ?? "无")")
            }
        }

    }
}

// 数据行组件
struct DataRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .foregroundColor(.black)
        }
    }
}

// 球员奖项行组件
struct PlayerAwardRow: View {
    let title: String
    let player: Player
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.gray)
            Spacer()
            Text(player.name)
                .foregroundColor(.black)
        }
    }
}

// 比赛事件行组件
struct MatchEventRow: View {
    let event: MatchEvent

    // 在 MatchStatsView.swift 中找到 MatchEventRow 视图，并将其 body 替换为以下代码

    var body: some View {
        HStack {
            Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 60, alignment: .leading)
            Text(event.eventType.rawValue)
                .fontWeight(.bold)
                .foregroundColor(event.isHomeTeam ? .red : .blue)
                .frame(width: 50, alignment: .leading)
            
            // MARK: - 逻辑修正
            // 根据事件类型显示正确的球员姓名
            if event.eventType == .save {
                if let goalkeeper = event.goalkeeper {
                    Text(goalkeeper.name)
                        .foregroundColor(.primary)
                }
            } else {
                if let scorer = event.scorer {
                    Text(scorer.name)
                        .foregroundColor(.primary)
                }
            }
            
            if let assistant = event.assistant, event.eventType == .goal {
                Text("助攻: \(assistant.name)")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            Spacer()
            Text(event.isHomeTeam ? "主队" : "客队")
                .font(.caption2)
                .foregroundColor(event.isHomeTeam ? .red : .blue)
        }
        .padding(.vertical, 2)
    }

    func colorForEventType(_ type: EventType) -> Color {
        switch type {
        case .goal: return .red
        //case .assist: return .orange
        case .save: return .blue
        case .foul: return .gray
        case .yellowCard: return .yellow
        case .redCard: return .red
        }
    }
} 
