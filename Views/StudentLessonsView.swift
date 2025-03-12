import SwiftUI

struct StudentLessonsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var upcomingLessons: [Booking] = []
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Upcoming Lessons")
                .font(.title2)
                .bold()

            if isLoading {
                ProgressView("Loading lessons...")
                    .padding()
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else if upcomingLessons.isEmpty {
                Text("No upcoming lessons.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(upcomingLessons) { lesson in
                    VStack(alignment: .leading) {
                        Text("Tutor: \(lesson.tutorName)")
                            .font(.headline)
                        Text("Date: \(lesson.date)")
                        Text("Time: \(lesson.timeSlot)")
                    }
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            print("🟢 StudentLessonsView appeared, fetching upcoming lessons...")
            fetchUpcomingLessons()
        }
    }

    /// Fetch upcoming confirmed lessons for the student
    func fetchUpcomingLessons() {
        guard let studentID = authManager.user?.id else { return }
        
        isLoading = true
        FirestoreManager.shared.fetchUpcomingLessons(forStudent: studentID) { fetchedLessons, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                } else {
                    self.upcomingLessons = fetchedLessons ?? []
                    print("✅ Found \(upcomingLessons.count) upcoming lessons for student \(studentID)")
                }
            }
        }
    }
}

// Preview
#Preview {
    StudentLessonsView().environmentObject(AuthManager.shared)
}
