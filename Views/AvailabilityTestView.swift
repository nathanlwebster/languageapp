import SwiftUI
import FirebaseFirestore

struct AvailabilityTestView: View {
    @State private var userID: String = "J6s60kEMV1WPaAGT8zTL7Ruiz3q1" // Example ID
    @State private var date: String = "20240312" // Format: YYYYMMDD
    @State private var availableSlots: [String] = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Fetch Tutor Availability")
                .font(.title2)
                .bold()

            TextField("Enter Tutor ID", text: $userID)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            TextField("Enter Date (YYYYMMDD)", text: $date)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            Button(action: {
                fetchAvailability(userID: userID, date: date) { slots in
                    DispatchQueue.main.async {
                        if let slots = slots {
                            availableSlots = slots
                            errorMessage = slots.isEmpty ? "No availability found." : nil
                        } else {
                            errorMessage = "Error fetching availability."
                        }
                    }
                }
            }) {
                Text("Fetch Availability")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.horizontal)

            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }

            if !availableSlots.isEmpty {
                VStack(alignment: .leading) {
                    Text("Available Slots:")
                        .font(.headline)
                    ForEach(availableSlots, id: \.self) { slot in
                        Text(slot)
                            .padding(.horizontal)
                    }
                }
                .padding()
            }

            Spacer()
        }
        .padding()
    }
    
    /// Fetches availability for a tutor on a specific date from Firestore.
    func fetchAvailability(userID: String, date: String, completion: @escaping ([String]?) -> Void) {
        let db = Firestore.firestore()
        
        // Reference to the availability document for the given date
        let availabilityRef = db.collection("tutors").document(userID).collection("availability").document(date)

        availabilityRef.getDocument { document, error in
            if let error = error {
                print("🔥 Error fetching availability: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let document = document, document.exists, let data = document.data() else {
                print("🚨 No availability document found for tutor: \(userID) on \(date)")
                completion([])
                return
            }

            // Extract available time slots
            if let slots = data["timeSlots"] as? [String] {
                print("✅ Availability for \(date): \(slots)")
                completion(slots)
            } else {
                print("⚠️ No available time slots found for \(date)")
                completion([])
            }
        }
    }


}

// Preview
#Preview {
    AvailabilityTestView()
}
