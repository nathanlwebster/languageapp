struct UserModel: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var name: String
    var isTutor: Bool
    var languages: [String]
    var bio: String
    var profileImageURL: String?

    // ✅ Make UserModel conform to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
