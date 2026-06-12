import Foundation

/// Supported authentication methods in priority order.
enum AuthMethod: String, Codable, CaseIterable, Identifiable {
    /// Face unlock via camera — the primary USP.
    case faceUnlock = "faceUnlock"

    /// Touch ID biometric authentication — fallback 1.
    case touchID = "touchID"

    /// Custom app password — fallback 2 (always available).
    case appPassword = "appPassword"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .faceUnlock: return "Face Unlock"
        case .touchID: return "Touch ID"
        case .appPassword: return "App Password"
        }
    }

    var iconName: String {
        switch self {
        case .faceUnlock: return "faceid"
        case .touchID: return "touchid"
        case .appPassword: return "key.fill"
        }
    }

    var description: String {
        switch self {
        case .faceUnlock:
            return "Unlock apps by looking at your camera. Fast and hands-free."
        case .touchID:
            return "Use the Touch ID sensor on your Mac to authenticate."
        case .appPassword:
            return "Enter your FaceGuard password to unlock apps."
        }
    }
}
