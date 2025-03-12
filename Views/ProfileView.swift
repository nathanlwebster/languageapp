import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var user: UserModel?
    @State private var name = ""
    @State private var isTutor = false
    @State private var languages = ""
    @State private var bio = ""
    @State private var errorMessage = ""
    @State private var navigateToDashboard = false
    @State private var navigateToAuth = false // ✅ Added for instant AuthView transition

    var body: some View {
        VStack {
            Text("Profile")
                .font(.largeTitle)
                .bold()
                .padding()

            TextField("Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Toggle("Are you a Tutor?", isOn: $isTutor)
                .padding()

            TextField("Languages (comma-separated)", text: $languages)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextField("Bio", text: $bio)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            Button(action: saveProfile) {
                Text("Save Changes")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
            }

            Button(action: {
                authManager.logout()
                navigateToAuth = true // ✅ Ensures direct navigation to AuthView
            }) {
                Text("Log Out")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
            }
        }
        .padding()
        .onAppear { loadProfile() }
        .fullScreenCover(isPresented: $navigateToDashboard) { // ✅ Navigates to Dashboard when saving profile
            DashboardView().environmentObject(authManager)
        }
        .fullScreenCover(isPresented: $navigateToAuth) { // ✅ Navigates to AuthView when logging out
            AuthView().environmentObject(authManager)
        }
    }

    func loadProfile() {
        guard let userID = Auth.auth().currentUser?.uid else {
            errorMessage = "User not logged in."
            return
        }

        FirestoreManager.shared.getUserProfile(userID: userID) { fetchedUser in
            DispatchQueue.main.async {
                if let fetchedUser = fetchedUser {
                    print("✅ Existing profile loaded: \(fetchedUser)")
                    self.user = fetchedUser
                    self.name = fetchedUser.name
                    self.isTutor = fetchedUser.isTutor
                    self.languages = fetchedUser.languages.joined(separator: ", ")
                    self.bio = fetchedUser.bio
                    authManager.userHasProfile = true
                    errorMessage = ""
                } else {
                    print("🆕 No existing profile found. This must be a new user.")
                    self.user = UserModel(
                        id: userID,
                        name: "",
                        isTutor: false,
                        languages: [],
                        bio: "",
                        profileImageURL: nil
                    )
                    errorMessage = "Please complete your profile."
                }
            }
        }
    }



    func saveProfile() {
        guard let userID = Auth.auth().currentUser?.uid else { return }

        let updatedUser = UserModel(
            id: userID,
            name: name,
            isTutor: isTutor,
            languages: languages.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) },
            bio: bio,
            profileImageURL: user?.profileImageURL
        )

        if let existingUser = user, updatedUser == existingUser {
            print("🟡 No changes detected in profile. Still navigating to Dashboard.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                navigateToDashboard = true
            }
            return
        }

        FirestoreManager.shared.saveUserProfile(user: updatedUser) { error in
            DispatchQueue.main.async {
                if let error = error {
                    errorMessage = "Error saving profile: \(error.localizedDescription)"
                    print("🔥 Error saving profile: \(error.localizedDescription)")
                } else {
                    print("✅ Profile updated successfully in Firestore!")
                    authManager.userHasProfile = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        navigateToDashboard = true
                    }
                }
            }
        }
    }
}
