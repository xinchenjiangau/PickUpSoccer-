//
//  EventRecordingView.swift
//  PickUpSoccer
//
//  Created by xc j on 6/24/25.
//
import SwiftUI
import SwiftData

struct EventRecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WatchMatchSession
    
    // 状态变量，用于触发二级页面的导航
    @State private var isRecordingGoal = false
    @State private var isRecordingSave = false
    @State private var isHomeTeamAction = true

    // 定时器，用于更新比赛时间
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var elapsedTime: TimeInterval = 0

    // 动态计算比分的逻辑 (保留在此处)
    private var homeScore: Int {
        let allEvents = (try? modelContext.fetch(FetchDescriptor<WatchMatchEvent>())) ?? []
        return allEvents.filter {
            $0.matchSession?.persistentModelID == session.persistentModelID &&
            $0.eventType == "goal" &&
            ($0.scorer?.isHomeTeam ?? false)
        }.count
    }
    
    private var awayScore: Int {
        let allEvents = (try? modelContext.fetch(FetchDescriptor<WatchMatchEvent>())) ?? []
        return allEvents.filter {
            $0.matchSession?.persistentModelID == session.persistentModelID &&
            $0.eventType == "goal" &&
            !($0.scorer?.isHomeTeam ?? true)
        }.count
    }
    
    private var homeTeamPlayers: [WatchPlayer] {
        session.players.filter { $0.isHomeTeam == true }
    }
    
    private var awayTeamPlayers: [WatchPlayer] {
        session.players.filter { $0.isHomeTeam == false }
    }

    // MARK: - 核心修改：用新的UI布局替换旧的 body
    var body: some View {
        ZStack {
            // 中间的比分显示
            HStack(alignment: .top,spacing: 10) {
                Text("\(homeScore)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
                Text(":")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
                Text("\(awayScore)")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.white)
            }
            .zIndex(1)

            // 2x2 的按钮网格
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    TeamActionButton(symbol: "G", teamColor: .red.opacity(0.8)) {
                        isHomeTeamAction = true
                        isRecordingGoal = true
                    }
                    TeamActionButton(symbol: "G", teamColor: .green.opacity(0.8)) {
                        isHomeTeamAction = false
                        isRecordingGoal = true
                    }
                }
                HStack(spacing: 4) {
                    TeamActionButton(symbol: "S", teamColor: .red.opacity(0.4)) {
                        isHomeTeamAction = true
                        isRecordingSave = true
                    }
                    TeamActionButton(symbol: "S", teamColor: .green.opacity(0.4)) {
                        isHomeTeamAction = false
                        isRecordingSave = true
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            
            // 顶部的比赛计时器
            VStack {
                Text(formatTime(elapsedTime))
                    .font(.headline).fontWeight(.semibold).foregroundColor(.white)
                    .padding(.vertical, 4).padding(.horizontal, 8)
                    .background(Color.black.opacity(0.5)).cornerRadius(8)
                Spacer()
            }
            .padding(.top, 55)
        }
        .onAppear(perform: setupTimer)
        .onReceive(timer) { _ in
            elapsedTime = Date().timeIntervalSince(session.startTime)
        }
        .sheet(isPresented: $isRecordingGoal) {
            GoalRecordingDetailView(
                session: session,
                players: isHomeTeamAction ? homeTeamPlayers : awayTeamPlayers,
                onSave: handleNewEvent
            )
        }
        .sheet(isPresented: $isRecordingSave) {
            SaveRecordingDetailView(
                session: session,
                players: isHomeTeamAction ? homeTeamPlayers : awayTeamPlayers,
                onSave: handleNewEvent
            )
        }
    }
    
    // MARK: - 以下所有函数都保留在原位，保证功能不变
    private func setupTimer() {
        elapsedTime = Date().timeIntervalSince(session.startTime)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func handleNewEvent(_ event: WatchMatchEvent) {
        event.matchSession = self.session
        modelContext.insert(event)
        try? modelContext.save()
        WatchConnectivityManager.shared.sendNewEventToPhone(event)
        print("✅ 事件已保存并发送: \(event.eventType)")
    }
}

// 按钮的辅助视图 (可以放在文件底部)
struct TeamActionButton: View {
    let symbol: String
    let teamColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Rectangle().fill(teamColor).cornerRadius(12)
                Text(symbol)
                    .font(.system(size: 90, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}


// --- 将以下代码添加到文件末尾 ---

#Preview {
    // 1. 创建一个临时的、仅在内存中使用的 SwiftData 容器
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: WatchMatchSession.self, WatchPlayer.self, WatchMatchEvent.self, configurations: config)

    // 2. 创建一个用于预览的虚拟比赛会话
    let sampleSession = WatchMatchSession(
        matchId: UUID(),
        homeTeamName: "主队",
        awayTeamName: "客队"
    )
    
    // 3. (可选) 创建一些虚拟球员并关联到会话
    let player1 = WatchPlayer(playerId: UUID(), name: "球员A", isHomeTeam: true)
    player1.matchSession = sampleSession
    let player2 = WatchPlayer(playerId: UUID(), name: "球员B", isHomeTeam: false)
    player2.matchSession = sampleSession
    
    sampleSession.players.append(player1)
    sampleSession.players.append(player2)


    // 4. 将虚拟会话注入到 EventRecordingView 中进行预览
    return EventRecordingView(session: sampleSession)
        .modelContainer(container) // 注入容器以供预览使用
}
