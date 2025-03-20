import FirebaseAuth
import FirebaseFirestore
import FirebaseMessaging
import SwiftUI

class AuthManager: ObservableObject {
    @Published var user: UserModel?
    @Published var userID: String?
    @AppStorage("isLoggedIn") var isLoggedIn = false
    @Published var userHasProfile: Bool? = nil
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    @Published var logoutInProgress = false // ✅ Keep track of logout state

    static let shared = AuthManager()
    private let db = Firestore.firestore()

    func checkAuthState() {
        guard !logoutInProgress else {
            print("⚠️ checkAuthState() skipped: Logout is in progress.")
            return
        }

        if let handle = authListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
            authListenerHandle = nil
        }

        print("🔍 checkAuthState() started...")

        authListenerHandle = Auth.auth().addStateDidChangeListener { _, user in
            DispatchQueue.main.async {
                if let user = user {
                    print("✅ Firebase detected user: \(user.email ?? "Unknown Email")")
                    self.user = UserModel(
                        id: user.uid,
                        name: user.email ?? "Unknown",
                        isTutor: false, // This will be updated when fetching from Firestore
                        languages: [],
                        bio: "",
                        profileImageURL: nil
                    )

                    if !self.isLoggedIn {
                        self.isLoggedIn = true
                        print("🔄 Setting isLoggedIn = true")
                    }

                    self.checkIfProfileExists(userID: user.uid)

                    // ✅ Update FCM token upon login
                    if let fcmToken = Messaging.messaging().fcmToken {
                        self.updateFCMToken(userID: user.uid, fcmToken: fcmToken)
                    } else {
                        print("⚠️ No FCM token found at login")
                    }

                } else {
                    print("🚨 Firebase says NO USER is logged in. Checking why...")

                    if Auth.auth().currentUser == nil {
                        print("🚪 `Auth.auth().currentUser` is nil. This is a real logout. Setting isLoggedIn = false.")
                        self.isLoggedIn = false
                        self.user = nil
                        self.userHasProfile = false
                    } else {
                        print("⚠️ `Auth.auth().currentUser` is NOT nil, avoiding false logout.")
                    }
                }
            }
        }
    }

    func checkIfProfileExists(userID: String) {
        DispatchQueue.main.async {
            print("🔄 Resetting userHasProfile to nil while checking Firestore...")
            self.userHasProfile = nil
            self.user = nil  // ✅ Reset user before fetching
            self.objectWillChange.send()
        }

        print("🔍 Fetching profile from Firestore for userID: \(userID)")

        db.collection("users").document(userID).getDocument { document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🔥 Firestore error while checking profile: \(error.localizedDescription)")
                    self.userHasProfile = false
                    return
                }
                
                guard let document = document, document.exists, let data = document.data() else {
                    print("🆕 No profile found for userID: \(userID) - New user setup required.")
                    self.userHasProfile = false
                    self.objectWillChange.send()
                    return
                }

                // ✅ Manually map Firestore document fields to UserModel
                let userModel = UserModel(
                    id: userID,
                    name: data["name"] as? String ?? "Unknown",
                    isTutor: data["isTutor"] as? Bool ?? false,
                    languages: data["languages"] as? [String] ?? [],
                    bio: data["bio"] as? String ?? "",
                    profileImageURL: data["profileImageURL"] as? String
                )

                print("✅ Profile loaded successfully: \(userModel)")
                self.user = userModel
                self.userHasProfile = true
                self.objectWillChange.send()

                // ✅ Ensure the FCM token is up to date
                if let fcmToken = Messaging.messaging().fcmToken {
                    self.updateFCMToken(userID: userID, fcmToken: fcmToken)
                }
            }
        }
    }

    func updateFCMToken(userID: String, fcmToken: String) {
        let userRef = db.collection("users").document(userID)

        userRef.updateData(["fcmToken": fcmToken]) { error in
            if let error = error {
                print("🔥 Error updating FCM token: \(error.localizedDescription)")
            } else {
                print("✅ FCM token updated successfully for user \(userID)")
            }
        }
    }

    func signUp(email: String, password: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let firebaseUser = authResult?.user else {
                    completion(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User creation failed."])))
                    return
                }
                
                let newUser = UserModel(
                    id: firebaseUser.uid,
                    name: firebaseUser.email ?? "Unknown",
                    isTutor: false,
                    languages: [],
                    bio: "",
                    profileImageURL: nil
                )

                let db = Firestore.firestore()
                db.collection("users").document(firebaseUser.uid).setData([
                    "id": newUser.id,
                    "name": newUser.name,
                    "isTutor": newUser.isTutor,
                    "languages": newUser.languages,
                    "bio": newUser.bio,
                    "profileImageURL": newUser.profileImageURL as Any,
                    "fcmToken": Messaging.messaging().fcmToken ?? ""
                ]) { error in
                    if let error = error {
                        print("🔥 Error saving new user profile: \(error.localizedDescription)")
                        completion(.failure(error))
                    } else {
                        print("✅ New user profile saved to Firestore: \(newUser)")
                        self.user = newUser
                        self.isLoggedIn = true
                        self.userHasProfile = true
                        completion(.success(newUser))
                    }
                }
            }
        }
    }

    func logout() {
        guard !logoutInProgress else { return }
        logoutInProgress = true

        DispatchQueue.main.async {
            print("🚪 Logging out user...")
            self.isLoggedIn = false
            self.userHasProfile = nil
            self.user = nil
            self.forceRefreshUI()
        }

        do {
            try Auth.auth().signOut()
            print("✅ Successfully logged out, isLoggedIn set to false")
        } catch {
            print("🔥 Logout Error: \(error.localizedDescription)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.logoutInProgress = false
            self.forceRefreshUI()
            print("🔄 Logout completed, transitioning directly to AuthView.")
            self.checkAuthState()
        }
    }

    /// ✅ Forces SwiftUI to update and react to changes
    func forceRefreshUI() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.objectWillChange.send()
        }
    }
}
