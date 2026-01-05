import SwiftUI
import SwiftData

struct MatchesView: View {
    @Environment(\.modelContext) private var modelContext
    
    // 获取所有数据
    @Query(sort: \Match.matchDate, order: .reverse) private var allMatches: [Match]
    @Query(sort: \Season.endDate, order: .reverse) private var seasons: [Season]
    
    // [修改] 状态变量改名，明确它是用来显示"参与者选择"页面的
    @State private var showingParticipationSelect = false
    @State private var selectedSeason: Season?
    
    // [关键修复 1] 必须在这里创建并注入协调器，否则跳转 MatchRecordView 会失败
    @StateObject private var coordinator = NavigationCoordinator()
    
    // 1. 将过滤逻辑移至计算属性
    private var filteredMatches: [Match] {
        if let season = selectedSeason {
            return allMatches.filter { $0.season?.id == season.id }
        }
        return allMatches
    }
    
    var body: some View {
        NavigationStack {
            // 2. 将列表内容抽取出来
            matchList
            .navigationTitle(selectedSeason?.name ?? "所有比赛")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    seasonFilterMenu
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    // [修改] 点击按钮触发 showingParticipationSelect
                    Button(action: { showingParticipationSelect = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            // [关键修复 2] 这里必须调用 ParticipationSelectView (第一步：选人)
            // 并且注入 coordinator
            .sheet(isPresented: $showingParticipationSelect) {
                ParticipationSelectView()
                    .environment(\.selectedSeasonID, selectedSeason?.id) // 传递赛季信息
                    .environmentObject(coordinator) // 传递协调器
            }
            .onAppear {
                if selectedSeason == nil {
                    selectedSeason = seasons.first(where: { $0.isCurrent })
                }
            }
        }
        .environmentObject(coordinator) // [关键修复 3] 为整个导航栈注入协调器，解决点击比赛无反应/崩溃问题
    }
    
    // MARK: - 抽取的子视图
    
    @ViewBuilder
    private var matchList: some View {
        if filteredMatches.isEmpty {
            ContentUnavailableView(
                selectedSeason == nil ? "暂无比赛记录" : "\(selectedSeason?.name ?? "") 暂无比赛",
                systemImage: "sportscourt",
                description: Text("点击右上角 + 开始一场新比赛")
            )
        } else {
            List {
                ForEach(filteredMatches) { match in
                    // 如果比赛已结束，通常跳转到统计页；进行中则跳转到记录页
                    // 这里统一跳转到 MatchRecordView
                    NavigationLink(destination: MatchRecordView(match: match)) {
                        MatchRowView(match: match)
                    }
                }
                .onDelete(perform: deleteMatches)
            }
            .listStyle(.insetGrouped)
        }
    }
    
    private var seasonFilterMenu: some View {
        Menu {
            Button("全部赛季", action: { selectedSeason = nil })
            Divider()
            ForEach(seasons) { season in
                Button(action: { selectedSeason = season }) {
                    HStack {
                        Text(season.name)
                        if selectedSeason?.id == season.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedSeason?.name ?? "全部")
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .foregroundColor(.primary)
        }
    }
    
    private func deleteMatches(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(filteredMatches[index])
            }
        }
    }
}

// 行视图定义
struct MatchRowView: View {
    let match: Match
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(match.matchDate.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let duration = match.duration {
                    Text("\(duration)分钟")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            
            HStack {
                Text(match.homeTeamName)
                    .font(.headline)
                Spacer()
                Text("\(match.homeScore) : \(match.awayScore)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(match.homeScore > match.awayScore ? .blue : (match.homeScore < match.awayScore ? .red : .primary))
                Spacer()
                Text(match.awayTeamName)
                    .font(.headline)
            }
            
            // 显示状态标签
            HStack {
                Text(match.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(match.status == .inProgress ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    .foregroundColor(match.status == .inProgress ? .green : .secondary)
                    .cornerRadius(4)
                
                Spacer()
                
                if let mvp = match.mvp {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                        Text("MVP: \(mvp.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
