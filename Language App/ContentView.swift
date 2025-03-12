import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isLoggedIn {
                if let hasProfile = authManager.userHasProfile {
                    if hasProfile {
                        DashboardView()
                    } else {
                        ProfileView()
                    }
                } else {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("Loading your profile...")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: authManager.isLoggedIn)
        .onAppear {
            print("📲 ContentView appeared, checking authentication state...")
            authManager.checkAuthState()
        }
        .task(id: authManager.userHasProfile) {
            if let hasProfile = authManager.userHasProfile {
                DispatchQueue.main.async {
                    print("🔄 userHasProfile changed to: \(String(describing: hasProfile)) — Ensuring correct navigation...")

                    if authManager.isLoggedIn {
                        if hasProfile {
                            print("✅ Navigating to DashboardView...")
                        } else {
                            print("🆕 Navigating to ProfileView for new user setup...")
                        }
                    } else {
                        print("🚪 User logged out, navigating to AuthView.")
                    }
                    authManager.forceRefreshUI() // ✅ Ensures UI updates
                }
            } else {
                print("⏳ Waiting for userHasProfile to be determined...")
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(AuthManager.shared)
}
