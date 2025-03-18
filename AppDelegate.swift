import UIKit
import Firebase
import FirebaseAuth  // ✅ Import FirebaseAuth to fix scope issues
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        print("✅ Firebase Initialized")

        // ✅ Set up Firebase Messaging delegate
        Messaging.messaging().delegate = self
        
        // ✅ Register for push notifications
        registerForPushNotifications(application: application)

        DispatchQueue.main.async {
            print("🚪 App Restarted - Checking Auth State")
            AuthManager.shared.checkAuthState()
        }

        return true
    }
    
    // ✅ Request user permission for push notifications
    private func registerForPushNotifications(application: UIApplication) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Push notification permission granted.")
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            } else {
                print("⚠️ Push notification permission denied: \(error?.localizedDescription ?? "No error")")
            }
        }
    }
    
    // ✅ Handle APNs Token Registration
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken  // ✅ Store APNs token in Firebase Messaging
        print("✅ APNs Token registered successfully.")

        // 🔄 Try to get the FCM token now that APNs is registered
        Messaging.messaging().token { token, error in
            if let error = error {
                print("🔥 Error fetching FCM token: \(error.localizedDescription)")
            } else if let fcmToken = token {
                print("📲 FCM Token retrieved: \(fcmToken)")
                
                if let userID = Auth.auth().currentUser?.uid {
                    print("📌 Storing FCM token in Firestore for user: \(userID)")
                    AuthManager.shared.updateFCMToken(userID: userID, fcmToken: fcmToken)
                } else {
                    print("⚠️ No authenticated user - Cannot store FCM token yet")
                }
            }
        }
    }
    
    // ✅ Handle updated FCM Token (Automatically Updates Firestore)
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken = fcmToken else {
            print("⚠️ FCM token is nil - waiting for refresh")
            return
        }
        
        print("📲 FCM Token received: \(fcmToken)")
        
        if let userID = Auth.auth().currentUser?.uid {
            print("📌 Updating Firestore with new FCM token for user: \(userID)")
            AuthManager.shared.updateFCMToken(userID: userID, fcmToken: fcmToken)
        } else {
            print("⚠️ No authenticated user - Cannot store FCM token yet")
        }
    }
    
    // ✅ Handle push notification when app is open
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📩 Received push notification: \(userInfo)")
        completionHandler(.newData)
    }
}
