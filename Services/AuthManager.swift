//
//  AuthManager.swift
//  Language App
//
//  Created by Nathan Webster on 3/6/25.
//

import FirebaseAuth
import SwiftUI
import FirebaseFirestore

class AuthManager: ObservableObject {
    @Published var user: UserModel?
    @AppStorage("isLoggedIn") var isLoggedIn = false
    @Published var userHasProfile: Bool? = nil
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    @Published var logoutInProgress = false // ✅ Keep track of logout state

    static let shared = AuthManager()

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
        let db = Firestore.firestore()

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
            }
        }
    }




    /// ✅ Forces SwiftUI to update and react to changes
    func forceRefreshUI() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.objectWillChange.send()
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
                
                // ✅ Create a new UserModel with default values
                let newUser = UserModel(
                    id: firebaseUser.uid,
                    name: firebaseUser.email ?? "Unknown",
                    isTutor: false, // Default to student, can be changed later
                    languages: [],
                    bio: "",
                    profileImageURL: nil
                )
                
                // ✅ Store in Firestore
                let db = Firestore.firestore()
                db.collection("users").document(firebaseUser.uid).setData([
                    "id": newUser.id,
                    "name": newUser.name,
                    "isTutor": newUser.isTutor,
                    "languages": newUser.languages,
                    "bio": newUser.bio,
                    "profileImageURL": newUser.profileImageURL as Any
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

    func login(email: String, password: String, completion: @escaping (Result<UserModel, Error>) -> Void) {
        print("🔑 Attempting to log in user: \(email)")

        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Login Failed: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }

                guard let firebaseUser = authResult?.user else {
                    completion(.failure(NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "User login failed."])))
                    return
                }

                print("✅ Login Successful: \(firebaseUser.email ?? "Unknown Email") (UID: \(firebaseUser.uid))")

                // ✅ Fetch profile from Firestore
                self.checkIfProfileExists(userID: firebaseUser.uid)
                
                // ✅ Set a placeholder user until Firestore data loads
                self.user = UserModel(
                    id: firebaseUser.uid,
                    name: firebaseUser.email ?? "Unknown",
                    isTutor: false,
                    languages: [],
                    bio: "",
                    profileImageURL: nil
                )

                self.isLoggedIn = true
                completion(.success(self.user!)) // ✅ Once profile loads, UI updates
            }
        }
    }


    func logout() {
        guard !logoutInProgress else { return } // ✅ Prevent multiple logouts
        logoutInProgress = true

        DispatchQueue.main.async {
            print("🚪 Logging out user...")
            self.isLoggedIn = false
            self.userHasProfile = nil // ✅ Reset to prevent stale UI state
            self.user = nil
            self.forceRefreshUI()
        }

        do {
            try Auth.auth().signOut()
            print("✅ Successfully logged out, isLoggedIn set to false")
        } catch {
            print("🔥 Logout Error: \(error.localizedDescription)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { // ✅ Small delay for smoother transition
            self.logoutInProgress = false
            self.forceRefreshUI()
            print("🔄 Logout completed, transitioning directly to AuthView.")

            // ✅ Immediately re-check auth state after logout
            self.checkAuthState()
        }
    }

}
