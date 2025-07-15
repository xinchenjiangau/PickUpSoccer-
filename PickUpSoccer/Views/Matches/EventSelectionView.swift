import SwiftUI
import SwiftData

struct EventSelectionView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    @Bindable var match: Match
    let isHomeTeam: Bool
    
    @State private var selectedTab = 0 // 0: 进球, 1: 扑救
    @State private var showingAssistSelection = false
    @State private var currentScorer: Player? // 临时存储进球球员
    
    var selectedTeamPlayers: [Player] {
        match.playerStats.filter { $0.isHomeTeam == isHomeTeam }.compactMap { $0.player }
    }
    
    // 添加计算属性用于调试
    var availableAssistPlayers: [Player] {
        let filtered = selectedTeamPlayers.filter { player in
            if let scorer = currentScorer {
                print("比较ID: \(player.id) vs \(scorer.id)") // 调试输出
                return player.id != scorer.id
            }
            return true
        }
        print("可选助攻球员数量: \(filtered.count)") // 调试输出
        return filtered
    }
    
    var body: some View {
        VStack {
            // 标题栏
            HStack(spacing: 20) {
                // 进球选择标签
                Text("选择进球球员")
                    .font(.headline)
                    .foregroundColor(selectedTab == 0 ? .black : .gray)
                    .fontWeight(selectedTab == 0 ? .bold : .regular)
                
                // 扑救选择标签
                Text("选择扑救球员")
                    .font(.headline)
                    .foregroundColor(selectedTab == 1 ? .black : .gray)
                    .fontWeight(selectedTab == 1 ? .bold : .regular)
            }
            .padding(.top)
            
            // 滑动提示
            HStack {
                Image(systemName: "arrow.left.and.right.circle")
                    .foregroundColor(.blue)
                Text("左右滑动切换")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.bottom)
            
            TabView(selection: $selectedTab) {
                // 进球选择页面
                VStack {
                    List(selectedTeamPlayers) { player in
                        Button(action: {
                            handleGoalScorer(player)
                        }) {
                            HStack {
                                Text(player.name)
                                Spacer()
                            }
                        }
                    }
                }
                .tag(0)
                
                // 扑救选择页面
                VStack {
                    List(selectedTeamPlayers) { player in
                        Button(action: {
                            recordSave(player)
                        }) {
                            HStack {
                                Text(player.name)
                                Spacer()
                            }
                        }
                    }
                }
                .tag(1)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))  // 隐藏默认指示器
        }
        .navigationTitle("\(isHomeTeam ? "红队" : "蓝队")事件")
        .navigationBarItems(trailing: Button("完成") {
            presentationMode.wrappedValue.dismiss()
        })
        .sheet(isPresented: $showingAssistSelection) {
            AssistSelectionView(
                players: availableAssistPlayers,
                onAssistSelected: { assistPlayer in
                    if let scorer = currentScorer {
                        print("选择助攻球员：\(assistPlayer.name)，进球球员：\(scorer.name)")
                        recordGoal(scorer, assistant: assistPlayer)
                    }
                },
                onSkip: {
                    if let scorer = currentScorer {
                        recordGoal(scorer, assistant: nil)
                    }
                }
            )
        }
        .onChange(of: currentScorer) { oldValue, newValue in
            print("currentScorer 更新为: \(newValue?.name ?? "nil")")
        }
    }
    
    private func handleGoalScorer(_ player: Player) {
        print("开始处理进球球员：\(player.name)") // 调试输出
        print("进球球员ID：\(player.id)") // 调试输出
        currentScorer = player
        showingAssistSelection = true
    }
    
    private func recordGoal(_ scorer: Player, assistant: Player?) {
        // 调试：打印进球球员信息
        print("记录进球：进球球员 - \(scorer.name)")    
        let event = MatchEvent(
            eventType: .goal,
            timestamp: Date(),
            isHomeTeam: isHomeTeam,
            match: match,
            scorer: scorer,
            assistant: assistant
        )
        
        // 更新比分
        if isHomeTeam {
            match.homeScore += 1
        } else {
            match.awayScore += 1
        }
        
        // 更新球员统计
        if let stats = match.playerStats.first(where: { $0.player?.id == scorer.id }) {
            stats.goals += 1
        }
        if let assistant = assistant,
           let assistStats = match.playerStats.first(where: { $0.player?.id == assistant.id }) {
            assistStats.assists += 1
        }
        
        match.events.append(event)

        // 调试：打印事件详情，确认 scorer 是否存储正确
        print("事件创建完成，进球球员: \(event.scorer?.name ?? "未知")")

        do {
            try modelContext.save()
            // [新增] 在事件保存成功后，调用同步函数
            WatchConnectivityManager.shared.sendEventToWatch(event, matchId: match.id)
        } catch {
            print("保存数据失败: \(error.localizedDescription)")
        }

        presentationMode.wrappedValue.dismiss()
    }
    
    private func recordSave(_ player: Player) {
        let event = MatchEvent(
            eventType: .save,
            timestamp: Date(),
            isHomeTeam: isHomeTeam,
            match: match,
            scorer: nil, // [修改] 扑救事件不应该使用 scorer
            assistant: nil,
            goalkeeper: player // [修改] 使用 goalkeeper 字段记录扑救者
        )
        
        // 更新球员统计
        if let stats = match.playerStats.first(where: { $0.player?.id == player.id }) {
            stats.saves += 1
        }
        
        match.events.append(event)
        do {
            try modelContext.save()
            // [新增] 在事件保存成功后，调用同步函数
            WatchConnectivityManager.shared.sendEventToWatch(event, matchId: match.id)
        } catch {
            print("保存数据失败: \(error.localizedDescription)")
        }

        presentationMode.wrappedValue.dismiss()
    }
}

// 修改 AssistSelectionView 的标题部分
struct AssistSelectionView: View {
    let players: [Player]
    let onAssistSelected: (Player) -> Void
    let onSkip: () -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                // 标题
                Text("选择助攻球员")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .padding(.top)
                
                List {
                    ForEach(players) { player in
                        Button(action: {
                            onAssistSelected(player)
                        }) {
                            Text(player.name)
                        }
                    }
                    
                    Button(action: onSkip) {
                        Text("无助攻")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationBarItems(trailing: Button("取消") {
                onSkip()
            })
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Match.self, configurations: config)
    
    let newMatch = Match(
        id: UUID(),
        status: .notStarted,
        homeTeamName: "红队",
        awayTeamName: "蓝队"
    )
    return EventSelectionView(match: newMatch, isHomeTeam: true)
        .modelContainer(container)
} 
