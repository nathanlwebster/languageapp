import SwiftUI

struct TutorBookingView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var bookings: [Booking] = []
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var pendingBookings: [Booking] = []
    @State private var confirmedBookings: [Booking] = []
    @State private var navigateBackToTutorDashboard = false

    var body: some View {
        VStack(spacing: 20) {
            Text("My Bookings")
                .font(.title2)
                .bold()

            Button(action: { navigateBackToTutorDashboard = true }) {
                Text("← Back to Dashboard")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .fullScreenCover(isPresented: $navigateBackToTutorDashboard) {
                TutorDashboardView().environmentObject(authManager)
            }

            if isLoading {
                ProgressView()
                    .padding()
            } else if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else if pendingBookings.isEmpty && confirmedBookings.isEmpty {
                Text("No bookings.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                // ✅ Pending Bookings Section
                if !pendingBookings.isEmpty {
                    Text("Pending Bookings")
                        .font(.headline)
                        .padding(.top)

                    List(pendingBookings) { booking in
                        VStack(alignment: .leading) {
                            Text("Student: \(booking.studentName)")
                                .font(.headline)
                            Text("Date: \(booking.date)")
                            Text("Time: \(booking.timeSlot)")

                            HStack {
                                Button(action: { confirmBooking(bookingID: booking.id) }) {
                                    Text("✅ Approve")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .buttonStyle(.borderless)

                                Button(action: { rejectBooking(bookingID: booking.id) }) {
                                    Text("❌ Reject")
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

                // ✅ Confirmed Lessons Section
                if !confirmedBookings.isEmpty {
                    Text("Confirmed Lessons (Mark as Completed)")
                        .font(.headline)
                        .padding(.top)

                    List(confirmedBookings) { booking in
                        VStack(alignment: .leading) {
                            Text("Student: \(booking.studentName)")
                                .font(.headline)
                            Text("Date: \(booking.date)")
                            Text("Time: \(booking.timeSlot)")

                            Button(action: { completeLesson(bookingID: booking.id) }) {
                                Text("✅ Mark as Completed")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            print("🟢 TutorBookingView appeared, fetching bookings...")
            fetchBookings()
        }
    }

    /// Fetch all bookings (pending and confirmed)
    func fetchBookings() {
        guard let tutorID = authManager.user?.id, let tutorName = authManager.user?.name else { return }

        isLoading = true
        FirestoreManager.shared.fetchTutorBookings(forTutor: tutorID, tutorName: tutorName) { pending, confirmed, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                } else {
                    self.pendingBookings = pending ?? []
                    self.confirmedBookings = confirmed ?? []
                    print("🔍 Fetched \(pending?.count ?? 0) pending bookings and \(confirmed?.count ?? 0) confirmed bookings.")
                }
            }
        }
    }

    /// Approve a booking
    func confirmBooking(bookingID: String) {
        guard let tutorID = authManager.user?.id else { return }

        FirestoreManager.shared.getBookingStatus(tutorID: tutorID, bookingID: bookingID) { currentStatus in
            guard currentStatus == "pending" else {
                print("⚠️ Booking \(bookingID) is no longer pending, skipping confirmation.")
                return
            }

            FirestoreManager.shared.updateBookingStatus(tutorID: tutorID, bookingID: bookingID, newStatus: "confirmed") { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.pendingBookings.removeAll { $0.id == bookingID }
                        self.fetchBookings()
                    } else {
                        self.errorMessage = error?.localizedDescription ?? "Failed to confirm booking."
                    }
                }
            }
        }
    }

    /// Reject a booking
    func rejectBooking(bookingID: String) {
        guard let tutorID = authManager.user?.id else { return }

        FirestoreManager.shared.getBookingStatus(tutorID: tutorID, bookingID: bookingID) { currentStatus in
            guard currentStatus == "pending" else {
                print("⚠️ Booking \(bookingID) is no longer pending, skipping rejection.")
                return
            }

            FirestoreManager.shared.updateBookingStatus(tutorID: tutorID, bookingID: bookingID, newStatus: "rejected") { success, error in
                DispatchQueue.main.async {
                    if success {
                        self.pendingBookings.removeAll { $0.id == bookingID }
                        self.fetchBookings()
                    } else {
                        self.errorMessage = error?.localizedDescription ?? "Failed to reject booking."
                    }
                }
            }
        }
    }

    /// Mark a confirmed lesson as completed
    func completeLesson(bookingID: String) {
        guard let tutorID = authManager.user?.id else { return }

        FirestoreManager.shared.updateBookingStatus(tutorID: tutorID, bookingID: bookingID, newStatus: "completed") { success, error in
            DispatchQueue.main.async {
                if success {
                    self.confirmedBookings.removeAll { $0.id == bookingID }
                    self.fetchBookings()
                } else {
                    self.errorMessage = error?.localizedDescription ?? "Failed to mark lesson as completed."
                }
            }
        }
    }
}

// Preview
#Preview {
    TutorBookingView().environmentObject(AuthManager.shared)
}
