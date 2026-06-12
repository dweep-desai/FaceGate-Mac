import Foundation
import Security

/// Wrapper around the macOS Keychain for secure credential storage.
/// Uses `Security` framework's `SecItem*` functions.
final class KeychainHelper {
    static let shared = KeychainHelper()

    private let service = FGConstants.keychainService

    private init() {}

    // MARK: - Public API

    /// Save data to the Keychain. Overwrites existing entry if present.
    /// - Parameters:
    ///   - data: The raw data to store.
    ///   - account: The account key (identifier for this entry).
    /// - Throws: `KeychainError` if the operation fails.
    func save(_ data: Data, for account: String) throws {
        // Try to update first; if the item doesn't exist, add it.
        let query = baseQuery(for: account)
        let updateAttributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            // Item doesn't exist — add it.
            var addQuery = query
            addQuery[kSecValueData as String] = data
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unableToSave(status: addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw KeychainError.unableToSave(status: updateStatus)
        }
    }

    /// Read data from the Keychain.
    /// - Parameter account: The account key to look up.
    /// - Returns: The stored data, or `nil` if not found.
    func read(for account: String) -> Data? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Delete an entry from the Keychain.
    /// - Parameter account: The account key to delete.
    func delete(for account: String) {
        let query = baseQuery(for: account)
        SecItemDelete(query as CFDictionary)
    }

    /// Check if an entry exists in the Keychain.
    /// - Parameter account: The account key to check.
    /// - Returns: `true` if the entry exists.
    func exists(for account: String) -> Bool {
        return read(for: account) != nil
    }

    // MARK: - Convenience (String)

    /// Save a string to the Keychain.
    func saveString(_ string: String, for account: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.encodingError
        }
        try save(data, for: account)
    }

    /// Read a string from the Keychain.
    func readString(for account: String) -> String? {
        guard let data = read(for: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Private

    private func baseQuery(for account: String) -> [String: Any] {
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError {
    case unableToSave(status: OSStatus)
    case encodingError

    var errorDescription: String? {
        switch self {
        case .unableToSave(let status):
            return "Keychain save failed with status: \(status)"
        case .encodingError:
            return "Failed to encode data for Keychain storage"
        }
    }
}
