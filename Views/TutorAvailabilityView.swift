import SwiftUI
import FirebaseFirestore

struct TutorAvailabilityView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedDate = Date()
    @State private var selectedTime = ""
    @State private var availableSlots: [String] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var navigateBackToTutorDashboard = false

    var tutorID: String? {
        return authManager.user?.isTutor == true ? authManager.user?.id : nil
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Manage Availability")
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

            DatePicker("Select a Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding()

            HStack {
                TextField("Enter Time (e.g. 14:00)", text: $selectedTime)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                Button(action: {
                    guard let tutorID = tutorID, !selectedTime.isEmpty else { return }
                    addAvailability(for: tutorID)
                }) {
                    Text("Add Time")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .padding()
            }

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            List {
                Section(header: Text("Available Slots")) {
                    ForEach(availableSlots, id: \.self) { slot in
                        HStack {
                            Text(slot)
                            Spacer()
                            Button(action: { if let tutorID = tutorID { removeAvailability(for: tutorID, slot: slot) } }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .task(id: selectedDate) {
            if let tutorID = tutorID {
                await fetchAvailability(for: tutorID)
            }
        }
    }

    /// Fetch availability from Firestore
    func fetchAvailability(for tutorID: String) async {
        isLoading = true
        errorMessage = nil
        availableSlots.removeAll()

        let dateKey = formatDate(selectedDate)

        let db = Firestore.firestore()
        let availabilityRef = db.collection("tutors").document(tutorID)
            .collection("availability").document(dateKey)

        do {
            let document = try await availabilityRef.getDocument()
            if let data = document.data(), let slots = data["timeSlots"] as? [String] {
                availableSlots = slots.sorted()
            } else {
                availableSlots = []
            }
        } catch {
            errorMessage = "Error fetching availability: \(error.localizedDescription)"
        }

        isLoading = false
    }

    /// Add a time slot to Firestore
    func addAvailability(for tutorID: String) {
        let dateKey = formatDate(selectedDate)

        let db = Firestore.firestore()
        let availabilityRef = db.collection("tutors").document(tutorID)
            .collection("availability").document(dateKey)

        availableSlots.append(selectedTime)
        availableSlots.sort()

        availabilityRef.setData(["timeSlots": availableSlots], merge: true) { error in
            if let error = error {
                errorMessage = "Failed to add availability: \(error.localizedDescription)"
            } else {
                selectedTime = ""
            }
        }
    }

    /// Remove a time slot from Firestore
    func removeAvailability(for tutorID: String, slot: String) {
        let dateKey = formatDate(selectedDate)

        let db = Firestore.firestore()
        let availabilityRef = db.collection("tutors").document(tutorID)
            .collection("availability").document(dateKey)

        availableSlots.removeAll { $0 == slot }

        if availableSlots.isEmpty {
            availabilityRef.delete()
        } else {
            availabilityRef.setData(["timeSlots": availableSlots], merge: true)
        }
    }

    /// Helper function to format the date as YYYYMMDD
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}

// Preview
#Preview {
    TutorAvailabilityView().environmentObject(AuthManager.shared)
}
