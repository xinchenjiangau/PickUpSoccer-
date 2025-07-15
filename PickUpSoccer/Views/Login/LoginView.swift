import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) var colorScheme
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 40) {
            // Logo
            Image("iconforsplash_画板 1")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .cornerRadius(25)
                .shadow(radius: 10)
            
            Text("欢迎使用 PickUp Soccer")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(ThemeColor.text)
            
            Text("请登录以开始使用")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            // Sign in with Apple 按钮
            SignInWithAppleButton(
                .signIn,
                onRequest: configure,
                onCompletion: handle
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding(.top, 60)
        .background(ThemeColor.background)
        .alert("登录失败", isPresented: $showError) {
            Button("确定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func configure(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }
    
    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            if let appleCredential = auth.credential as? ASAuthorizationAppleIDCredential {
                Task {
                    await authManager.signInWithApple(credential: appleCredential)
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
            print("Apple 登录失败: \(error.localizedDescription)")
        }
    }
} 