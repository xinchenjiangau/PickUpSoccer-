import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// 1. 新增：定义一个遵循 Identifiable 的结构体来驱动弹窗
// 这确保了弹窗弹出时，数据（urls）一定已经准备好了
struct ShareData: Identifiable {
    let id = UUID()
    let urls: [URL]
}

struct PlayerListView: View {
    @Environment(\.modelContext) private var modelContext
    // MARK: - 关键修改 1：Query 过滤器
    // 只查询未归档(isArchived == false)的球员
    // 注意：SwiftData 的 Predicate 有时对布尔值比较敏感，显式写全比较稳妥
    @Query(filter: #Predicate<Player> { $0.isArchived == false }, sort: \Player.number)
    private var players: [Player]
    
    @Query private var matches: [Match]
    
    // MARK: - State Properties
    @State private var showingAddPlayer = false
    @State private var showingExportSheet = false // 用于单个球员列表导出
    @State private var showingImportSheet = false
    @State private var csvString: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    // 2. 修改：使用 shareData 替换原来的 Bool 和 Array，防止状态不同步
    @State private var shareData: ShareData?
    
    var body: some View {
        List {
            ForEach(players) { player in
                HStack {
                    Text("\(player.number ?? 0)")
                        .frame(width: 30)
                        .foregroundColor(.secondary)
                    Text(player.name)
                    Spacer()
                    Text(player.position.rawValue)
                        .foregroundColor(.secondary)
                }
            }
            .onDelete(perform: deletePlayers)
        }
        .navigationTitle("球员名单")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { showingAddPlayer = true }) {
                        Label("添加球员", systemImage: "person.badge.plus")
                    }
                    
                    // 导出单个球员名单
                    Button(action: exportPlayerData) {
                        Label("导出球员列表", systemImage: "doc.text")
                    }
                    
                    Button(action: { showingImportSheet = true }) {
                        Label("导入数据", systemImage: "square.and.arrow.down")
                    }
                    
                    // 导出全部数据
                    Button(action: exportAllData) {
                        Label("导出全部数据", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPlayer) {
            AddPlayerView(isPresented: $showingAddPlayer)
        }
        // 单个文件导出 (球员列表)
        .fileExporter(
            isPresented: $showingExportSheet,
            document: CSVFile(initialText: csvString),
            contentType: .commaSeparatedText,
            defaultFilename: "球员列表_\(formattedDate).csv"
        ) { result in
            switch result {
            case .success(let url):
                print("成功导出到: \(url)")
            case .failure(let error):
                print("导出失败: \(error.localizedDescription)")
            }
        }
        // 导入文件
        .fileImporter(
            isPresented: $showingImportSheet,
            allowedContentTypes: [.commaSeparatedText]
        ) { result in
            switch result {
            case .success(let url):
                importCSV(from: url)
            case .failure(let error):
                errorMessage = "导入失败: \(error.localizedDescription)"
                showError = true
            }
        }
        .alert("错误", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        // 3. 修改：使用 item: $shareData 形式
        // 只有当 shareData 被赋值时，这里才会运行，并且 data 保证是有值的
        .sheet(item: $shareData) { data in
            ShareSheet(activityItems: data.urls)
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: Date())
    }
    
    private func deletePlayers(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                // 原代码：modelContext.delete(players[index])
                // 新代码：标记为归档
                let player = players[index]
                player.isArchived = true
            }
            // 显式保存更改
            try? modelContext.save()
        }
    }
    
    // 导出单个球员列表
    private func exportPlayerData() {
        csvString = CSVExporter.exportPlayers(players)
        showingExportSheet = true
    }
    
    // 导入
    private func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "无法访问选择的文件"
            showError = true
            return
        }
        
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        
        do {
            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw CSVImporter.ImportError.invalidData
            }
            
            try CSVImporter.importPlayers(from: content, modelContext: modelContext)
        } catch let error as CSVImporter.ImportError {
            errorMessage = error.localizedDescription
            showError = true
        } catch {
            errorMessage = "导入失败: \(error.localizedDescription)"
            showError = true
        }
    }
    
    // 4. 修改：导出全部数据逻辑
    private func exportAllData() {
        let urls = CSVExporter.exportAllDataToURLs(players: players, matches: matches)
        
        if urls.isEmpty {
            errorMessage = "没有可导出的数据"
            showError = true
            return
        }
        
        // 直接赋值 shareData，这将自动触发 sheet
        self.shareData = ShareData(urls: urls)
    }
}

// MARK: - Helper Structs

struct CSVFile: FileDocument {
    static var readableContentTypes = [UTType.commaSeparatedText]
    
    var text: String
    
    init(initialText: String = "") {
        self.text = initialText
    }
    
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let bomString = "\u{FEFF}"
        let fullText = bomString + text
        guard let data = fullText.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return .init(regularFileWithContents: data)
    }
}

// 封装系统分享控制器
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    PlayerListView()
        .modelContainer(for: Player.self, inMemory: true)
}
