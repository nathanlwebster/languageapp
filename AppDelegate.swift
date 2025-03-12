import UIKit
import Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        print("✅ Firebase Initialized")

        DispatchQueue.main.async {
            print("🚪 App Restarted - Logging Out User")
            AuthManager.shared.logout()
        }

        return true
    }
}
