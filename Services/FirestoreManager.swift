import FirebaseFirestore

class FirestoreManager {
    static let shared = FirestoreManager()
    private let db = Firestore.firestore()

    // ✅ Fetch user profile from Firestore
    func getUserProfile(userID: String, completion: @escaping (UserModel?) -> Void) {
        let docRef = db.collection("users").document(userID)

        docRef.getDocument { (document, error) in
            if let error = error {
                print("🔥 Firestore Error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let document = document, document.exists else {
                print("⚠️ Firestore: No user document found for userID \(userID)")
                completion(nil)
                return
            }

            let data = document.data()
            print("✅ Firestore Data: \(String(describing: data))")

            let user = UserModel(
                id: userID,
                name: data?["name"] as? String ?? "Unknown",
                isTutor: data?["isTutor"] as? Bool ?? false,
                languages: data?["languages"] as? [String] ?? [],
                bio: data?["bio"] as? String ?? "",
                profileImageURL: data?["profileImageURL"] as? String
            )
            completion(user)
        }
    }

    // ✅ Save or update user profile in Firestore
    func saveUserProfile(user: UserModel, completion: @escaping (Error?) -> Void) {
        let userData: [String: Any] = [
            "id": user.id,
            "name": user.name,
            "isTutor": user.isTutor,
            "languages": user.languages,
            "bio": user.bio,
            "profileImageURL": user.profileImageURL ?? ""
        ]

        db.collection("users").document(user.id).setData(userData, merge: true) { error in
            if let error = error {
                print("🔥 Error saving user profile: \(error.localizedDescription)")
            } else {
                print("✅ User profile saved successfully!")
            }
            completion(error)
        }
    }

    // ✅ Fetch available tutors, excluding the student themselves
    func fetchAvailableTutors() async throws -> [UserModel] {
        let snapshot = try await db.collection("users").whereField("isTutor", isEqualTo: true).getDocuments()

        let tutors = snapshot.documents.compactMap { doc in
            let data = doc.data()
            let tutorID = doc.documentID // ✅ Ensure we fetch tutors by ID
            let tutorName = data["name"] as? String ?? "Unknown"

            print("📌 Firestore Tutor Loaded - ID: \(tutorID), Name: \(tutorName)") // ✅ Debug log

            return UserModel(
                id: tutorID,
                name: tutorName,
                isTutor: true,
                languages: data["languages"] as? [String] ?? [],
                bio: data["bio"] as? String ?? "",
                profileImageURL: data["profileImageURL"] as? String
            )
        }
        
        return tutors
    }

    // ✅ Fetch available dates for a tutor
    func fetchAvailableDates(tutorID: String) async throws -> [String] {
        let snapshot = try await db.collection("tutors").document(tutorID).collection("availability").getDocuments()
        
        return snapshot.documents.map { $0.documentID } // ✅ Fetch available dates **by tutorID** only
    }

    // ✅ Fetch available time slots for a tutor on a specific date
    func fetchAvailableTimeSlots(tutorID: String, date: String, sessionLengths: [Int], completion: @escaping ([String]?, Error?) -> Void) {
        let docRef = db.collection("tutors").document(tutorID).collection("availability").document(date)

        docRef.getDocument { document, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let data = document?.data(), let timeSlots = data["timeSlots"] as? [String] else {
                completion([], nil)
                return
            }

            // Filter time slots based on allowed session length
            let filteredSlots = timeSlots.filter { slot in
                if sessionLengths.contains(60) && !sessionLengths.contains(30) {
                    return slot.hasSuffix(":00") // Only allow on-the-hour times
                }
                return true // If both lengths are allowed, return all
            }

            completion(filteredSlots, nil)
        }
    }
    
    // ✅ Book a tutor session
    func bookSession(
        tutorID: String,
        studentID: String,
        studentName: String,
        date: String,
        timeSlot: String,
        sessionLength: Int,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let tutorUserRef = db.collection("users").document(tutorID)

        tutorUserRef.getDocument { document, error in
            if let error = error {
                completion(false, "Error fetching tutor name")
                return
            }

            guard let document = document, document.exists,
                  let tutorData = document.data(),
                  let tutorName = tutorData["name"] as? String else {
                completion(false, "Tutor name not found")
                return
            }

            // ✅ Calculate correct end time
            let endTime = self.calculateEndTime(startTime: timeSlot, sessionLength: sessionLength)

            let bookingData: [String: Any] = [
                "studentID": studentID,
                "studentName": studentName,
                "tutorID": tutorID,
                "tutorName": tutorName,
                "date": date,
                "timeSlot": timeSlot,
                "sessionLength": sessionLength,
                "endTime": endTime, // ✅ Store correct end time
                "status": "pending"
            ]

            let bookingRef = self.db.collection("tutors").document(tutorID).collection("bookings").document()
            bookingRef.setData(bookingData) { error in
                completion(error == nil, error?.localizedDescription)
            }
        }
    }
    
    // ✅ Fetch all bookings for a tutor
    func fetchBookings(forTutor tutorID: String, tutorName: String, completion: @escaping ([String: String]) -> Void) {
        print("📡 Fetching bookings for tutor: \(tutorID)")

        let bookingsRef = db.collection("tutors").document(tutorID).collection("bookings")

        bookingsRef.getDocuments { snapshot, error in
            if let error = error {
                print("🔥 Error fetching bookings: \(error.localizedDescription)")
                completion([:])
                return
            }

            var bookedSlots: [String: String] = [:] // Dictionary of [TimeSlot: Status]

            for doc in snapshot?.documents ?? [] {
                let data = doc.data()
                let startTime = data["timeSlot"] as? String ?? ""
                let endTime = data["endTime"] as? String ?? ""
                let status = data["status"] as? String ?? "pending"

                print("📅 Processing Booking: \(startTime) - \(endTime) | Status: \(status)")

                // ✅ Store the correct status for the starting slot
                bookedSlots[startTime] = status

                // ✅ Ensure next slot is blocked correctly based on session length
                if let sessionLength = data["sessionLength"] as? Int {
                    let nextSlot = sessionLength == 60 ? self.getNextHourSlot(from: startTime) : self.getNextHalfHourSlot(from: startTime)

                    if let nextSlot = nextSlot {
                        if bookedSlots[nextSlot] == nil || bookedSlots[nextSlot] == "pending" {
                            bookedSlots[nextSlot] = status
                            print("🔒 Correctly Blocking Next Slot: \(nextSlot) also as \(status)")
                        }
                    }
                }
            }

            print("✅ Final Booked Slots: \(bookedSlots)") // ✅ Debugging output
            completion(bookedSlots)
        }
    }



    private func getNextHourSlot(from time: String) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a" // ✅ Ensures consistent AM/PM format

        guard let date = formatter.date(from: time) else { return nil }

        let nextHourDate = Calendar.current.date(byAdding: .minute, value: 60, to: date)!
        return formatter.string(from: nextHourDate) // ✅ Returns correct next time slot
    }
    
    private func getNextHalfHourSlot(from time: String) -> String? {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a" // Ensure correct format

        guard let date = formatter.date(from: time) else { return nil }
        let nextSlot = Calendar.current.date(byAdding: .minute, value: 30, to: date)!

        return formatter.string(from: nextSlot)
    }

    // ✅ Fetch all pending bookings for a tutor
    func fetchPendingBookings(forTutor tutorID: String, tutorName: String, completion: @escaping ([Booking]?, Error?) -> Void) {
        print("📡 Querying Firestore for pending bookings for tutor: \(tutorID)")

        db.collection("tutors").document(tutorID).collection("bookings")
            .whereField("status", isEqualTo: "pending")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("🔥 Error fetching pending bookings: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No pending bookings found for tutor: \(tutorID)")
                    completion([], nil)
                    return
                }

                let bookings = documents.compactMap { doc -> Booking? in
                    let data = doc.data()
                    print("📄 Booking Data:", data) // ✅ Print out each document retrieved
                    return Booking(
                        id: doc.documentID,
                        studentID: data["studentID"] as? String ?? "",
                        studentName: data["studentName"] as? String ?? "Unknown",
                        tutorID: tutorID, // ✅ Ensure tutorID is passed correctly
                        tutorName: tutorName, // ✅ Include tutorName
                        date: data["date"] as? String ?? "",
                        timeSlot: data["timeSlot"] as? String ?? "",
                        status: data["status"] as? String ?? "pending"
                    )
                }

                print("✅ Found \(bookings.count) pending bookings for tutor \(tutorID)")
                completion(bookings, nil)
            }
        }

    func getBookingStatus(tutorID: String, bookingID: String, completion: @escaping (String?) -> Void) {
        let db = Firestore.firestore()
        let bookingRef = db.collection("tutors").document(tutorID).collection("bookings").document(bookingID)
        
        bookingRef.getDocument { document, error in
            if let error = error {
                print("🔥 Error fetching booking status: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let document = document, document.exists, let data = document.data(),
                  let status = data["status"] as? String else {
                print("⚠️ Booking document not found or missing status")
                completion(nil)
                return
            }
            
            print("📄 Booking \(bookingID) current status: \(status)")
            completion(status)
        }
    }

    
    // ✅ Confirm or reject a booking
    // ✅ Confirm or reject a booking (now also restores availability if canceled)
    func updateBookingStatus(tutorID: String, bookingID: String, newStatus: String, completion: @escaping (Bool, Error?) -> Void) {
        let db = Firestore.firestore()
        let bookingRef = db.collection("tutors").document(tutorID).collection("bookings").document(bookingID)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let bookingDoc: DocumentSnapshot
            do {
                try bookingDoc = transaction.getDocument(bookingRef)
            } catch {
                errorPointer?.pointee = NSError(domain: "FirestoreError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch booking"])
                return nil
            }

            guard let currentData = bookingDoc.data(),
                  let currentStatus = currentData["status"] as? String,
                  let studentID = currentData["studentID"] as? String else { // ✅ Extract studentID safely
                errorPointer?.pointee = NSError(domain: "FirestoreError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid booking data"])
                return nil
            }

            // ✅ Prevent multiple updates by checking if status has changed
            if currentStatus == newStatus {
                print("⚠️ Booking \(bookingID) is already \(newStatus), skipping update.")
                return nil
            }

            // ✅ If canceling, restore the time slot to tutor's availability
            if newStatus == "canceled" {
                if let date = currentData["date"] as? String, let timeSlot = currentData["timeSlot"] as? String {
                    let availabilityRef = db.collection("tutors").document(tutorID).collection("availability").document(date)
                    transaction.updateData(["timeSlots": FieldValue.arrayUnion([timeSlot])], forDocument: availabilityRef)
                    print("✅ Restored \(timeSlot) on \(date) to tutor \(tutorID)'s availability")
                }
            } else if newStatus == "completed" {
                print("✅ Marking lesson \(bookingID) as completed.")
            }

            // ✅ Update booking status inside transaction
            print("🟢 Updating Booking \(bookingID) from \(currentStatus) → \(newStatus)")
            transaction.updateData(["status": newStatus], forDocument: bookingRef)

            return nil
        }) { success, error in
            if let error = error {
                print("🔥 Transaction failed: \(error.localizedDescription)")
                completion(false, error)
            } else {
                print("✅ Booking \(bookingID) successfully updated to \(newStatus)")
                completion(true, nil)
            }
        }
    }

    
    // ✅ Fetch upcoming lessons for a student
    func fetchUpcomingLessons(forStudent studentID: String, completion: @escaping ([Booking]?, [Booking]?, Error?) -> Void) {
        let db = Firestore.firestore()

        print("📡 Querying Firestore for upcoming & canceled lessons for student: \(studentID)")

        db.collectionGroup("bookings") // ✅ Search across all tutors' bookings
            .whereField("studentID", isEqualTo: studentID)
            .order(by: "date", descending: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("🔥 Error fetching lessons: \(error.localizedDescription)")
                    completion(nil, nil, error)
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No lessons found for student: \(studentID)")
                    completion([], [], nil)
                    return
                }

                var upcomingLessons: [Booking] = []
                var canceledLessons: [Booking] = []

                for doc in documents {
                    let data = doc.data()
                    let lesson = Booking(
                        id: doc.documentID,
                        studentID: data["studentID"] as? String ?? "",
                        studentName: data["studentName"] as? String ?? "Unknown",
                        tutorID: data["tutorID"] as? String ?? "",
                        tutorName: data["tutorName"] as? String ?? "Unknown",
                        date: data["date"] as? String ?? "",
                        timeSlot: data["timeSlot"] as? String ?? "",
                        status: data["status"] as? String ?? "confirmed"
                    )

                    // ✅ Sort lessons into upcoming or canceled
                    if lesson.status == "canceled" {
                        canceledLessons.append(lesson)
                    } else {
                        upcomingLessons.append(lesson)
                    }
                }

                print("✅ Found \(upcomingLessons.count) upcoming lessons & \(canceledLessons.count) canceled lessons for student \(studentID)")
                completion(upcomingLessons, canceledLessons, nil)
            }
    }


    func cancelLesson(studentID: String, tutorID: String, lessonID: String, completion: @escaping (Bool, String?) -> Void) {
        let db = Firestore.firestore()
        let lessonRef = db.collection("tutors").document(tutorID).collection("bookings").document(lessonID)

        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let lessonDoc: DocumentSnapshot
            do {
                try lessonDoc = transaction.getDocument(lessonRef)
            } catch {
                errorPointer?.pointee = NSError(domain: "FirestoreError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch lesson"])
                return nil
            }

            guard let lessonData = lessonDoc.data(),
                  let currentStatus = lessonData["status"] as? String else {
                errorPointer?.pointee = NSError(domain: "FirestoreError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid lesson data"])
                return nil
            }

            // ✅ Prevent cancellation of already canceled lessons
            if currentStatus == "canceled" {
                print("⚠️ Lesson \(lessonID) is already canceled.")
                return nil
            }

            // ✅ Mark the lesson as canceled
            print("🟢 Cancelling Lesson \(lessonID) for Student \(studentID)")
            transaction.updateData(["status": "canceled"], forDocument: lessonRef)

            return nil
        }) { success, error in
            if let error = error {
                print("🔥 Transaction failed: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                print("✅ Lesson \(lessonID) successfully canceled for Student \(studentID)")
                completion(true, nil)
            }
        }
    }
    
    func fetchTutorLessons(forTutor tutorID: String, completion: @escaping ([Booking]?, [Booking]?, Error?) -> Void) {
        let db = Firestore.firestore()
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let todayString = formatter.string(from: today)

        print("📡 Querying Firestore for scheduled & completed lessons for tutor: \(tutorID)")

        db.collection("tutors").document(tutorID).collection("bookings")
            .order(by: "date", descending: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("🔥 Error fetching lessons: \(error.localizedDescription)")
                    completion(nil, nil, error)
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No lessons found for tutor: \(tutorID)")
                    completion([], [], nil)
                    return
                }

                var scheduledLessons: [Booking] = []
                var completedLessons: [Booking] = []

                for doc in documents {
                    let data = doc.data()
                    let lesson = Booking(
                        id: doc.documentID,
                        studentID: data["studentID"] as? String ?? "",
                        studentName: data["studentName"] as? String ?? "Unknown",
                        tutorID: tutorID,
                        tutorName: data["tutorName"] as? String ?? "Unknown",
                        date: data["date"] as? String ?? "",
                        timeSlot: data["timeSlot"] as? String ?? "",
                        status: data["status"] as? String ?? "confirmed"
                    )

                    // ✅ Sort lessons into scheduled or completed
                    if lesson.status == "completed" {
                        completedLessons.append(lesson)
                    } else if lesson.status == "confirmed" && lesson.date >= todayString {
                        scheduledLessons.append(lesson)
                    }
                }

                print("✅ Found \(scheduledLessons.count) scheduled lessons & \(completedLessons.count) completed lessons for tutor \(tutorID)")
                completion(scheduledLessons, completedLessons, nil)
            }
    }
    
    func fetchTutorBookings(forTutor tutorID: String, completion: @escaping ([Booking]?, [Booking]?, Error?) -> Void) {
        print("📡 Querying Firestore for tutor bookings...")

        db.collection("tutors").document(tutorID).collection("bookings")
            .order(by: "date", descending: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("🔥 Error fetching tutor bookings: \(error.localizedDescription)")
                    completion(nil, nil, error)
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("⚠️ No bookings found for tutor: \(tutorID)")
                    completion([], [], nil)
                    return
                }

                var pendingBookings: [Booking] = []
                var confirmedBookings: [Booking] = []

                for doc in documents {
                    let data = doc.data()
                    let booking = Booking(
                        id: doc.documentID,
                        studentID: data["studentID"] as? String ?? "",
                        studentName: data["studentName"] as? String ?? "Unknown",
                        tutorID: tutorID,
                        tutorName: data["tutorName"] as? String ?? "Unknown",
                        date: data["date"] as? String ?? "",
                        timeSlot: data["timeSlot"] as? String ?? "",
                        status: data["status"] as? String ?? "pending"
                    )

                    if booking.status == "pending" {
                        pendingBookings.append(booking)
                    } else if booking.status == "confirmed" {
                        confirmedBookings.append(booking)
                    }
                }

                print("✅ Found \(pendingBookings.count) pending bookings and \(confirmedBookings.count) confirmed bookings.")
                completion(pendingBookings, confirmedBookings, nil)
            }
    }
    
    func updateExistingBookingsWithEndTime(forTutor tutorID: String) {

        let bookingsRef = db.collection("tutors").document(tutorID).collection("bookings")

        bookingsRef.getDocuments { snapshot, error in
            if let error = error {
                print("🔥 Error fetching bookings: \(error.localizedDescription)")
                return
            }

            for document in snapshot?.documents ?? [] {
                let data = document.data()
                guard let startTime = data["timeSlot"] as? String else { continue }
                let sessionLength = data["sessionLength"] as? Int ?? 30 // Default to 30 min if missing
                
                let endTime = self.calculateEndTime(startTime: startTime, sessionLength: sessionLength)

                // Update Firestore document with calculated endTime
                bookingsRef.document(document.documentID).updateData(["endTime": endTime]) { error in
                    if let error = error {
                        print("🔥 Error updating booking \(document.documentID): \(error.localizedDescription)")
                    } else {
                        print("✅ Booking \(document.documentID) updated with endTime: \(endTime)")
                    }
                }
            }
        }
    }

    // ✅ Add a vocabulary word
    func addVocabularyWord(userID: String, word: String, translation: String, exampleSentence: String, difficultyLevel: String, completion: @escaping (Error?) -> Void) {
        let wordID = word.lowercased()
        let vocabRef = db.collection("users").document(userID).collection("vocabulary").document(wordID)

        let vocabData: [String: Any] = [
            "word": word,
            "translation": translation,
            "exampleSentence": exampleSentence,
            "difficultyLevel": difficultyLevel,
            "timestamp": Timestamp()
        ]

        vocabRef.setData(vocabData) { error in
            if let error = error {
                print("🔥 Error adding vocabulary: \(error.localizedDescription)")
            } else {
                print("✅ Vocabulary word added successfully!")
            }
            completion(error)
        }
    }

    // ✅ Fetch all vocabulary words
    func getVocabulary(userID: String, completion: @escaping ([VocabularyModel]?, Error?) -> Void) {
        let vocabRef = db.collection("users").document(userID).collection("vocabulary")

        vocabRef.order(by: "timestamp", descending: true).getDocuments { snapshot, error in
            if let error = error {
                print("🔥 Error retrieving vocabulary: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            let words = snapshot?.documents.compactMap { document -> VocabularyModel? in
                let data = document.data()
                return VocabularyModel(
                    word: data["word"] as? String ?? "",
                    translation: data["translation"] as? String ?? "",
                    exampleSentence: data["exampleSentence"] as? String ?? "",
                    difficultyLevel: data["difficultyLevel"] as? String ?? "unknown"
                )
            }
            completion(words, nil)
        }
    }
    
    private func calculateEndTime(startTime: String, sessionLength: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a" // ✅ Updated to remove leading zero

        // 🛠 Debug: Print the inputs received
        print("📌 Calculating End Time...")
        print("⏳ Received Start Time: \(startTime)")
        print("🕒 Received Session Length: \(sessionLength) minutes")

        guard let startDate = formatter.date(from: startTime) else {
            print("🔥 Error: Could not parse startTime: \(startTime)")
            return startTime
        }

        // ✅ Add session length to get end time
        let endDate = Calendar.current.date(byAdding: .minute, value: sessionLength, to: startDate)!

        let formattedEndTime = formatter.string(from: endDate)

        // 🛠 Debug: Print the calculated end time
        print("✅ Calculated End Time: \(formattedEndTime)")

        return formattedEndTime
    }

}
