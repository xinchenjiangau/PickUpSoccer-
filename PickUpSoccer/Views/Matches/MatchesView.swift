import SwiftUI
import SwiftData

struct MatchesView: View {
    // MARK: - 属性
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager

    // 查询所有赛季，按开始日期排序
    @Query(sort: \Season.startDate, order: .reverse) private var seasons: [Season]
    
    // 查询不属于任何赛季的比赛
    @Query(filter: #Predicate<Match> { $0.season == nil }, sort: \Match.matchDate, order: .reverse) private var unsortedMatches: [Match]

    @StateObject private var coordinator = NavigationCoordinator()
    @State private var showingParticipationSelect = false
    @State private var seasonToEdit: Season? = nil
    // ✅ 1. 确保您有一个@State变量来暂存要操作的赛季
    @State private var seasonForNewMatch: Season? = nil
    
    // MARK: - 视图主体
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    // 遍历每个赛季，创建一个可折叠的Section
                    ForEach(seasons) { season in
                        DisclosureGroup(
                            content: {
                                // 显示该赛季下的所有比赛
                                let sortedMatches = season.matches.sorted(by: { $0.matchDate > $1.matchDate })
                                
                                ForEach(sortedMatches) { match in
                                    // 链接到 MatchStatsView 以显示比赛详情
                                    NavigationLink(destination: MatchStatsView(match: match)) {
                                        MatchRowView(match: match)
                                    }
                                }
                                .onDelete { indexSet in
                                    deleteMatch(at: indexSet, from: season)
                                }
                            },
                            label: {
                                // 这是可折叠区域的标题
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(season.name).font(.headline)
                                        Text("\(season.startDate.formatted(.dateTime.month().day())) - \(season.endDate.formatted(.dateTime.month().day()))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    // ✅ 1. 新增：为每个赛季标题添加上下文菜单
                                    .contextMenu {
                                        // ✅ 2. 新增“编辑”按钮
                                        Button(action: {
                                            edit(season: season)
                                        }) {
                                            Label("编辑赛季信息", systemImage: "pencil")
                                        }

                                        // ✅ 3. 新增“删除”按钮（可选，但非常实用）
                                        // 只有管理员才能看到并使用删除按钮
                                        if season.administratorIDs.contains(authManager.currentUserID ?? "") {
                                            Button(role: .destructive, action: {
                                                delete(season: season)
                                            }) {
                                                Label("删除赛季", systemImage: "trash")
                                            }
                                        }
                                    }
                                    Spacer() // 将按钮推到最右边
                                    // ✅ 新增：赛季专属的“添加比赛”按钮
                                        Button(action: {
                                            // 我们将修改 showingParticipationSelect 的触发方式
                                            // 让它能“携带”当前这个season对象
                                            self.seasonForNewMatch = season
                                            self.showingParticipationSelect = true
                                        }) {
                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(.accentColor)
                                        }
                                        .buttonStyle(.plain) // 移除按钮的默认背景，让它看起来更干净
                                        // ✅ 3.修改弹出ParticipationSelectView的.sheet，将season传递进去
                                        
                                }
                                
                            }
                        )
                    }
                    
                    // 为不属于任何赛季的比赛创建一个独立的Section
                    if !unsortedMatches.isEmpty {
                        Section("未分类比赛") {
                            ForEach(unsortedMatches) { match in
                                // 链接到 MatchStatsView 以显示比赛详情
                                NavigationLink(destination: MatchStatsView(match: match)) {
                                    MatchRowView(match: match)
                                }
                            }
                            .onDelete(perform: deleteUnsortedMatch)
                        }
                    }
                }
            }
            .navigationTitle("比赛")
            .sheet(isPresented: $showingParticipationSelect) {
                if let season = seasonForNewMatch {
                    ParticipationSelectView(selectedSeason: season)
                        .environmentObject(coordinator)
                }
            }
            .sheet(item: $seasonToEdit) { season in
                SeasonEditView(season: season)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                
                // 创建新赛季的按钮
                Button(action: createNewSeason) {
                    Image(systemName: "folder.badge.plus")
                }
            }
        }
        .onChange(of: coordinator.shouldDismissParticipationSheet) { _, newValue in
            if newValue {
                showingParticipationSelect = false
                coordinator.shouldDismissParticipationSheet = false
            }
        }
    }
    
    // MARK: - 私有方法
    private func createNewSeason() {
        guard let adminID = authManager.currentUserID else { return }
        
        let newSeason = Season(name: "新赛季", startDate: Date(), endDate: Date())
        newSeason.administratorIDs = [adminID]
        modelContext.insert(newSeason)
        
        seasonToEdit = newSeason
    }
    
    private func deleteMatch(at offsets: IndexSet, from season: Season) {
        let sortedMatches = season.matches.sorted(by: { $0.matchDate > $1.matchDate })
        for offset in offsets {
            let matchToDelete = sortedMatches[offset]
            modelContext.delete(matchToDelete)
        }
    }
    
    private func deleteUnsortedMatch(at offsets: IndexSet) {
        for offset in offsets {
            let matchToDelete = unsortedMatches[offset]
            modelContext.delete(matchToDelete)
        }
    }

    // ✅ 4. 新增：处理编辑操作的方法
    private func edit(season: Season) {
        // 这个逻辑和创建新赛季时非常相似：
        // 将要编辑的season对象赋值给@State变量，以触发弹窗
        self.seasonToEdit = season
    }

    // ✅ 5. 新增：处理删除操作的方法
    private func delete(season: Season) {
        modelContext.delete(season)
        // SwiftData的级联删除规则会自动删除该赛季下的所有比赛
    }
}
    
    



// 比赛行视图
struct MatchRowView: View {
    let match: Match
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 比赛日期
            Text(match.matchDate.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.gray)
            
            // 比分
            HStack {
                Text(match.homeTeamName)
                    .foregroundColor(.red)
                Text("\(match.homeScore) - \(match.awayScore)")
                    .font(.headline)
                Text(match.awayTeamName)
                    .foregroundColor(.blue)
            }
            
            // 比赛状态
            Text(match.status.rawValue)
                .font(.caption)
                .foregroundColor(match.status == .finished ? .gray : .green)
        }
        .padding(.vertical, 4)
    }
}

//#Preview {
//    NavigationStack {
//        MatchesView()
//    }
//} 
