import SwiftUI

struct StudentLessonsView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var upcomingLessons: [Booking] = []
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var canceledLessons: [Booking] = []

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
                if !upcomingLessons.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Upcoming Lessons")
                            .font(.headline)
                            .padding(.top)

                        List(upcomingLessons) { lesson in
                            VStack(alignment: .leading) {
                                Text("Tutor: \(lesson.tutorName)")
                                    .font(.headline)
                                Text("Date: \(lesson.date)")
                                Text("Time: \(lesson.timeSlot)")

                                Button(action: { cancelLesson(lessonID: lesson.id, tutorID: lesson.tutorID) }) {
                                    Text("❌ Cancel Lesson")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                // ✅ Display Canceled Lessons Separately
                if !canceledLessons.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Canceled Lessons")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding(.top)

                        List(canceledLessons) { lesson in
                            VStack(alignment: .leading) {
                                Text("Tutor: \(lesson.tutorName)")
                                    .font(.headline)
                                Text("Date: \(lesson.date)")
                                Text("Time: \(lesson.timeSlot)")
                                Text("❌ Canceled")
                                    .font(.subheadline)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

            }


            Spacer()
        }
        .padding()
        .onAppear {
            print("🟢 StudentLessonsView appeared, fetching upcoming lessons...")
            fetchLessons()
        }
    }

    /// Fetch upcoming confirmed lessons for the student
    func fetchLessons() {
        guard let studentID = authManager.user?.id else { return }

        FirestoreManager.shared.fetchUpcomingLessons(forStudent: studentID) { upcoming, canceled, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "🔥 Error fetching lessons: \(error.localizedDescription)"
                } else {
                    self.upcomingLessons = upcoming ?? []
                    self.canceledLessons = canceled ?? []
                }
            }
        }
    }

    
    func cancelLesson(lessonID: String, tutorID: String) {
        FirestoreManager.shared.updateBookingStatus(tutorID: tutorID, bookingID: lessonID, newStatus: "canceled") { success, error in
            DispatchQueue.main.async {
                if success {
                    if let canceledLesson = upcomingLessons.first(where: { $0.id == lessonID }) {
                        // ✅ Move the lesson to canceledLessons
                        canceledLessons.append(canceledLesson)
                    }
                    // ✅ Remove from upcoming lessons
                    upcomingLessons.removeAll { $0.id == lessonID }
                } else {
                    errorMessage = error?.localizedDescription ?? "Failed to cancel lesson."
                }
            }
        }
    }
}

// Preview
#Preview {
    StudentLessonsView().environmentObject(AuthManager.shared)
}
