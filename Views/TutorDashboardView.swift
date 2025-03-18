import SwiftUI
import FirebaseFirestore

struct TutorDashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var scheduledLessons: [Booking] = []
    @State private var completedLessons: [Booking] = []
    @State private var selectedSessionLengths: Set<Int> = [] // ✅ Stores session length selection
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var navigateToBookings = false
    @State private var navigateToAvailability = false
    @State private var navigateBackToDashboard = false
    private let db = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 20) {
            // 🔹 Header
            HStack {
                Button(action: { navigateBackToDashboard = true }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                Spacer()
                Text("Tutor Dashboard")
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding()

            // 🔹 Session Length Selection
            VStack(alignment: .leading) {
                Text("Allowed Session Lengths")
                    .font(.headline)
                
                HStack {
                    Toggle("30 Min", isOn: Binding(
                        get: { selectedSessionLengths.contains(30) },
                        set: { isSelected in updateSessionLength(30, isSelected: isSelected) }
                    ))
                    
                    Toggle("60 Min", isOn: Binding(
                        get: { selectedSessionLengths.contains(60) },
                        set: { isSelected in updateSessionLength(60, isSelected: isSelected) }
                    ))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // 🔹 Lessons Summary
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
            
            // 🔹 Navigation Buttons
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
                TutorAvailabilityView().environmentObject(authManager)
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .onAppear {
            print("🟢 TutorDashboardView appeared, fetching lessons...")
            fetchLessons()
            fetchSessionLengthPreference()
        }
    }
    
    /// 🔹 Fetch scheduled & completed lessons for the tutor
    func fetchLessons() {
        guard let tutorID = authManager.user?.id else { return }

        FirestoreManager.shared.fetchTutorLessons(forTutor: tutorID) { scheduled, completed, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "🔥 Error fetching lessons: \(error.localizedDescription)"
                } else {
                    self.scheduledLessons = scheduled ?? []
                    self.completedLessons = completed ?? []
                    print("📊 Updated Dashboard: \(self.scheduledLessons.count) scheduled, \(self.completedLessons.count) completed")
                }
            }
        }
    }
    
    /// 🔹 Fetch tutor’s current session length preferences
    func fetchSessionLengthPreference() {
        guard let tutorID = authManager.user?.id else { return }
        let docRef = db.collection("tutors").document(tutorID)

        docRef.getDocument { document, error in
            if let error = error {
                self.errorMessage = "🔥 Error fetching session length preferences: \(error.localizedDescription)"
                return
            }
            if let data = document?.data(), let lengths = data["session_lengths"] as? [Int] {
                DispatchQueue.main.async {
                    self.selectedSessionLengths = Set(lengths)
                }
            }
        }
    }
    
    /// 🔹 Update session length selection in Firestore
    func updateSessionLength(_ length: Int, isSelected: Bool) {
        guard let tutorID = authManager.user?.id else { return }
        let docRef = db.collection("tutors").document(tutorID)

        if isSelected {
            selectedSessionLengths.insert(length)
        } else {
            selectedSessionLengths.remove(length)
        }

        docRef.updateData(["session_lengths": Array(selectedSessionLengths)]) { error in
            if let error = error {
                self.errorMessage = "🔥 Error updating session lengths: \(error.localizedDescription)"
            }
        }
    }
}

// Preview
#Preview {
    TutorDashboardView().environmentObject(AuthManager.shared)
}
