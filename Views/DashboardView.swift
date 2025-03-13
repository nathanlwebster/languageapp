import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var navigateToProfile = false
    @State private var navigateToBooking = false
    @State private var navigateToLessons = false
    @State private var navigateToTutorDashboard = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome to Your Dashboard")
                    .font(.largeTitle)
                    .bold()
                    .padding()

                // ✅ Edit Profile Button
                Button(action: { navigateToProfile = true }) {
                    Text("Edit Profile")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                // ✅ For Students: Book a Lesson and View Upcoming Lessons
                if authManager.user?.isTutor == false {
                    Button(action: { navigateToBooking = true }) {
                        Text("📅 Book a Lesson")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    .fullScreenCover(isPresented: $navigateToBooking) {
                        StudentBookingView().environmentObject(authManager)
                    }

                    Button(action: { navigateToLessons = true }) {
                        Text("📖 My Upcoming Lessons")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.purple)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    .fullScreenCover(isPresented: $navigateToLessons) {
                        StudentLessonsView().environmentObject(authManager)
                    }
                }

                // ✅ For Tutors: Access Tutor Dashboard
                if authManager.user?.isTutor == true {
                    Button(action: { navigateToTutorDashboard = true }) {
                        Text("📊 Tutor Dashboard")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    .fullScreenCover(isPresented: $navigateToTutorDashboard) {
                        TutorDashboardView().environmentObject(authManager)
                    }
                }

                // ✅ Log Out Button
                Button(action: {
                    print("🚪 DashboardView Logout Button Pressed")
                    authManager.logout()
                }) {
                    Text("Log Out")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Dashboard")
            .fullScreenCover(isPresented: $navigateToProfile) {
                ProfileView().environmentObject(authManager)
            }
        }
    }
}

// Preview
#Preview {
    DashboardView().environmentObject(AuthManager.shared)
}
