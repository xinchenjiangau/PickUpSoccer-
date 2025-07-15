import SwiftUI
import SwiftData

struct ParticipationSelectView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [Player]
    @State private var selectedPlayers: Set<Player> = []
    @State private var navigateToTeamSelect = false // 状态变量
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var coordinator: NavigationCoordinator
    
    var body: some View {
        NavigationStack {
            List(players) { player in
                MultipleSelectionRow(title: player.name, isSelected: selectedPlayers.contains(player)) {
                    if selectedPlayers.contains(player) {
                        selectedPlayers.remove(player)
                    } else {
                        selectedPlayers.insert(player)
                    }
                }
            }
            .navigationTitle("选择参赛球员")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: selectAllPlayers) {
                        Text(selectedPlayers.count == players.count ? "取消全选" : "全选")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(
                        destination: TeamSelectView(selectedPlayers: Array(selectedPlayers)).environmentObject(coordinator)
                    ) {
                        Text("完成")
                    }
                    .disabled(selectedPlayers.isEmpty) // 可选
                }
            }
        }
        .onChange(of: selectedPlayers) { oldValue, newValue in
            // 处理选择状态变化
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

#Preview {
    ParticipationSelectView()
} 