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
            

            NavigationLink("帮助") {
                Text("帮助内容")
                    .navigationTitle("帮助")
            }
            .frame(maxWidth: .infinity, alignment: .leading) // 确保链接靠左
            
            NavigationLink("球员列表与数据") {
                PlayerListView()
                    .navigationTitle("球员列表")
            }
            .frame(maxWidth: .infinity, alignment: .leading) // 确保链接靠左
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
