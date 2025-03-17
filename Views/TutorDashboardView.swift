import SwiftUI
import FirebaseFirestore

struct TutorDashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var scheduledLessons: [Booking] = []
    @State private var completedLessons: [Booking] = []
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var navigateToBookings = false
    @State private var navigateToAvailability = false
    @State private var navigateBackToDashboard = false



    var body: some View {
        VStack(spacing: 20) {
            Text("Tutor Dashboard")
                .font(.title2)
                .bold()
            
            Button(action: { navigateBackToDashboard = true }) {
                Text("← Back to Dashboard")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .fullScreenCover(isPresented: $navigateBackToDashboard) {
                DashboardView().environmentObject(authManager)
            }

            
            if isLoading {
                ProgressView("Loading lessons...")
                    .padding()
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Currently Scheduled Lessons: \(scheduledLessons.count)")
                        .font(.headline)
                    
                    Text("Completed Lessons: \(completedLessons.count)")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .padding()
            }
            
            HStack {
                Button(action: { navigateToBookings = true }) {
                    Text("View Bookings")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Button(action: { navigateToAvailability = true }) {
                    Text("Manage Availability")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .fullScreenCover(isPresented: $navigateToBookings) {
                TutorBookingView().environmentObject(authManager)
            }
            .fullScreenCover(isPresented: $navigateToAvailability) {
                TutorAvailabilityView()
            }

            .padding()
            
            Spacer()
        }
        .padding()
        .onAppear {
            print("🟢 TutorDashboardView appeared, fetching lessons...")
            fetchLessons()
        }
    }
    
    /// Fetch currently scheduled and completed lessons for the tutor
    func fetchLessons() {
        guard let tutorID = authManager.user?.id else { return }

        FirestoreManager.shared.fetchTutorLessons(forTutor: tutorID) { scheduled, completed, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "🔥 Error fetching lessons: \(error.localizedDescription)"
                } else {
                    self.scheduledLessons = scheduled ?? []  // ✅ Ensure scheduled lessons update correctly
                    self.completedLessons = completed ?? []
                    print("📊 Updated Dashboard: \(self.scheduledLessons.count) scheduled, \(self.completedLessons.count) completed")
                }
            }
        }
    }
}

// Preview
#Preview {
    TutorDashboardView().environmentObject(AuthManager.shared)
}
