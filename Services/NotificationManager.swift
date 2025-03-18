import FirebaseFirestore
import FirebaseMessaging

class NotificationManager {
    static let shared = NotificationManager()
    private let db = Firestore.firestore()

    /// ✅ Send a push notification
    func sendNotification(toUserID userID: String, title: String, body: String) {
        let userRef = db.collection("users").document(userID)

        userRef.getDocument { document, error in
            guard let document = document, document.exists,
                  let userData = document.data(),
                  let fcmToken = userData["fcmToken"] as? String else {
                print("⚠️ No FCM token found for user \(userID)")
                return
            }

            let message: [String: Any] = [
                "to": fcmToken,
                "notification": [
                    "title": title,
                    "body": body
                ],
                "data": [
                    "click_action": "FLUTTER_NOTIFICATION_CLICK"
                ]
            ]

            // ✅ Send request to Firebase Cloud Messaging (FCM)
            let url = URL(string: "https://fcm.googleapis.com/fcm/send")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("key=YOUR_SERVER_KEY_HERE", forHTTPHeaderField: "Authorization")
            request.httpBody = try? JSONSerialization.data(withJSONObject: message, options: [])

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("🔥 Error sending push notification: \(error.localizedDescription)")
                } else {
                    print("✅ Push notification sent to \(userID)")
                }
            }
            task.resume()
        }
    }
}
