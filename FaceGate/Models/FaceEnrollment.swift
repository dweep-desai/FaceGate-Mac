import Foundation

/// Model representing a user's face enrollment data.
/// Contains one or more enrolled faces.
struct FaceEnrollment: Codable {
    struct EnrolledFace: Codable, Identifiable {
        let id: UUID
        var name: String
        let embeddings: [[Float]]
        let enrolledDate: Date
        let averageQuality: Float
    }

    var faces: [EnrolledFace]

    /// Whether the enrollment has enough embeddings to be considered valid.
    var isValid: Bool {
        !faces.isEmpty && faces.allSatisfy { $0.embeddings.count >= 3 }
    }

    init(faces: [EnrolledFace]) {
        self.faces = faces
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let decodedFaces = try? container.decode([EnrolledFace].self, forKey: .faces) {
            self.faces = decodedFaces
        } else {
            // Fallback to legacy single-face format
            let embeddings = try container.decode([[Float]].self, forKey: .embeddings)
            let enrolledDate = try container.decode(Date.self, forKey: .enrolledDate)
            let averageQuality = try container.decode(Float.self, forKey: .averageQuality)
            
            let legacyFace = EnrolledFace(
                id: UUID(),
                name: "Face 1",
                embeddings: embeddings,
                enrolledDate: enrolledDate,
                averageQuality: averageQuality
            )
            self.faces = [legacyFace]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(faces, forKey: .faces)
    }

    enum CodingKeys: String, CodingKey {
        case faces
        case embeddings
        case enrolledDate
        case averageQuality
    }
}

