import SwiftUI
import PhotosUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var isEditingName = false
    
    // 用户数据
    @State private var name: String = ""
    @State private var gender: String = "男"
    @State private var height: Int = 170
    @State private var weight: Int = 70
    @State private var preferredFoot: String = "右脚"
    @State private var boots: String = ""
    @State private var position: PlayerPosition = .forward
    @State private var selectedNumber: Int = 0
    
    // 在 SettingsView.swift 中添加状态变量
    @State private var showingFullRestoreImporter = false
    @State private var restoreAlertMessage = ""
    @State private var showRestoreAlert = false
    @State private var pendingImportURLs: [URL]? = nil
    @State private var showingRestoreConfig = false
    
    // 添加一个状态变量来存储 URL
    @State private var profileImageURL: URL?
    
    private let genders = ["男", "女"]
    private let feet = ["左脚", "右脚"]
    private let heights = Array(150...200)
    private let weights = Array(40...120)
    private let numbers = Array(0...99)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // 头像与基础信息区域
                        profileSection
                        
                        // 常用设置区域
                        commonSettingsSection
                        
                        // 其他区域
                        otherSection
                    }
                    .padding()
                }
            }
            .onAppear {
                loadPlayerData()
            }
        }
    }
    
    // MARK: - 头像与基础信息区域
    private var profileSection: some View {
        VStack(spacing: 15) {
            // 头像
            PhotosPicker(selection: $selectedItem) {
                Group {
                    if let profileImage {
                        profileImage
                            .resizable()
                            .scaledToFill()
                            .frame(width: 107, height: 107)
                            .clipShape(Circle())
                    } else if let url = profileImageURL,
                              let uiImage = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 107, height: 107)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 107, height: 107)
                            .foregroundColor(.gray)
                    }
                }
            }
            .onChange(of: selectedItem) { _, newItem in
                handleImageSelection(newItem)
            }
            
            // 昵称和ID
            VStack(spacing: 8) {
                if isEditingName {
                    TextField("昵称", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                } else {
                    Text(name)
                        .font(.title2)
                        .foregroundColor(.black)
                }
                
                Text("ID: \(authManager.currentPlayer?.id.uuidString.prefix(16) ?? "")")
                    .font(.caption)
                    .foregroundColor(Color(red: 139/255, green: 139/255, blue: 139/255))
                
                Button(isEditingName ? "保存" : "编辑") {
                    if isEditingName {
                        saveChanges()
                    }
                    isEditingName.toggle()
                }
                .foregroundColor(.black)
                .padding(.vertical, 5)
            }
        }
    }
    
    // MARK: - 常用设置区域
    private var commonSettingsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("常用设置")
                .foregroundColor(.gray)
                .font(.headline)
            
            Group {
                settingRow("性别", selection: $gender, options: genders)
                    
                settingRow("身高", value: "\(height)cm") {
                    Picker("身高", selection: $height) {
                        ForEach(heights, id: \.self) { height in
                            Text("\(height)cm").tag(height)
                        }
                    }
                }
                settingRow("体重", value: "\(weight)kg") {
                    Picker("体重", selection: $weight) {
                        ForEach(weights, id: \.self) { weight in
                            Text("\(weight)kg").tag(weight)
                        }
                    }
                }
                settingRow("惯用脚", selection: $preferredFoot, options: feet)
                settingRow("位置", value: position.rawValue) {
                    Picker("位置", selection: $position) {
                        ForEach(PlayerPosition.allCases, id: \.self) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                }
                settingRow("球鞋", text: $boots)
                settingRow("球员号码", value: "\(selectedNumber)") {
                    Picker("球员号码", selection: $selectedNumber) {
                        ForEach(numbers, id: \.self) { number in
                            Text("\(number)").tag(number)
                        }
                    }
                }
            }
            .onChange(of: gender) { oldValue, newValue in 
                saveChanges()
            }
            .onChange(of: height) { oldValue, newValue in 
                saveChanges()
            }
            .onChange(of: weight) { oldValue, newValue in 
                saveChanges()
            }
            .onChange(of: preferredFoot) { oldValue, newValue in 
                saveChanges()
            }
            .onChange(of: position) { oldValue, newValue in 
                saveChanges()
            }
            .onChange(of: boots) { oldValue, newValue in 
                saveChanges()
            }
            .onChange(of: selectedNumber) { oldValue, newValue in 
                saveChanges()
            }
        }
        .padding()
        .background(Color.black.opacity(0.05))
        .cornerRadius(10)
    }
    
    // MARK: - 其他区域
    private var otherSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("其他")
                .foregroundColor(.gray)
                .font(.headline)
            
            // 1. 新增：赛季管理入口
            NavigationLink(destination: SeasonListView()) {
                HStack {
                    Text("赛季管理")
                        .foregroundColor(.black)
                    Spacer()
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.gray)
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
            }
            
            // [新增] 恢复历史备份入口
            Button(action: { showingFullRestoreImporter = true }) {
                HStack {
                    Text("从 CSV 恢复历史备份")
                        .foregroundColor(.black)
                    Spacer()
                    Image(systemName: "arrow.counterclockwise.icloud")
                        .foregroundColor(.blue)
                }
            }
            .fileImporter(
                isPresented: $showingFullRestoreImporter,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    // [修改] 不直接导入，而是保存 URL 并弹出配置窗口
                    self.pendingImportURLs = urls
                    self.showingRestoreConfig = true
                    
                case .failure(let error):
                    restoreAlertMessage = "文件选择失败: \(error.localizedDescription)"
                    showRestoreAlert = true
                }
            }
            // [新增] 恢复配置弹窗
            .sheet(isPresented: $showingRestoreConfig) {
                if let urls = pendingImportURLs {
                    RestoreConfigSheet(fileURLs: urls) { resultMessage in
                        // 导入完成后的回调
                        restoreAlertMessage = resultMessage
                        showRestoreAlert = true
                        pendingImportURLs = nil // 清理
                    }
                }
            }
            .alert("数据恢复", isPresented: $showRestoreAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(restoreAlertMessage)
            }
            
            NavigationLink("球员列表与数据") {
                PlayerListView()
                    .navigationTitle("球员列表")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            NavigationLink("帮助") {
                Text("帮助内容")
                    .navigationTitle("帮助")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.black.opacity(0.05))
        .cornerRadius(10)
    }
    
    // MARK: - 辅助方法
    private func loadPlayerData() {
        guard let player = authManager.currentPlayer else { return }
        name = player.name
        selectedNumber = player.number ?? 0
        position = player.position
        profileImageURL = player.profilePicture  // 加载头像 URL
        
        // 如果有头像 URL，加载头像
        if let url = player.profilePicture,
           let uiImage = UIImage(contentsOfFile: url.path) {
            profileImage = Image(uiImage: uiImage)
        }
        
        // 加载其他字段...
    }
    
    private func saveChanges() {
        guard let player = authManager.currentPlayer else { return }
        player.name = name
        player.number = selectedNumber
        player.position = position
        // 保存其他字段...
        
        do {
            try modelContext.save()
        } catch {
            print("保存失败: \(error)")
        }
    }
    
    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
        Task {
            if let data = try? await newItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                // 更新显示的图片
                profileImage = Image(uiImage: uiImage)
                
                // 保存图片到本地并更新 URL
                if let url = try await saveImageLocally(uiImage) {
                    profileImageURL = url
                    authManager.currentPlayer?.profilePicture = url
                    try? modelContext.save()
                }
            }
        }
    }
    
    private func saveImageLocally(_ image: UIImage) async throws -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return nil }
        let filename = "\(UUID().uuidString).jpg"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        try data.write(to: fileURL)
        return fileURL
    }
}

// MARK: - 辅助视图
private struct SettingRow<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.black)
            Spacer()
            content
        }
    }
}

// MARK: - 设置行扩展
extension View {
    func settingRow(_ title: String, value: String, content: @escaping () -> some View) -> some View {
        SettingRow(title) {
            HStack {
                Text(value)
                    .foregroundColor(.gray)
                content()
            }
        }
    }
    
    func settingRow(_ title: String, selection: Binding<String>, options: [String]) -> some View {
        SettingRow(title) {
            Picker(title, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
        }
    }
    
    func settingRow(_ title: String, text: Binding<String>) -> some View {
        SettingRow(title) {
            TextField(title, text: text)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.gray)
        }
    }
}

struct RestoreConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let fileURLs: [URL]
    let onFinish: (String) -> Void
    
    @Query(sort: \Season.endDate, order: .reverse) private var seasons: [Season]
    
    @State private var selectedSeasonID: UUID?
    @State private var createNewSeason = true
    @State private var newSeasonName = "恢复的历史赛季"
    @State private var isImporting = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("第一步：选择文件") {
                    LabeledContent("已选文件数", value: "\(fileURLs.count)")
                    Text("包含: " + fileURLs.map { $0.lastPathComponent }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("第二步：选择目标赛季") {
                    Picker("导入方式", selection: $createNewSeason) {
                        Text("新建赛季").tag(true)
                        Text("并入现有赛季").tag(false)
                    }
                    .pickerStyle(.segmented)
                    
                    if createNewSeason {
                        TextField("新赛季名称", text: $newSeasonName)
                    } else {
                        if seasons.isEmpty {
                            Text("暂无现有赛季，请选择新建")
                                .foregroundStyle(.red)
                        } else {
                            Picker("选择赛季", selection: $selectedSeasonID) {
                                Text("请选择...").tag(nil as UUID?)
                                ForEach(seasons) { season in
                                    Text(season.name).tag(season.id as UUID?)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: startImport) {
                        if isImporting {
                            ProgressView()
                        } else {
                            Text("开始恢复")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isImporting || (!createNewSeason && selectedSeasonID == nil))
                    .listRowBackground(Color.blue)
                }
                
                Section {
                    Text("说明：\n1. 如果现有球员名字与备份中的名字完全一致，数据将自动合并。\n2. 否则将创建新球员。")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
            .navigationTitle("恢复选项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
    
    private func startImport() {
        isImporting = true
        
        // 延迟一点执行，让UI显示Loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            do {
                let targetSeason: Season
                
                if createNewSeason {
                    // 创建新赛季
                    let season = Season(
                        name: newSeasonName.isEmpty ? "恢复的数据" : newSeasonName,
                        startDate: .distantPast,
                        endDate: Date()
                    )
                    modelContext.insert(season)
                    targetSeason = season
                } else {
                    // 获取选中的赛季
                    guard let id = selectedSeasonID,
                          let season = seasons.first(where: { $0.id == id }) else {
                        isImporting = false
                        return
                    }
                    targetSeason = season
                }
                
                // 执行导入
                try CSVImporter.restoreFromFiles(
                    urls: fileURLs,
                    targetSeason: targetSeason,
                    context: modelContext
                )
                
                onFinish("成功恢复数据到赛季：\(targetSeason.name)")
                dismiss()
                
            } catch {
                onFinish("恢复失败: \(error.localizedDescription)")
                dismiss()
            }
        }
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Player.self, configurations: config)
        let context = container.mainContext
        return SettingsView()
            .environmentObject(AuthManager(modelContext: context))
    } catch {
        return Text("Failed to create preview: \(error.localizedDescription)")
    }
} 
