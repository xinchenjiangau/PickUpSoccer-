import SwiftUI
import SwiftData

struct AddPlayerView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var isPresented: Bool
    
    @State private var name: String = ""
    @State private var number: String = ""
    @State private var position: PlayerPosition = .forward
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("姓名", text: $name)
                    TextField("号码", text: $number)
                        .keyboardType(.numberPad)
                    Picker("位置", selection: $position) {
                        Text("前锋").tag(PlayerPosition.forward)
                        Text("中场").tag(PlayerPosition.midfielder)
                        Text("后卫").tag(PlayerPosition.defender)
                        Text("守门员").tag(PlayerPosition.goalkeeper)
                    }
                }
            }
            .navigationTitle("添加球员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        addPlayer()
                        isPresented = false
                    }
                    .disabled(name.isEmpty || number.isEmpty)
                }
            }
        }
    }
    
    private func addPlayer() {
        let player = Player(
            name: name,
            number: Int(number) ?? 0,
            position: position
        )
        modelContext.insert(player)
    }
}

#Preview {
    AddPlayerView(isPresented: .constant(true))
        .modelContainer(for: Player.self, inMemory: true)
} 