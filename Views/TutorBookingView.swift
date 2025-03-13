import SwiftUI

struct TutorBookingView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var bookings: [Booking] = []
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var pendingBookings: [Booking] = []
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
            } else if pendingBookings.isEmpty {
                Text("No pending bookings.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
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

            Spacer()
        }
        .padding()
        .onAppear {
            print("🟢 TutorBookingView appeared, fetching bookings...")
            fetchPendingBookings()
        }
    }

    /// Fetch all pending bookings for the tutor
    func fetchPendingBookings() {
        guard let tutorID = authManager.user?.id, let tutorName = authManager.user?.name else { return }
        
        isLoading = true
        FirestoreManager.shared.fetchPendingBookings(forTutor: tutorID, tutorName: tutorName) { fetchedBookings, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = "Error: \(error.localizedDescription)"
                } else {
                    self.pendingBookings = fetchedBookings ?? []
                    print("🔍 Fetching pending bookings for Tutor ID:", tutorID)
                }
            }
        }
    }


    /// Approve a booking
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
                    } else {
                        self.errorMessage = error?.localizedDescription ?? "Failed to reject booking."
                    }
                }
            }
        }
    }


}

// Preview
#Preview {
    TutorBookingView().environmentObject(AuthManager.shared)
}
