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
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                Spacer()
                Text("Manage Availability")
                    .font(.headline)
                Spacer()
            }
            .padding()
            
            // 🔹 Date Picker
            DatePicker("Select a Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
                .padding()
                .onChange(of: selectedDate) { _ in
                    fetchAvailabilityAndBookings()
                }
            
            // 🔹 Time Slot List
            ScrollView {
                ForEach(generateAllTimeSlots(), id: \..self) { slot in
                    HStack {
                        Text(slot)
                            .fontWeight(.medium)
                            .foregroundColor(bookedTimeSlots[slot] == "confirmed" ? .gray : .black)
                        Spacer()
                        if availableTimeSlots.contains(slot) {
                            Button(action: { removeAvailability(slot) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        } else if pendingTimeSlots.contains(slot) {
                            Image(systemName: "exclamationmark.circle")
                                .foregroundColor(.blue)
                        } else if confirmedTimeSlots.contains(slot) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                        } else {
                            Button(action: { addAvailability(slot) }) {
                                Text("Add")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(availableTimeSlots.contains(slot) ? Color.green.opacity(0.3) : Color.clear)
                    .cornerRadius(10)
                }
            }
            
            // 🔹 Buttons
            HStack {
                Button("Add Availability", action: addSelectedAvailability)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(selectedTimeSlots.isEmpty)
                
                Button("Clear Availability", action: clearAvailability)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .onAppear {
            fetchAvailabilityAndBookings()
        }
    }
    
    // 🔹 Add Selected Availability
    func addSelectedAvailability() {
        guard let userID = authManager.userID else {
            errorMessage = "User ID not found"
            return
        }

        let dateStr = DateFormatter.localizedString(from: selectedDate, dateStyle: .medium, timeStyle: .none)

        for timeSlot in selectedTimeSlots {
            FirestoreManager().addAvailability(tutorID: userID, date: dateStr, timeSlot: timeSlot) {
                DispatchQueue.main.async {
                    self.availableTimeSlots.append(timeSlot)
                }
            }
        }
        selectedTimeSlots.removeAll()
    }
    
    // 🔹 Fetch Data
    func fetchAvailabilityAndBookings() {
        guard let userID = authManager.userID else {
            errorMessage = "User ID not found"
            return
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let dateStr = formatter.string(from: selectedDate)

        FirestoreManager().fetchAvailabilityAndBookings(tutorID: userID, date: dateStr) { available, pending, confirmed, error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                return
            }
            DispatchQueue.main.async {
                self.availableTimeSlots = available
                self.pendingTimeSlots = pending
                self.confirmedTimeSlots = confirmed
            }
        }
    }

    
    // 🔹 Add Availability
    func addAvailability(_ timeSlot: String) {
        guard let userID = authManager.userID else {
            errorMessage = "User ID not found"
            return
        }
        
        let dateStr = DateFormatter.localizedString(from: selectedDate, dateStyle: .medium, timeStyle: .none)
        
        FirestoreManager().addAvailability(tutorID: userID, date: dateStr, timeSlot: timeSlot) {
            DispatchQueue.main.async {
                self.availableTimeSlots.append(timeSlot)
            }
        }
    }

    
    // 🔹 Remove Availability
    func removeAvailability(_ timeSlot: String) {
        guard let userID = authManager.userID else {
            errorMessage = "User ID not found"
            return
        }
        
        let dateStr = DateFormatter.localizedString(from: selectedDate, dateStyle: .medium, timeStyle: .none)
        
        FirestoreManager().removeAvailability(tutorID: userID, date: dateStr, timeSlot: timeSlot) {
            DispatchQueue.main.async {
                self.availableTimeSlots.removeAll { $0 == timeSlot }
            }
        }
    }
    
    // 🔹 Clear Availability
    func clearAvailability() {
        self.availableTimeSlots.removeAll()
    }
    
    // 🔹 Generate Time Slots
    func generateAllTimeSlots() -> [String] {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var slots: [String] = []
        var currentTime = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: Date())!
        for _ in 0..<48 {
            slots.append(formatter.string(from: currentTime))
            currentTime = Calendar.current.date(byAdding: .minute, value: 30, to: currentTime)!
        }
        return slots
    }
    
    // 🔹 Navigate Back
    func navigateBack() {
        presentationMode.wrappedValue.dismiss()
    }
}
