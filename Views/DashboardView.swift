import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var navigateToProfile = false
    @State private var navigateToBooking = false
    @State private var navigateToBookings = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome to Your Dashboard")
                    .font(.largeTitle)
                    .bold()
                    .padding()

                Button(action: { navigateToProfile = true }) {
                    Text("Edit Profile")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
                }

                NavigationLink("Test Availability", destination: TutorAvailabilityView())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)

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
                
                Button(action: { navigateToBooking = true }) {
                    Text("Book a Lesson")
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
                
                if authManager.user?.isTutor == true { // Only show for tutors
                    Button(action: { navigateToBookings = true }) {
                        Text("My Bookings")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    .fullScreenCover(isPresented: $navigateToBookings) {
                        TutorBookingView().environmentObject(authManager)
                    }
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

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView().environmentObject(AuthManager.shared)
    }
}
