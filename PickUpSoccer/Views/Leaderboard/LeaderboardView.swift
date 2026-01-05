import SwiftUI
import SwiftData

struct LeaderboardView: View {
    // 查询未归档的球员
    @Query(filter: #Predicate<Player> { $0.isArchived == false })
    private var players: [Player]
    
    // 查询赛季用于筛选
    @Query(sort: \Season.endDate, order: .reverse)
    private var seasons: [Season]
    
    @State private var selectedSeason: Season?
    @State private var selectedTab = 0 // 0: 进球, 1: 助攻, 2: MVP, 3: 扑救
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. 赛季选择器 (横向滚动)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        Button(action: { selectedSeason = nil }) {
                            Text("全部")
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedSeason == nil ? Color.black : Color.gray.opacity(0.1))
                                .foregroundColor(selectedSeason == nil ? .white : .primary)
                                .cornerRadius(20)
                        }
                        
                        ForEach(seasons) { season in
                            Button(action: { selectedSeason = season }) {
                                Text(season.name)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedSeason?.id == season.id ? Color.black : Color.gray.opacity(0.1))
                                    .foregroundColor(selectedSeason?.id == season.id ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding()
                }
                .background(Color.white)
                
                // 2. 统计维度选择
                Picker("统计项", selection: $selectedTab) {
                    Text("进球").tag(0)
                    Text("助攻").tag(1)
                    Text("MVP").tag(2)
                    Text("扑救").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 10)
                
                // 3. 榜单列表
                List {
                    ForEach(sortedPlayers) { player in
                        HStack {
                            // 排名
                            Text("\(rank(of: player))")
                                .font(.headline)
                                .italic()
                                .frame(width: 30)
                                .foregroundColor(.secondary)
                            
                            // 头像
                            if let url = player.profilePicture,
                               let uiImage = UIImage(contentsOfFile: url.path) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .frame(width: 40, height: 40)
                                    .foregroundColor(.gray)
                            }
                            
                            // 名字
                            Text(player.name)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            // 数值
                            Text("\(value(for: player))")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("排行榜")
            .onAppear {
                // 默认选中当前赛季
                if selectedSeason == nil {
                    selectedSeason = seasons.first(where: { $0.isCurrent })
                }
            }
        }
    }
    
    // 根据选中项排序
    private var sortedPlayers: [Player] {
        players
            .map { player -> (Player, Int) in
                (player, value(for: player))
            }
            .filter { $0.1 > 0 } // 只显示数值大于0的球员
            .sorted { $0.1 > $1.1 } // 降序
            .map { $0.0 }
    }
    
    // 获取当前Tab对应的数值 (使用 Player 扩展方法)
    private func value(for player: Player) -> Int {
        switch selectedTab {
        case 0: return player.goals(in: selectedSeason)
        case 1: return player.assists(in: selectedSeason)
        case 2: return player.mvpCountForSeason(selectedSeason) // 这里用回你之前定义的，或者用stats计算
        case 3: return player.saves(in: selectedSeason)
        default: return 0
        }
    }
    
    private func rank(of player: Player) -> Int {
        guard let index = sortedPlayers.firstIndex(where: { $0.id == player.id }) else { return 0 }
        return index + 1
    }
}
