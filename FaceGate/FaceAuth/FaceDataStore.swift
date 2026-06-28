import Foundation

/// Encrypted storage for face enrollment data.
/// Reads and writes the face embedding file using AES-256-GCM encryption via CryptoHelper.
final class FaceDataStore {
    static let shared = FaceDataStore()

    private let crypto = CryptoHelper.shared
    private let fileURL = FGConstants.faceDataFilePath

    private init() {}

    // MARK: - Read / Write

    /// Save a face enrollment to the encrypted data file.
    /// - Parameter enrollment: The face enrollment data to persist.
    func save(_ enrollment: FaceEnrollment) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(enrollment)

        // Ensure the parent directory exists before writing.
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        try crypto.encryptToFile(data, at: fileURL)

        // Update UserDefaults metadata.
        UserDefaults.standard.set(true, forKey: FGConstants.faceEnrolledKey)
    }

    /// Load the face enrollment from the encrypted data file.
    /// - Returns: The stored FaceEnrollment, or nil if no enrollment exists.
    func load() -> FaceEnrollment? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }

        do {
            let data = try crypto.decryptFromFile(at: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(FaceEnrollment.self, from: data)
        } catch {
            print("[FaceDataStore] Failed to load enrollment: \(error)")
            return nil
        }
    }

    /// Delete the stored face enrollment data.
    /// - Throws: If the file cannot be removed.
    func delete() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }

        // Clear UserDefaults metadata.
        UserDefaults.standard.set(false, forKey: FGConstants.faceEnrolledKey)
        UserDefaults.standard.set(false, forKey: FGConstants.faceUnlockEnabledKey)
    }

    /// Delete a specific face profile by its unique ID.
    /// - Parameter id: The UUID of the profile to remove.
    /// - Throws: If the updated enrollment cannot be saved or files deleted.
    func deleteProfile(id: UUID) throws {
        guard var enrollment = load() else { return }
        enrollment.faces.removeAll { $0.id == id }

        if enrollment.faces.isEmpty {
            try delete()
        } else {
            try save(enrollment)
        }
    }

    /// Rename an existing face profile.
    /// - Parameters:
    ///   - id: The UUID of the profile.
    ///   - newName: The new user-visible name.
    /// - Throws: If the file cannot be saved.
    func renameProfile(id: UUID, newName: String) throws {
        guard var enrollment = load() else { return }
        if let idx = enrollment.faces.firstIndex(where: { $0.id == id }) {
            enrollment.faces[idx].name = newName
            try save(enrollment)
        }
    }

    /// Append a new face profile to the existing enrollment, or create one.
    /// - Parameter profile: The new EnrolledFace to add.
    /// - Throws: If the file cannot be saved.
    func addProfile(_ profile: FaceEnrollment.EnrolledFace) throws {
        var enrollment: FaceEnrollment
        if let existing = load() {
            enrollment = existing
            enrollment.faces.append(profile)
        } else {
            enrollment = FaceEnrollment(faces: [profile])
        }
        try save(enrollment)
    }

    /// Whether a face enrollment exists on disk.
    var hasEnrollment: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }
}
