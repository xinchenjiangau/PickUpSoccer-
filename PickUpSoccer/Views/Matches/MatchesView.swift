import SwiftUI
import SwiftData

struct MatchesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Match.matchDate, order: .reverse) private var matches: [Match]
    @StateObject private var coordinator = NavigationCoordinator()
    @State private var showingParticipationSelect = false // 状态变量
    
    // 按状态分组的比赛
    var matchesByStatus: [(status: MatchStatus, matches: [Match])] {
        let grouped = Dictionary(grouping: matches) { $0.status }
        return MatchStatus.allCases
            .map { status in
                (status: status, matches: grouped[status] ?? [])
            }
            .filter { !$0.matches.isEmpty } // 只显示有比赛的状态
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(matchesByStatus, id: \.status) { section in
                    Section(header: Text(section.status.rawValue)) {
                        ForEach(section.matches) { match in
                            if match.status == .finished {
                                // 已结束的比赛导航到统计视图
                                NavigationLink {
                                    MatchStatsView(match: match)
                                } label: {
                                    MatchRowView(match: match)
                                }
                            } else {
                                // 进行中的比赛导航到记录视图
                                NavigationLink {
                                    MatchRecordView(match: match)
                                } label: {
                                    MatchRowView(match: match)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            // 获取当前分组中的比赛
                            let matchesToDelete = indexSet.map { section.matches[$0] }
                            for match in matchesToDelete {
                                modelContext.delete(match)
                            }
                            try? modelContext.save()
                        }
                    }
                }
            }
            .navigationTitle("比赛")
            .navigationBarTitleDisplayMode(.large)  // 明确指定标题显示模式
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingParticipationSelect = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingParticipationSelect) {
                ParticipationSelectView()
                    .environmentObject(coordinator)
            }
        }
        .onChange(of: coordinator.shouldDismissParticipationSheet) { _, newValue in
            if newValue {
                showingParticipationSelect = false
                coordinator.shouldDismissParticipationSheet = false // 重置
            }
        }
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

#Preview {
    NavigationStack {
        MatchesView()
    }
} 