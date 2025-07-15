import SwiftUI
import AuthenticationServices
import SwiftData

@MainActor
class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var currentUserID: String? = nil
    @Published var currentPlayer: Player? = nil
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        // 检查是否已登录
        Task {
            await checkExistingUser()
        }
    }
    
    private func checkExistingUser() async {
        // 从 UserDefaults 获取存储的用户ID
        if let userID = UserDefaults.standard.string(forKey: "AppleUserID") {
            self.currentUserID = userID
            // 查找对应的 Player
            await findOrCreatePlayer(for: userID)
            self.isLoggedIn = true
        }
    }
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        let userID = credential.user
        self.currentUserID = userID
        
        // 保存用户ID
        UserDefaults.standard.set(userID, forKey: "AppleUserID")
        
        // 如果是首次登录，获取用户信息
        if let email = credential.email,
           let fullName = credential.fullName {
            // 创建新用户时使用实际名字
            await findOrCreatePlayer(for: userID, name: "\(fullName.givenName ?? "") \(fullName.familyName ?? "")")
        } else {
            // 非首次登录
            await findOrCreatePlayer(for: userID)
        }
        
        self.isLoggedIn = true
    }
    
    private func findOrCreatePlayer(for userID: String, name: String? = nil) async {
        let descriptor = FetchDescriptor<Player>(
            predicate: #Predicate<Player> { player in
                player.appleUserID == userID
            }
        )
        
        do {
            let existingPlayers = try modelContext.fetch(descriptor)
            if let player = existingPlayers.first {
                self.currentPlayer = player
            } else {
                // 创建新 Player
                let newPlayer = Player(
                    name: name ?? "新用户",
                    position: .forward
                )
                newPlayer.appleUserID = userID
                modelContext.insert(newPlayer)
                try modelContext.save()
                self.currentPlayer = newPlayer
            }
        } catch {
            print("查找或创建用户失败: \(error)")
        }
    }
    
    func signOut() {
        self.currentUserID = nil
        self.currentPlayer = nil
        self.isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: "AppleUserID")
    }
} 