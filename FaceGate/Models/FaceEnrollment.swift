import Foundation

/// Model representing a user's face enrollment data.
/// Supports multiple registered face profiles.
/// Model representing a single face profile enrollment.
struct FaceProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    let enrolledDate: Date
    let embeddings: [[Float]]
    let averageQuality: Float
}

/// Model representing a user's face enrollment data.
/// Supports multiple registered face profiles.
struct FaceEnrollment: Codable {
    /// The registered face profiles.
    var profiles: [FaceProfile]

    enum CodingKeys: String, CodingKey {
        case embeddings
        case enrolledDate
        case averageQuality
        case profiles
    }

    init(profiles: [FaceProfile]) {
        self.profiles = profiles
    }

    // Auto-migrate legacy enrollment files to the new multi-profile format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let profiles = try? container.decode([FaceProfile].self, forKey: .profiles) {
            self.profiles = profiles
        } else if let legacyEmbeddings = try? container.decode([[Float]].self, forKey: .embeddings) {
            let date = (try? container.decode(Date.self, forKey: .enrolledDate)) ?? Date()
            let quality = (try? container.decode(Float.self, forKey: .averageQuality)) ?? 0.8
            
            let legacyProfile = FaceProfile(
                id: UUID(),
                name: "Primary Face",
                enrolledDate: date,
                embeddings: legacyEmbeddings,
                averageQuality: quality
            )
            self.profiles = [legacyProfile]
        } else {
            self.profiles = []
        }
    }

    /// Number of valid frames captured during enrollment.
    var frameCount: Int {
        profiles.reduce(0) { $0 + $1.embeddings.count }
    }

    /// Whether the enrollment has enough embeddings to be considered valid.
    var isValid: Bool {
        !profiles.isEmpty && profiles.allSatisfy { $0.embeddings.count >= 3 }
    }
}
