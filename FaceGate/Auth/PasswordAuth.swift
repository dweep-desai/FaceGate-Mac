import CommonCrypto
import Foundation

/// Handles the custom app password authentication method.
/// Passwords are hashed (SHA-256 + salt) and stored in the Keychain.
final class PasswordAuth {
    static let shared = PasswordAuth()

    private let keychain = KeychainHelper.shared

    private init() {}

    // MARK: - Public API

    /// Whether a password has been set.
    var isPasswordSet: Bool {
        keychain.exists(for: FGConstants.keychainPasswordAccount)
    }

    /// Set a new app password.
    /// - Parameter password: The plaintext password to hash and store.
    func setPassword(_ password: String) throws {
        // Generate a random salt.
        let salt = generateSalt()

        // Hash the password with salt.
        let hashedPassword = hashPassword(password, salt: salt)

        // Store both in Keychain.
        try keychain.save(hashedPassword, for: FGConstants.keychainPasswordAccount)
        try keychain.save(salt, for: FGConstants.keychainSaltAccount)
    }

    /// Verify a password against the stored hash.
    /// - Parameter password: The plaintext password to verify.
    /// - Returns: `true` if the password matches.
    func verifyPassword(_ password: String) -> Bool {
        guard let storedHash = keychain.read(for: FGConstants.keychainPasswordAccount),
              let storedSalt = keychain.read(for: FGConstants.keychainSaltAccount) else {
            return false
        }

        let attemptHash = hashPassword(password, salt: storedSalt)
        return constantTimeEqual(attemptHash, storedHash)
    }

    /// Change the app password (requires old password verification first).
    /// - Parameters:
    ///   - oldPassword: The current password for verification.
    ///   - newPassword: The new password to set.
    /// - Returns: `true` if the password was changed successfully.
    func changePassword(from oldPassword: String, to newPassword: String) -> Bool {
        guard verifyPassword(oldPassword) else { return false }
        do {
            try setPassword(newPassword)
            return true
        } catch {
            return false
        }
    }

    /// Delete the stored password (for full reset).
    func deletePassword() {
        keychain.delete(for: FGConstants.keychainPasswordAccount)
        keychain.delete(for: FGConstants.keychainSaltAccount)
    }

    // MARK: - Private

    /// Compare two Data buffers in constant time to prevent timing side-channel attacks.
    /// Swift's default `==` on Data exits on the first mismatched byte, leaking information
    /// about how many leading bytes were correct. This XOR-accumulation approach always
    /// examines every byte regardless of where differences occur.
    private func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for (x, y) in zip(a, b) {
            diff |= x ^ y
        }
        return diff == 0
    }

    /// Generate a random 32-byte salt.
    private func generateSalt() -> Data {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
        }
        return salt
    }

    /// Hash a password with a salt using SHA-256.
    private func hashPassword(_ password: String, salt: Data) -> Data {
        guard let passwordData = password.data(using: .utf8) else {
            return Data()
        }

        var combined = salt
        combined.append(passwordData)

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        combined.withUnsafeBytes { buffer in
            CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }

        return Data(hash)
    }
}
