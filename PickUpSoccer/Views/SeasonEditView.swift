import SwiftUI
import SwiftData

struct SeasonEditView: View {
    // ✅ 1. 新增：从环境中获取modelContext，这样视图才能执行数据库操作
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Bindable var season: Season

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("赛季信息")) {
                    TextField("赛季名称", text: $season.name)
                    DatePicker("开始日期", selection: $season.startDate, displayedComponents: .date)
                    DatePicker("结束日期", selection: $season.endDate, in: season.startDate..., displayedComponents: .date) // ✅ 正确 .date) // 确保结束日期不能早于开始日期
                }

                Section(header: Text("备注")) {
                    TextEditor(text: Binding(
                        get: { season.notes ?? "" },
                        set: { season.notes = $0 }
                    ))
                    .frame(height: 150)
                }
                
                Section(header: Text("球员管理")) {
                    NavigationLink("赛季参与球员") {
                        SeasonPlayerManagementView(season: season)
                            .navigationTitle("管理球员")
                    }
                }
            }
            .navigationTitle(season.name.isEmpty ? "创建新赛季" : "编辑赛季")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        // ✅ 2. 现在因为获取了modelContext，这里的删除操作将能正常工作
                        // 如果是新创建的赛季（名字为空），取消时应该将其从数据库中删除
                        if season.name.isEmpty {
                            modelContext.delete(season)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        // 确保在完成前至少保存一次，以防自动保存有延迟
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(season.name.isEmpty)
                }
            }
        }
    }
}
