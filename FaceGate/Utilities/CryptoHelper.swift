import CryptoKit
import Foundation

/// AES-256-GCM encryption/decryption helper using CryptoKit.
/// Used to encrypt face embedding data at rest.
final class CryptoHelper {
    static let shared = CryptoHelper()

    private init() {}

    // MARK: - Key Management

    /// Retrieve the encryption key from Keychain, or generate and store a new one.
    /// - Returns: A 256-bit symmetric key for AES-GCM.
    func getOrCreateKey() throws -> SymmetricKey {
        if let existingKeyData = KeychainHelper.shared.read(for: FGConstants.keychainFaceDataKeyAccount) {
            return SymmetricKey(data: existingKeyData)
        }

        // Generate a new random 256-bit key.
        let newKey = SymmetricKey(size: .bits256)
        let keyData = newKey.withUnsafeBytes { Data($0) }
        try KeychainHelper.shared.save(keyData, for: FGConstants.keychainFaceDataKeyAccount)
        return newKey
    }

    // MARK: - Encrypt / Decrypt

    /// Encrypt data using AES-256-GCM.
    /// - Parameters:
    ///   - data: The plaintext data to encrypt.
    ///   - key: The symmetric key to use. If nil, uses the stored/generated key.
    /// - Returns: The sealed box data (nonce + ciphertext + tag).
    func encrypt(_ data: Data, using key: SymmetricKey? = nil) throws -> Data {
        let encryptionKey = try key ?? getOrCreateKey()
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        guard let combined = sealedBox.combined else {
            throw CryptoError.encryptionFailed
        }
        return combined
    }

    /// Decrypt data using AES-256-GCM.
    /// - Parameters:
    ///   - data: The sealed box data (nonce + ciphertext + tag).
    ///   - key: The symmetric key to use. If nil, uses the stored/generated key.
    /// - Returns: The decrypted plaintext data.
    func decrypt(_ data: Data, using key: SymmetricKey? = nil) throws -> Data {
        let decryptionKey = try key ?? getOrCreateKey()
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: decryptionKey)
    }

    // MARK: - File Operations

    /// Encrypt data and write it to a file.
    func encryptToFile(_ data: Data, at url: URL) throws {
        let encrypted = try encrypt(data)
        try encrypted.write(to: url, options: [.atomic, .completeFileProtection])
    }

    /// Read and decrypt data from a file.
    func decryptFromFile(at url: URL) throws -> Data {
        let encrypted = try Data(contentsOf: url)
        return try decrypt(encrypted)
    }
}

// MARK: - Errors

enum CryptoError: LocalizedError {
    case encryptionFailed
    case decryptionFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        }
    }
}
