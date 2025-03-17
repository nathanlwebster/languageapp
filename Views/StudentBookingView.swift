import SwiftUI

struct StudentBookingView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var availableTutors: [UserModel] = []
    @State private var selectedTutor: UserModel?
    @State private var availableDates: [String] = []
    @State private var selectedDate: String?
    @State private var availableTimeSlots: [String] = []
    @State private var selectedTimeSlot: String?
    @State private var errorMessage: String?
    @State private var navigateBackToDashboard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Book a Lesson")
                    .font(.title2)
                    .bold()
                
                Button(action: { navigateBackToDashboard = true }) {
                    Text("← Back to Dashboard")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .fullScreenCover(isPresented: $navigateBackToDashboard) {
                    DashboardView().environmentObject(authManager)
                }
                
                if availableTutors.isEmpty {
                    ProgressView("Loading tutors...")
                } else {
                    // ✅ Tutor Selection
                    Text("Select a Tutor:")
                        .font(.headline)
                    
                    ForEach(availableTutors, id: \.id) { tutor in
                        Button(action: {
                            selectedTutor = tutor
                            selectedDate = nil
                            availableDates = []
                            availableTimeSlots = []
                            selectedTimeSlot = nil
                        }) {
                            HStack {
                                Text(tutor.name)
                                    .padding()
                                Spacer()
                                if selectedTutor?.id == tutor.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }

                    // ✅ Date Selection (List instead of Picker)
                    if !availableDates.isEmpty {
                        Text("Select a Date:")
                            .font(.headline)
                        
                        ForEach(availableDates, id: \.self) { date in
                            Button(action: {
                                selectedDate = date
                                availableTimeSlots = []
                                selectedTimeSlot = nil
                            }) {
                                HStack {
                                    Text(date)
                                        .padding()
                                    Spacer()
                                    if selectedDate == date {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                    }

                    // ✅ Time Slot Selection (List instead of Picker)
                    if !availableTimeSlots.isEmpty {
                        Text("Select a Time Slot:")
                            .font(.headline)
                        
                        ForEach(availableTimeSlots, id: \.self) { slot in
                            Button(action: {
                                selectedTimeSlot = slot
                            }) {
                                HStack {
                                    Text(slot)
                                        .padding()
                                    Spacer()
                                    if selectedTimeSlot == slot {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            }
                        }
                    }

                    // ✅ Book Lesson Button
                    Button(action: bookLesson) {
                        Text("Book Lesson")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(selectedTutor == nil || selectedDate == nil || selectedTimeSlot == nil)
                    .padding()
                }

                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
                
                Spacer()
            }
            .padding()
        }
        .task {
            await loadAvailableTutors()
        }
        .task(id: selectedTutor?.id) {
            if let tutor = selectedTutor {
                await fetchAvailableDates(for: tutor)
            } else {
                availableDates = []
                selectedDate = nil
                availableTimeSlots = []
                selectedTimeSlot = nil
            }
        }
        .task(id: selectedDate) {
            if let tutor = selectedTutor, let date = selectedDate {
                await fetchAvailableTimeSlots(for: tutor, date: date)
            } else {
                availableTimeSlots = []
                selectedTimeSlot = nil
            }
        }
    }

    // ✅ Load available tutors
    func loadAvailableTutors() async {
        guard let studentID = authManager.user?.id else {
            DispatchQueue.main.async {
                errorMessage = "Error: No user logged in."
            }
            return
        }

        do {
            let tutors = try await FirestoreManager.shared.fetchAvailableTutors()
            
            print("🟢 Loaded Tutors from Firestore:")
            for tutor in tutors {
                print("➡️ Tutor ID: \(tutor.id), Name: \(tutor.name)")
            }

            // ✅ Check availability for all tutors concurrently
            let availableTutorsWithSlots = await withTaskGroup(of: (UserModel, Bool).self) { group -> [UserModel] in
                for tutor in tutors {
                    group.addTask {
                        let isAvailable = await hasAvailability(tutorID: tutor.id)
                        return (tutor, isAvailable)
                    }
                }

                var tutorsWithAvailability: [UserModel] = []
                for await (tutor, isAvailable) in group {
                    if isAvailable {
                        tutorsWithAvailability.append(tutor)
                    }
                }
                return tutorsWithAvailability
            }

            DispatchQueue.main.async {
                print("✅ Tutors with Availability:")
                for tutor in availableTutorsWithSlots {
                    print("✔️ Tutor ID: \(tutor.id), Name: \(tutor.name)")
                }
                availableTutors = availableTutorsWithSlots
            }
        } catch {
            DispatchQueue.main.async {
                errorMessage = "🔥 Error loading tutors: \(error.localizedDescription)"
            }
        }
    }

    // ✅ Fetch available dates for the selected tutor
    func fetchAvailableDates(for tutor: UserModel) async {
        do {
            print("📡 Fetching available dates for Tutor ID: \(tutor.id), Name: \(tutor.name)")
            let dates = try await FirestoreManager.shared.fetchAvailableDates(tutorID: tutor.id)
            DispatchQueue.main.async {
                print("✅ Available Dates for \(tutor.name): \(dates)")
                availableDates = dates
                selectedDate = nil
            }
        } catch {
            DispatchQueue.main.async {
                errorMessage = "🔥 Error loading dates: \(error.localizedDescription)"
            }
        }
    }

    // ✅ Fetch available time slots for the selected date
    func fetchAvailableTimeSlots(for tutor: UserModel, date: String) async {
        do {
            print("📡 Fetching available time slots for Tutor ID: \(tutor.id), Name: \(tutor.name) on \(date)")
            let slots = try await FirestoreManager.shared.fetchAvailableTimeSlots(tutorID: tutor.id, date: date)
            DispatchQueue.main.async {
                print("✅ Available Time Slots for \(tutor.name) on \(date): \(slots)")
                availableTimeSlots = slots
                selectedTimeSlot = nil
            }
        } catch {
            DispatchQueue.main.async {
                errorMessage = "🔥 Error loading time slots: \(error.localizedDescription)"
            }
        }
    }
    
    func hasAvailability(tutorID: String) async -> Bool {
        do {
            let dates = try await FirestoreManager.shared.fetchAvailableDates(tutorID: tutorID)
            return !dates.isEmpty
        } catch {
            print("🔥 Error checking availability for \(tutorID): \(error.localizedDescription)")
            return false
        }
    }

    // ✅ Book a lesson
    func bookLesson() {
        guard let tutor = selectedTutor, let student = authManager.user,
              let date = selectedDate, let timeSlot = selectedTimeSlot else { return }

        FirestoreManager.shared.bookSession(
            tutorID: tutor.id,
            studentID: student.id,
            studentName: student.name,
            date: date,
            timeSlot: timeSlot
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    errorMessage = "✅ Lesson booked successfully!"
                } else {
                    errorMessage = error ?? "🔥 Booking failed."
                }
            }
        }
    }
}
