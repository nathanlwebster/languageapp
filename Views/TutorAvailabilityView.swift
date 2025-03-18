import SwiftUI
import FirebaseFirestore

struct TutorAvailabilityView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedDate = Date()
    @State private var availableTimeSlots: [String] = []
    @State private var selectedTimeSlots: Set<String> = []
    @State private var errorMessage: String?
    @State private var bookedTimeSlots: [String] = [] // ✅ Holds confirmed bookings
    private let db = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 10) {
            // 🔹 Header with Back Button and Title
            HStack {
                Button(action: { navigateBack() }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                        .font(.title2)
                }
                Spacer()
                Text("Manage Availability")
                    .font(.title2)
                    .bold()
                Spacer()
            }
            .padding()
            
            // 🔹 Date Picker (Keeps manual date selection)
            DatePicker("Select a Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding()
                .onChange(of: selectedDate) { _ in
                    Task { await loadAvailability() }
                }
            
            // 🔹 Date Navigation (Fixed placement)
            HStack {
                Button(action: { moveDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(canMoveLeft ? .blue : .gray)
                        .font(.title2)
                }
                .disabled(!canMoveLeft)

                Text(formattedDate(selectedDate))
                    .font(.headline)
                    .padding(.horizontal)

                Button(action: { moveDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(canMoveRight ? .blue : .gray)
                        .font(.title2)
                }
                .disabled(!canMoveRight)
            }
            .padding(.vertical)

            // 🔹 Scrollable Timeslot List
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(generateTimeSlots(), id: \.self) { slot in
                        HStack {
                            Text(slot)
                                .font(.headline)
                                .foregroundColor(isTimeSlotBooked(slot) || availableTimeSlots.contains(slot) ? .gray : .black) // ✅ Grey out booked AND available slots
                            
                            Spacer()
                            
                            if isTimeSlotBooked(slot) {
                                Image(systemName: "lock.fill") // 🔒 Lock icon for booked slots
                                    .foregroundColor(.red)
                            } else if availableTimeSlots.contains(slot) {
                                Button(action: { deleteSingleTimeSlot(slot) }) {
                                    Image(systemName: "trash") // 🗑️ Trashcan for available slots
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        .padding()
                        .background(isTimeSlotBooked(slot) || availableTimeSlots.contains(slot) ? Color.gray.opacity(0.2) : Color.white) // ✅ Grey out both booked & available slots
                        .cornerRadius(8)
                        .onTapGesture {
                            if !(isTimeSlotBooked(slot) || availableTimeSlots.contains(slot)) { // ✅ Only allow selection if NOT booked or already available
                                toggleTimeSlotSelection(slot)
                            }
                        }
                    }
                }
            }
            .padding()
            
            // 🔹 Buttons for Adding and Clearing Availability
            Button(action: addSelectedTimeSlots) {
                Text("Add Availability")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedTimeSlots.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(selectedTimeSlots.isEmpty)
            
            Button(action: deleteAllAvailabilityForDay) {
                Text("Clear Availability")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top)
        }
        .padding()
        .task { await loadAvailability() }
    }

    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func generateTimeSlots() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a" // Ensure the UI uses the same format as `bookedTimeSlots`

        var slots: [String] = []
        var currentTime = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!

        for _ in 0..<48 {
            slots.append(formatter.string(from: currentTime))
            currentTime = Calendar.current.date(byAdding: .minute, value: 30, to: currentTime)!
        }
        return slots
    }
    
    private func isTimeSlotBooked(_ slot: String) -> Bool {
        return bookedTimeSlots.contains(slot) // ✅ Returns true if slot is already booked
    }
    
    private func toggleTimeSlotSelection(_ slot: String) {
        guard !isTimeSlotBooked(slot) else { return } // ✅ Prevent selection if booked
        
        if selectedTimeSlots.contains(slot) {
            selectedTimeSlots.remove(slot)
        } else {
            selectedTimeSlots.insert(slot)
        }
    }
    
    private func addSelectedTimeSlots() {
        guard let tutorID = authManager.user?.id else { return }
        let dateKey = formattedDateKey(selectedDate)
        let docRef = db.collection("tutors").document(tutorID).collection("availability").document(dateKey)
        
        docRef.getDocument { document, error in
            if let error = error {
                errorMessage = "Error checking document: \(error.localizedDescription)"
                return
            }

            if document?.exists == true {
                // ✅ Document exists, update it
                docRef.updateData(["timeSlots": FieldValue.arrayUnion(Array(selectedTimeSlots))]) { error in
                    if let error = error {
                        errorMessage = "Error adding slots: \(error.localizedDescription)"
                    } else {
                        availableTimeSlots.append(contentsOf: selectedTimeSlots)
                        selectedTimeSlots.removeAll()
                    }
                }
            } else {
                // ✅ Document does NOT exist, create it first
                docRef.setData(["timeSlots": Array(selectedTimeSlots)]) { error in
                    if let error = error {
                        errorMessage = "Error creating document: \(error.localizedDescription)"
                    } else {
                        availableTimeSlots.append(contentsOf: selectedTimeSlots)
                        selectedTimeSlots.removeAll()
                    }
                }
            }
        }
    }
    
    private func deleteAllAvailabilityForDay() {
        guard let tutorID = authManager.user?.id else { return }
        let dateKey = formattedDateKey(selectedDate)
        let docRef = db.collection("tutors").document(tutorID).collection("availability").document(dateKey)
        
        docRef.delete { error in
            if let error = error {
                errorMessage = "Error deleting availability: \(error.localizedDescription)"
            } else {
                availableTimeSlots.removeAll()
            }
        }
    }
    
    private func loadAvailability() async {
        guard let tutorID = authManager.user?.id else { return }
        let dateKey = formattedDateKey(selectedDate)

        let availabilityRef = db.collection("tutors").document(tutorID).collection("availability").document(dateKey)
        let bookingsRef = db.collection("tutors").document(tutorID).collection("bookings")
            .whereField("date", isEqualTo: dateKey)
            .whereField("status", in: ["pending", "confirmed"])

        do {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm" // Matches Firestore format
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "hh:mm a" // Matches UI format

            // Fetch available time slots
            let availabilityDoc = try await availabilityRef.getDocument()
            let availabilityData = availabilityDoc.data()
            let slots = availabilityData?["timeSlots"] as? [String] ?? []

            // Fetch booked time slots and format correctly
            let bookingsSnapshot = try await bookingsRef.getDocuments()
            let bookedSlotsRaw = bookingsSnapshot.documents.compactMap { $0.data()["timeSlot"] as? String }

            let bookedSlotsFormatted = bookedSlotsRaw.compactMap { rawTime -> String? in
                if let date = formatter.date(from: rawTime) {
                    return displayFormatter.string(from: date) // Convert to 12-hour format
                }
                return nil
            }

            DispatchQueue.main.async {
                self.availableTimeSlots = slots.sorted()
                self.bookedTimeSlots = bookedSlotsFormatted.sorted() // ✅ Now correctly formatted
                print("📅 Available: \(self.availableTimeSlots), 🔒 Booked: \(self.bookedTimeSlots)")
            }
        } catch {
            print("🔥 Error fetching availability/bookings for \(dateKey): \(error.localizedDescription)")
        }
    }
    
    private func formattedDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
    
    private func handleSwipe(gesture: DragGesture.Value) {
        let swipeThreshold: CGFloat = 50.0
        if gesture.translation.width > swipeThreshold { // Swipe Right
            let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate)!
            if newDate >= Date() {
                selectedDate = newDate
            }
        } else if gesture.translation.width < -swipeThreshold { // Swipe Left
            let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate)!
            if newDate <= Calendar.current.date(byAdding: .day, value: 28, to: Date())! {
                selectedDate = newDate
            }
        }
    }
    
    private func navigateBack() {
        presentationMode.wrappedValue.dismiss()
    }
    
    private var canMoveLeft: Bool {
        return selectedDate > Date()
    }

    private var canMoveRight: Bool {
        let maxDate = Calendar.current.date(byAdding: .day, value: 28, to: Date())!
        return selectedDate < maxDate
    }

    private func moveDate(by days: Int) {
        let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate)!
        if (days < 0 && canMoveLeft) || (days > 0 && canMoveRight) {
            selectedDate = newDate
        }
    }
    
    private func deleteSingleTimeSlot(_ slot: String) {
        guard let tutorID = authManager.user?.id else { return }
        let dateKey = formattedDateKey(selectedDate)
        let docRef = db.collection("tutors").document(tutorID).collection("availability").document(dateKey)
        
        if bookedTimeSlots.contains(slot) {
            errorMessage = "❌ This time slot is booked. Please cancel the lesson from the Bookings page."
            return
        }
        
        docRef.updateData(["timeSlots": FieldValue.arrayRemove([slot])]) { error in
            if let error = error {
                errorMessage = "Error deleting slot: \(error.localizedDescription)"
            } else {
                availableTimeSlots.removeAll { $0 == slot }
            }
        }
    }
}
