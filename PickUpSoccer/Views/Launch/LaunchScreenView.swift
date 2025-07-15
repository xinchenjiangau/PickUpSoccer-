import SwiftUI

struct LaunchScreenView: View {
    @State private var isActive = false
    @State private var size = 0.8
    @State private var opacity = 0.5
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationStack {
            if isActive {
                if authManager.isLoggedIn {
                    ContentView()
                } else {
                    LoginView()
                }
            } else {
                ZStack {
                    ThemeColor.primary
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Image("iconforsplash_画板 1")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .cornerRadius(25)
                            
                        
                        Text("PickUp Soccer")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(size)
                    .opacity(opacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 1.2)) {
                            self.size = 1.0
                            self.opacity = 1.0
                        }
                    }
                }
                .navigationBarHidden(true)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            self.isActive = true
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    LaunchScreenView()
} 