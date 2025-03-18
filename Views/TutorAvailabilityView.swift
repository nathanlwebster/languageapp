import SwiftUI
import FirebaseFirestore

struct TutorAvailabilityView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedDate = Date()
    @State private var availableTimeSlots: [String] = []
    @State private var errorMessage: String?

    private let db = Firestore.firestore()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Manage Availability").font(.title2).bold()
            
            Button(action: { /* Navigate back */ }) {
                Text("\u{2190} Back to Dashboard")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            DatePicker("Select a Date", selection: $selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .padding()
                .task(id: selectedDate) { // ✅ Runs every time `selectedDate` changes
                    await loadAvailability()
                }
            
            HStack {
                Button(action: deleteAllAvailabilityForDay) {
                    Text("Clear All for Day")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(availableTimeSlots.isEmpty)
                
                Button(action: copyWeekForward) {
                    Text("Copy to Next Week")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            
            List {
                ForEach(availableTimeSlots, id: \ .self) { slot in
                    HStack {
                        Text(slot)
                        Spacer()
                        Button(action: { deleteTimeSlot(slot: slot) }) {
                            Image(systemName: "trash").foregroundColor(.red)
                        }
                    }
                }
            }
            .task {
                await loadAvailability()
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage).foregroundColor(.red)
            }
        }
        .padding()
    }
    
    // ✅ Delete all availability for the selected date
    private func deleteAllAvailabilityForDay() {
        guard let tutorID = authManager.user?.id else { return }
        let dateKey = formattedDateKey(selectedDate)
        let docRef = db.collection("tutors").document(tutorID).collection("availability").document(dateKey)
        
        docRef.delete { error in
            if let error = error {
                errorMessage = "Error deleting availability: \(error.localizedDescription)"
            } else {
                availableTimeSlots.removeAll()
                print("✅ All availability deleted for \(dateKey)")
            }
        }
    }
    
    // ✅ Copy availability to the next week
    private func copyWeekForward() {
        guard let tutorID = authManager.user?.id else { return }
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
        
        for i in 0..<7 {
            let sourceDate = calendar.date(byAdding: .day, value: i, to: startOfWeek)!
            let targetDate = calendar.date(byAdding: .day, value: 7, to: sourceDate)!
            
            let sourceKey = formattedDateKey(sourceDate)
            let targetKey = formattedDateKey(targetDate)
            
            let sourceRef = db.collection("tutors").document(tutorID).collection("availability").document(sourceKey)
            let targetRef = db.collection("tutors").document(tutorID).collection("availability").document(targetKey)
            
            sourceRef.getDocument { document, error in
                if let data = document?.data(), !data.isEmpty {
                    targetRef.setData(data) { error in
                        if let error = error {
                            print("🔥 Error copying \(sourceKey) to \(targetKey): \(error.localizedDescription)")
                        } else {
                            print("✅ Copied availability from \(sourceKey) to \(targetKey)")
                        }
                    }
                }
            }
        }
    }
    
    // ✅ Load availability for the selected date
    // ✅ Load availability for the selected date (now async)
    private func loadAvailability() async {
        guard let tutorID = authManager.user?.id else { return }
        let dateKey = formattedDateKey(selectedDate)
        let docRef = db.collection("tutors").document(tutorID).collection("availability").document(dateKey)
        
        do {
            let document = try await docRef.getDocument()
            let data = document.data()
            let slots = data?["timeSlots"] as? [String] ?? []
            
            // ✅ Update UI on main thread
            DispatchQueue.main.async {
                self.availableTimeSlots = slots.sorted()
                print("🔄 Loaded availability for \(dateKey): \(self.availableTimeSlots)")
            }
        } catch {
            print("🔥 Error fetching availability for \(dateKey): \(error.localizedDescription)")
        }
    }
    
    // ✅ Delete a single time slot
    private func deleteTimeSlot(slot: String) {
        guard let tutorID = authManager.user?.id else { return }
        let dateKey = formattedDateKey(selectedDate)
        let docRef = db.collection("tutors").document(tutorID).collection("availability").document(dateKey)
        
        docRef.updateData(["timeSlots": FieldValue.arrayRemove([slot])]) { error in
            if let error = error {
                errorMessage = "Error deleting slot: \(error.localizedDescription)"
            } else {
                availableTimeSlots.removeAll { $0 == slot }
                print("✅ Deleted time slot: \(slot)")
            }
        }
    }
    
    // ✅ Format date to Firestore key format (YYYYMMDD)
    private func formattedDateKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}

