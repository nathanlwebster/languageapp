//
//  AuthView.swift
//  Language App
//
//  Created by Nathan Webster on 3/6/25.
//

import SwiftUI
import FirebaseAuth

struct AuthView: View {
    @EnvironmentObject var authManager: AuthManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage = ""

    var body: some View {
        VStack {
            Text(isSignUp ? "Sign Up" : "Login")
                .font(.largeTitle)
                .bold()

            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .autocapitalization(.none)
                .padding()

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            Button(action: {
                if isSignUp {
                    signUp()
                } else {
                    login()
                }
            }) {
                Text(isSignUp ? "Create Account" : "Login")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
            }

            Button(action: {
                isSignUp.toggle()
            }) {
                Text(isSignUp ? "Already have an account? Login" : "Don't have an account? Sign Up")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .onAppear {
            print("📲 AuthView appeared, checking auth state...")
        }
    }
    
    func signUp() {
        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
            if let error = error {
                errorMessage = "Sign-up failed: \(error.localizedDescription)"
                return
            }

            if let user = authResult?.user {
                let newUser = UserModel(
                    id: user.uid,
                    name: "New User",
                    isTutor: false,
                    languages: ["English"],
                    bio: "Hello! I’m new here.",
                    profileImageURL: nil
                )

                print("✅ Creating profile for new user: \(user.uid)")

                FirestoreManager.shared.saveUserProfile(user: newUser) { error in
                    if let error = error {
                        print("🔥 Error saving new user profile: \(error.localizedDescription)")
                        errorMessage = "Failed to create profile: \(error.localizedDescription)"
                    } else {
                        print("✅ New user profile successfully saved in Firestore!")
                        DispatchQueue.main.async {
                            authManager.isLoggedIn = true // ✅ Let AuthManager handle login state
                            authManager.userHasProfile = false // ✅ New user starts on profile page
                        }
                    }
                }
            }
        }
    }

    func login() {
        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                print("✅ Login successful!")
                DispatchQueue.main.async {
                    authManager.isLoggedIn = true
                }
            }
        }
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView().environmentObject(AuthManager.shared) // ✅ Fixed missing environmentObject
    }
}
