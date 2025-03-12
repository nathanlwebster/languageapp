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
    func fetchAvailableTutors(excludeUserID: String) async throws -> [UserModel] {
        let db = Firestore.firestore()
        let snapshot = try await db.collection("users").whereField("isTutor", isEqualTo: true).getDocuments()

        let tutors = snapshot.documents.compactMap { doc -> UserModel? in
            let data = doc.data()
            let id = doc.documentID

            if id == excludeUserID { return nil } // Exclude student themselves

            return UserModel(
                id: id,
                name: data["name"] as? String ?? "Unknown",
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
        let db = Firestore.firestore()
        let snapshot = try await db.collection("tutors").document(tutorID).collection("availability").getDocuments()

        return snapshot.documents.map { $0.documentID } // Return available dates
    }

    // ✅ Fetch available time slots for a tutor on a specific date
    func fetchAvailableTimeSlots(tutorID: String, date: String) async throws -> [String] {
        let db = Firestore.firestore()
        let docRef = db.collection("tutors").document(tutorID).collection("availability").document(date)

        let document = try await docRef.getDocument()
        
        guard let data = document.data(), let timeSlots = data["timeSlots"] as? [String] else {
            return []
        }
        return timeSlots
    }
    
    // ✅ Book a tutor session
    func bookSession(
        tutorID: String,
        studentID: String,
        studentName: String,
        date: String,
        timeSlot: String,
        completion: @escaping (Bool, String?) -> Void
    ) {
        let tutorUserRef = db.collection("users").document(tutorID) // ✅ Correct location for tutor name
        let tutorRef = db.collection("tutors").document(tutorID)
        let bookingRef = tutorRef.collection("bookings").document()
        let availabilityRef = tutorRef.collection("availability").document(date)

        print("🟢 Booking Session for Student \(studentID) with Tutor \(tutorID) on \(date) at \(timeSlot)")

        // 🔍 Fetch Tutor Name from `users/{tutorID}` Before Storing Booking
        tutorUserRef.getDocument { document, error in
            if let error = error {
                print("🔥 Firestore error fetching tutor name: \(error.localizedDescription)")
            }
            
            guard let document = document, document.exists, let tutorData = document.data(),
                  let tutorName = tutorData["name"] as? String else {
                print("⚠️ Failed to retrieve tutor name from users/{tutorID}, storing as 'Unknown'")
                return
            }

            print("✅ Retrieved tutor name: \(tutorName) for tutorID: \(tutorID)")

            self.db.runTransaction({ (transaction, errorPointer) -> Any? in
                let availabilityDoc: DocumentSnapshot
                do {
                    try availabilityDoc = transaction.getDocument(availabilityRef)
                } catch {
                    errorPointer?.pointee = NSError(domain: "FirestoreError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch availability"])
                    return nil
                }

                guard var timeSlots = availabilityDoc.data()?["timeSlots"] as? [String], timeSlots.contains(timeSlot) else {
                    errorPointer?.pointee = NSError(domain: "FirestoreError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Time slot not available"])
                    return nil
                }

                // Remove the booked slot
                timeSlots.removeAll { $0 == timeSlot }
                transaction.updateData(["timeSlots": timeSlots], forDocument: availabilityRef)

                // ✅ Store booking with tutorName included
                let bookingData: [String: Any] = [
                    "studentID": studentID,
                    "studentName": studentName,
                    "tutorID": tutorID,
                    "tutorName": tutorName, // ✅ Now fetched from `users/{tutorID}`
                    "date": date,
                    "timeSlot": timeSlot,
                    "status": "pending"
                ]

                transaction.setData(bookingData, forDocument: bookingRef)

                print("✅ Booking saved under Tutor \(tutorID) with Tutor Name: \(tutorName)")
                return nil
            }) { (success, error) in
                if let error = error {
                    print("🔥 Booking failed: \(error.localizedDescription)")
                    completion(false, error.localizedDescription)
                } else {
                    print("✅ Booking successful for Tutor \(tutorID)")
                    completion(true, nil)
                }
            }
        }
    }
    
    // ✅ Fetch all bookings for a tutor
    func fetchBookings(forTutor tutorID: String, tutorName: String, completion: @escaping ([Booking]?, Error?) -> Void) {
        let bookingsRef = db.collection("tutors").document(tutorID).collection("bookings")

        bookingsRef.getDocuments { snapshot, error in
            if let error = error {
                print("🔥 Error fetching bookings: \(error.localizedDescription)")
                completion(nil, error)
                return
            }

            let bookings = snapshot?.documents.compactMap { doc -> Booking? in
                let data = doc.data()
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
            completion(bookings, nil)
        }
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
                  let currentStatus = currentData["status"] as? String else {
                errorPointer?.pointee = NSError(domain: "FirestoreError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid booking data"])
                return nil
            }

            // ✅ Prevent multiple updates by checking if status has changed
            if currentStatus == newStatus {
                print("⚠️ Booking \(bookingID) is already \(newStatus), skipping update.")
                return nil
            }

            // ✅ If canceling, restore the time slot to tutor's availability
            if newStatus == "canceled",
               let date = currentData["date"] as? String,
               let timeSlot = currentData["timeSlot"] as? String {

                let availabilityRef = db.collection("tutors").document(tutorID).collection("availability").document(date)

                // ✅ Restore the time slot
                transaction.updateData([
                    "timeSlots": FieldValue.arrayUnion([timeSlot])
                ], forDocument: availabilityRef)

                print("✅ Restored \(timeSlot) on \(date) to tutor \(tutorID)'s availability")
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
}
