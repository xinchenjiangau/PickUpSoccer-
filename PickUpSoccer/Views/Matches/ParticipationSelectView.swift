import SwiftUI
import SwiftData

struct ParticipationSelectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var players: [Player]
    @State private var selectedPlayers: Set<Player> = []
    let selectedSeason: Season
    @State private var navigateToTeamSelect = false // 状态变量
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var coordinator: NavigationCoordinator
    
    var body: some View {
        NavigationStack {
            // ✅ 2. 修改List，让它直接遍历赛季内的球员
            List(selection: $selectedPlayers) {
                // 直接使用selectedSeason.players作为列表的数据源
                ForEach(selectedSeason.players) { player in
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading) {
                            Text(player.name).font(.headline)
                            Text(player.position.rawValue).font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                    .tag(player) // 确保tag是player对象本身
                }
            }
            .environment(\.editMode, .constant(.active)) // 保持多选模式
            .navigationTitle("选择参赛球员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(
                        destination: TeamSelectView(selectedPlayers: Array(selectedPlayers), selectedSeason: self.selectedSeason)
                    ) {
                        Text("完成")
                    }
                    .disabled(selectedPlayers.isEmpty)
                }
            }
        }
    }
    
    private func selectAllPlayers() {
        if selectedPlayers.count == players.count {
            selectedPlayers.removeAll() // 取消全选
        } else {
            selectedPlayers = Set(players) // 全选
        }
    }
}

struct MultipleSelectionRow: View {
    var title: String
    var isSelected: Bool
    var action: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}


