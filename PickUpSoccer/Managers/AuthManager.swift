import SwiftUI
import AuthenticationServices
import SwiftData

@MainActor
class AuthManager: ObservableObject {
    enum MigrationState: Equatable {
        case idle
        case needsAdminConfirmation(Season) // 当需要用户确认时，持有打包好的Season对象
        case completed

        // Equatable的实现，与我们之前为DataClaimState做的一样
        static func == (lhs: MigrationState, rhs: MigrationState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.completed, .completed):
                return true
            case (.needsAdminConfirmation(let lhsSeason), .needsAdminConfirmation(let rhsSeason)):
                return lhsSeason.id == rhsSeason.id
            default:
                return false
            }
        }
    }

    // 在AuthManager中添加一个@Published属性来驱动UI
    @Published var migrationState: MigrationState = .idle
    @Published var isLoggedIn: Bool = false
    @Published var currentUserID: String? = nil
    @Published var currentPlayer: Player? = nil
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            await checkExistingUser()
        }
    }
    
    private func checkExistingUser() async {
        if let userID = UserDefaults.standard.string(forKey: "AppleUserID") {
            self.currentUserID = userID
            await findOrCreatePlayer(for: userID)
        }
    }
    
    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        let userID = credential.user
        self.currentUserID = userID
        UserDefaults.standard.set(userID, forKey: "AppleUserID")
        let name = "\(credential.fullName?.givenName ?? "") \(credential.fullName?.familyName ?? "")".trimmingCharacters(in: .whitespacesAndNewlines)
        await findOrCreatePlayer(for: userID, name: name)
    }
        


    // ✅ 1. 重构：findOrCreatePlayer现在只负责登录，不再检查孤儿数据
    private func findOrCreatePlayer(for userID: String, name: String? = nil) async {
        print("🕵️ Auth: Simplified findOrCreatePlayer started.")
        let descriptor = FetchDescriptor<Player>(predicate: #Predicate { $0.appleUserID == userID })
        
        if let existingPlayer = try? modelContext.fetch(descriptor).first {
            self.currentPlayer = existingPlayer
        } else {
            let newPlayer = Player(name: name?.isEmpty ?? true ? "新用户" : name!, position: .forward)
            newPlayer.appleUserID = userID
            modelContext.insert(newPlayer)
            self.currentPlayer = newPlayer
            try? modelContext.save()
        }
        
        // 无论找到还是创建，都立刻完成登录
        self.isLoggedIn = true
        print("✅ Auth: Login successful. Player is set.")
    }
    
    // ✅ 2. 新增：独立的、专门用于检查数据迁移的方法
    func checkForMigration() {
        print("🕵️ Auth: Checking for data migration possibilities...")
        
        // 如果用户已经处理过迁移，则不再检查
        guard migrationState == .idle else {
            print("ℹ️ Auth: Migration check skipped, state is already: \(migrationState).")
            return
        }
        
        // 查找“无主赛季”的逻辑不变
        let allSeasonsDescriptor = FetchDescriptor<Season>()
        if let allSeasons = try? modelContext.fetch(allSeasonsDescriptor),
           let orphanSeason = allSeasons.first(where: { $0.administratorIDs.isEmpty }) {
            
            print("‼️ Auth: Found an orphan season! Triggering admin confirmation.")
            self.migrationState = .needsAdminConfirmation(orphanSeason)
        } else {
            print("ℹ️ Auth: No orphan seasons found. Migration check complete.")
            self.migrationState = .completed
        }
    }

    // 我们需要一个私有的createNewPlayer方法来处理通用逻辑
    private func createNewPlayer(for userID: String, name: String?) {
        print("➕ Auth: createNewPlayer - Creating new player record.")
        let newPlayer = Player(name: name?.isEmpty ?? true ? "新用户" : name!, position: .forward)
        newPlayer.appleUserID = userID
        modelContext.insert(newPlayer)

        self.currentPlayer = newPlayer
        self.isLoggedIn = true
        self.migrationState = .completed
        print("➡️ Auth: New player created. Login successful. Migration state set to .completed.")
        try? modelContext.save()
    }
    
    /// 仅用于调试：重置当前登录的用户状态，但保留其他业务数据
    // 在 AuthManager.swift 中，替换这个方法

    /// 仅用于调试：重置当前登录的用户状态，并将所有赛季恢复为“待认领”状态
    func resetCurrentUserForDebugging() {
        // 步骤1：登出并清除用户凭证（逻辑不变）
        guard let userID = self.currentUserID else {
            print("🐞 DEBUG: No user is currently logged in to reset.")
            signOut()
            return
        }
        
        // 步骤2：删除当前用户的Player记录（逻辑不变）
        let playerDescriptor = FetchDescriptor<Player>(predicate: #Predicate { $0.appleUserID == userID })
        do {
            if let playerToDelete = try modelContext.fetch(playerDescriptor).first {
                modelContext.delete(playerToDelete)
                print("🐞 DEBUG: Deleted Player record for userID: \(userID)")
            }
        } catch {
            print("❌ DEBUG: Failed to delete player record: \(error)")
        }
        
        // ✅ 步骤3：新增核心逻辑 - “孤立”所有赛季
        print("ℹ️ DEBUG: Resetting all seasons to be ownerless...")
        let allSeasonsDescriptor = FetchDescriptor<Season>()
        do {
            let allSeasons = try modelContext.fetch(allSeasonsDescriptor)
            for season in allSeasons {
                // 清空这个赛季的管理员列表
                season.administratorIDs.removeAll()
            }
            print("✅ DEBUG: All seasons have been made ownerless.")
        } catch {
            print("❌ DEBUG: Failed to fetch and reset seasons: \(error)")
        }
        
        // 步骤4：保存所有更改并执行登出
        try? modelContext.save()
        signOut()
    }
    
    func signOut() {
        self.currentUserID = nil
        self.currentPlayer = nil
        self.isLoggedIn = false
        self.migrationState = .idle // 确保迁移状态也被重置
        UserDefaults.standard.removeObject(forKey: "AppleUserID")
    }
    
    /// 用户同意成为赛季管理员
    func claimAdminRole(for season: Season, withName name: String?) {
        guard let userID = currentUserID, let player = currentPlayer else { return }
        
        // 将用户设为赛季管理员
        season.administratorIDs.append(userID)

        // 此时Player已存在，无需再创建
        self.isLoggedIn = true
        self.migrationState = .completed

        try? modelContext.save()
        print("✅ Auth: Admin role claimed for season: \(season.name)")
    }

    /// 用户拒绝，直接将迁移状态置为完成
    func declineMigration() {
        self.migrationState = .completed
        print("ℹ️ Auth: User declined migration. Process complete.")
    }
}
