import Foundation
import LocalAuthentication

/// Handles Touch ID biometric authentication as a fallback method.
final class TouchIDAuth {
    static let shared = TouchIDAuth()

    private init() {}

    // MARK: - Public API

    /// Whether Touch ID is available on this Mac.
    var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
        return canEvaluate
    }

    /// Whether Touch ID is enabled by the user in FaceGuard settings.
    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: FGConstants.touchIDEnabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: FGConstants.touchIDEnabledKey) }
    }

    /// Whether Touch ID can be used (available AND enabled).
    var canUse: Bool {
        isAvailable && isEnabled
    }

    /// Authenticate using Touch ID.
    /// - Parameter reason: The reason displayed to the user (e.g., "Unlock Messages").
    /// - Parameter completion: Callback with success/failure result.
    func authenticate(reason: String, completion: @escaping (Result<Void, TouchIDError>) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = ""  // Hide "Enter Password" fallback (we have our own).

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(.failure(.notAvailable(error?.localizedDescription ?? "Touch ID is not available")))
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        ) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else if let laError = error as? LAError {
                    switch laError.code {
                    case .userCancel:
                        completion(.failure(.cancelled))
                    case .userFallback:
                        completion(.failure(.fallbackRequested))
                    case .biometryLockout:
                        completion(.failure(.lockedOut))
                    default:
                        completion(.failure(.failed(laError.localizedDescription)))
                    }
                } else {
                    completion(.failure(.failed(error?.localizedDescription ?? "Unknown error")))
                }
            }
        }
    }
}

// MARK: - Errors

enum TouchIDError: LocalizedError {
    case notAvailable(String)
    case cancelled
    case fallbackRequested
    case lockedOut
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable(let message):
            return "Touch ID not available: \(message)"
        case .cancelled:
            return "Authentication cancelled"
        case .fallbackRequested:
            return "User requested password fallback"
        case .lockedOut:
            return "Touch ID is locked out. Please try again later."
        case .failed(let message):
            return "Touch ID failed: \(message)"
        }
    }
}
