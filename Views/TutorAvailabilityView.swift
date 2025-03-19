import SwiftUI
import FirebaseFirestore

struct TutorAvailabilityView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedDate = Date()
    @State private var availableTimeSlots: [String] = []
    @State private var selectedTimeSlots: Set<String> = []
    @State private var errorMessage: String?
    @State private var bookedTimeSlots: [String: String] = [:]
    @State private var allowedSessionLengths: Set<Int> = [30, 60] // Default to both allowed
    @State private var tutorSessionLengths: [Int] = []
    @State private var pendingTimeSlots: [String] = []
    @State private var confirmedTimeSlots: [String] = []
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
                        getTimeSlotView(slot)
                    }

                }
            }

            //.onAppear { _ = debugSlots } // ✅ Trigger debugging when UI loads
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
        .task {
            await ensureCorrectInitialDate()
        }
        .task {
            guard let tutor = authManager.user else { return }
            
            print("📡 Calling fetchBookings for Tutor: \(tutor.id)")
            
            FirestoreManager.shared.fetchBookings(forTutor: tutor.id, tutorName: tutor.name) { fetchedSlots in
                DispatchQueue.main.async {
                    print("📡 Received Fetched Slots: \(fetchedSlots)")

                    // ✅ Debugging Before Assignment
                    print("🚀 BEFORE ASSIGNMENT - Confirmed: \(self.confirmedTimeSlots)")
                    print("🚀 BEFORE ASSIGNMENT - Pending: \(self.pendingTimeSlots)")

                    // ✅ Assign values inside DispatchQueue to trigger UI refresh
                    self.bookedTimeSlots = fetchedSlots

                    // ✅ Convert dictionary into arrays of keys
                    let confirmed = fetchedSlots.filter { $0.value == "confirmed" }.map { $0.key }
                    let pending = fetchedSlots.filter { $0.value == "pending" }.map { $0.key }

                    // ✅ Assign to @State variables
                    self.confirmedTimeSlots = confirmed
                    self.pendingTimeSlots = pending

                    // ✅ Debugging After Assignment
                    print("✅ AFTER ASSIGNMENT - Confirmed: \(self.confirmedTimeSlots)")
                    print("✅ AFTER ASSIGNMENT - Pending: \(self.pendingTimeSlots)")
                }
            }
        }
    }

    private func ensureCorrectInitialDate() async {
        DispatchQueue.main.async {
            self.selectedDate = Date() // ✅ Set today's date before fetching data
        }

        do {
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms delay to allow UI update
            await loadAvailability() // ✅ Fetch availability after ensuring correct date
        } catch {
            print("⚠️ Task sleep error: \(error.localizedDescription)")
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func generateTimeSlots() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"  // ✅ Ensure 12-hour format

        var slots: [String] = []
        var currentTime = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!

        for _ in 0..<48 {
            slots.append(formatter.string(from: currentTime))
            currentTime = Calendar.current.date(byAdding: .minute, value: 30, to: currentTime)!
        }
        return slots
    }
    
    private func isTimeSlotBooked(_ slot: String) -> Bool {
        if let status = bookedTimeSlots[slot], status == "confirmed" {
            print("⛔ DEBUG: Slot \(slot) is confirmed.")
            return true
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        if let startTime = formatter.date(from: slot) {
            let nextTime = Calendar.current.date(byAdding: .minute, value: 30, to: startTime)!
            let nextSlot = formatter.string(from: nextTime)

            // ✅ Check if the current slot is part of a 60-minute booking
            if let currentStatus = bookedTimeSlots[slot], currentStatus == "confirmed",
               let nextStatus = bookedTimeSlots[nextSlot], nextStatus == "confirmed" {
                //print("🔒 DEBUG: Slot \(slot) is part of a 60-minute session, blocking \(nextSlot).")
                return true
            }
        }

        //print("✅ DEBUG: Slot \(slot) is NOT blocked.")
        return false
    }
    
    private func isTimeSlotPending(_ slot: String) -> Bool {
        if let status = bookedTimeSlots[slot], status == "pending" {
            return true
        }

        // ✅ Check for 1-hour bookings: If this time is part of a longer session
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        if let startTime = formatter.date(from: slot) {
            let endTime = Calendar.current.date(byAdding: .minute, value: 30, to: startTime)!
            let nextSlot = formatter.string(from: endTime)

            if let status = bookedTimeSlots[nextSlot], status == "pending" {
                return true
            }
        }

        return false
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

        // ✅ Ensure selectedDate is fully set before proceeding
        await Task.sleep(200_000_000) // 200ms delay to allow UI update

        let dateKey = formattedDateKey(selectedDate)
        
        let availabilityRef = db.collection("tutors").document(tutorID).collection("availability").document(dateKey)
        let bookingsRef = db.collection("tutors").document(tutorID).collection("bookings")
        
        do {
            // ✅ Clear previous state before fetching new data
            DispatchQueue.main.async {
                self.availableTimeSlots.removeAll()
                self.confirmedTimeSlots.removeAll()
                self.pendingTimeSlots.removeAll()
                self.bookedTimeSlots.removeAll()
            }

            // ✅ Force Firestore to get fresh data (bypassing cache)
            let availabilityDoc = try await availabilityRef.getDocument(source: .server)
            let availabilityData = availabilityDoc.data()
            let fetchedAvailableSlots = availabilityData?["timeSlots"] as? [String] ?? []

            let bookingSnapshot = try await bookingsRef.whereField("date", isEqualTo: dateKey)
                .getDocuments(source: .server) // 🚀 Force fresh data
             
            var fetchedConfirmedSlots: [String] = []
            var fetchedPendingSlots: [String] = []

            for document in bookingSnapshot.documents {
                let data = document.data()
                let slot = data["timeSlot"] as? String ?? ""
                let status = data["status"] as? String ?? "pending"
                
                if status == "confirmed" {
                    fetchedConfirmedSlots.append(slot)
                } else if status == "pending" {
                    fetchedPendingSlots.append(slot)
                }
            }

            // ✅ Update UI on the main thread
            DispatchQueue.main.async {
                self.availableTimeSlots = fetchedAvailableSlots
                self.confirmedTimeSlots = fetchedConfirmedSlots
                self.pendingTimeSlots = fetchedPendingSlots
                
                // ✅ Populate bookedTimeSlots dictionary
                for slot in fetchedConfirmedSlots {
                    self.bookedTimeSlots[slot] = "confirmed"
                }
                for slot in fetchedPendingSlots {
                    self.bookedTimeSlots[slot] = "pending"
                }
            }

        } catch {
            print("🔥 Error fetching availability: \(error.localizedDescription)")
        }
    }
    
    //private var debugSlots: [String] {
      //  let logs = generateTimeSlots().map { slot in
        //    let status = """
          //  🛠 Slot: \(slot) |
          //  Confirmed: \(confirmedTimeSlots.contains(slot)) |
           // Pending: \(pendingTimeSlots.contains(slot)) |
           // Available: \(availableTimeSlots.contains(slot))
           // """
           // return status
       // }
        
        // ✅ Print **all slot statuses** at once (safe outside of body)
        //DispatchQueue.main.async {
          //  logs.forEach { print($0) }
       // }
        
        //return []
   // }

    

    
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
        
        if bookedTimeSlots.keys.contains(slot) {
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
    
    private func fetchSessionLengthPreference() {
        guard let tutorID = authManager.user?.id else { return }
        let docRef = db.collection("tutors").document(tutorID)

        docRef.getDocument { document, error in
            if let error = error {
                print("🔥 Error fetching session length preferences: \(error.localizedDescription)")
                return
            }
            if let data = document?.data(), let lengths = data["session_lengths"] as? [Int] {
                DispatchQueue.main.async {
                    self.allowedSessionLengths = Set(lengths)
                }
            }
        }
    }

    private func getTimeSlotView(_ slot: String) -> some View {
        HStack {
            Text(slot)
                .font(.headline)
                .foregroundColor(
                    bookedTimeSlots[slot] == "confirmed" ? .gray :
                    bookedTimeSlots[slot] == "pending" ? .blue :
                    selectedTimeSlots.contains(slot) ? .blue : .black
                )

            Spacer()

            if bookedTimeSlots[slot] == "confirmed" {
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray) // Lock icon for confirmed slots
            } else if bookedTimeSlots[slot] == "pending" {
                Button(action: { navigateToBookingConfirmationView(for: slot) }) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.blue) // Indicator for pending slots
                }
            } else if availableTimeSlots.contains(slot) {
                Button(action: { deleteSingleTimeSlot(slot) }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red) // Trash icon for deletable slots
                }
            }

            // ✅ Add checkmark if selected
            if selectedTimeSlots.contains(slot) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(
            bookedTimeSlots[slot] == "confirmed" ? Color.gray.opacity(0.4) :
            bookedTimeSlots[slot] == "pending" ? Color.blue.opacity(0.3) :
            availableTimeSlots.contains(slot) ? Color.green.opacity(0.2) :
            Color.white
        )
        .cornerRadius(8)
        .onTapGesture {
            if bookedTimeSlots[slot] != "confirmed" && bookedTimeSlots[slot] != "pending" {
                toggleTimeSlotSelection(slot)
            }
        }
    }

    
    private func isTimeSlotSelectable(_ slot: String) -> Bool {
        return bookedTimeSlots.keys.contains(slot) && !availableTimeSlots.contains(slot) && isTimeSlotAllowed(slot)
    }
    
    private func getTimeSlotColor(_ slot: String) -> Color {
        if bookedTimeSlots.keys.contains(slot)
        {
            return .gray
        } else if availableTimeSlots.contains(slot) {
            return .gray
        } else if !isTimeSlotAllowed(slot) {
            return .gray
        } else {
            return selectedTimeSlots.contains(slot) ? .blue : .black
        }
    }

    private func getTimeSlotBackground(_ slot: String) -> Color {
        if bookedTimeSlots.keys.contains(slot)
        {
            return Color.gray.opacity(0.2)
        } else if availableTimeSlots.contains(slot) {
            return Color.white
        } else {
            return Color.white
        }
    }
    
    private func isTimeSlotAllowed(_ slot: String) -> Bool {
        let allSlots = generateTimeSlots()
        guard let index = allSlots.firstIndex(of: slot) else {
            print("⛔ DEBUG: Slot \(slot) not found in generated slots.")
            return false
        }

        // ✅ Log whether the slot is being checked
        print("🔎 DEBUG: Checking if slot \(slot) is allowed.")

        // ✅ If the slot is directly booked, block it
        if let status = bookedTimeSlots[slot], status == "confirmed" {
            print("⛔ DEBUG: Slot \(slot) is CONFIRMED and cannot be selected.")
            return false
        }

        // ✅ If only 60-minute sessions are allowed, check rules
        if allowedSessionLengths.contains(60) && !allowedSessionLengths.contains(30) {
            if index % 2 != 0 {
                print("⛔ DEBUG: Slot \(slot) is blocked due to session length rules.")
                return false
            }
        }

        print("✅ DEBUG: Slot \(slot) is allowed.")
        return true
    }
    
    private func fetchTutorSessionLengths() {
        guard let tutorID = authManager.user?.id else { return }
        
        let tutorRef = db.collection("tutors").document(tutorID)
        
        tutorRef.getDocument { document, error in
            if let error = error {
                print("🔥 Error fetching session lengths: \(error.localizedDescription)")
                return
            }
            
            if let data = document?.data(), let sessionLengths = data["session_lengths"] as? [Int] {
                DispatchQueue.main.async {
                    self.tutorSessionLengths = sessionLengths
                    print("✅ Fetched Tutor Session Lengths: \(sessionLengths)")
                }
            }
        }
    }
    
    private func navigateToBookingConfirmationView(for timeSlot: String) {
        print("📌 Navigating to booking confirmation for \(timeSlot)")
        // TODO: Implement actual navigation logic when the booking confirmation screen is available.
    }

}
