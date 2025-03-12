import SwiftUI
import Firebase

@main
struct LanguageApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate // ✅ Ensure AppDelegate is used
    @StateObject var authManager = AuthManager.shared // ✅ Ensure shared instance is used

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager) // ✅ Inject globally
        }
    }
}
