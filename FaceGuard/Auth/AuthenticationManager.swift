import Combine
import Foundation

/// Unified authentication manager that orchestrates all auth methods.
/// Follows the priority hierarchy: Face Unlock → Touch ID → App Password.
final class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()

    /// Current authentication state.
    @Published var authState: AuthState = .idle

    /// Number of failed attempts in the current session.
    @Published var failedAttempts: Int = 0

    /// Whether the user is locked out due to too many failures.
    @Published var isLockedOut: Bool = false

    private var lockoutTimer: Timer?

    private let passwordAuth = PasswordAuth.shared
    private let touchIDAuth = TouchIDAuth.shared

    private init() {}

    // MARK: - Auth State

    enum AuthState: Equatable {
        case idle
        case authenticating(AuthMethod)
        case success
        case failed(String)
        case lockedOut(TimeInterval)
    }

    // MARK: - Public API

    /// Get the list of available auth methods for the current session.
    func availableAuthMethods() -> [AuthMethod] {
        var methods: [AuthMethod] = []

        // Phase 2: Face unlock will be added here.
        // if isFaceUnlockEnabled && isFaceEnrolled {
        //     methods.append(.faceUnlock)
        // }

        if touchIDAuth.canUse {
            methods.append(.touchID)
        }

        if passwordAuth.isPasswordSet {
            methods.append(.appPassword)
        }

        return methods
    }

    /// Authenticate using Touch ID.
    /// - Parameter appName: Name of the app being unlocked (shown in Touch ID dialog).
    /// - Parameter completion: Called with the result.
    func authenticateWithTouchID(appName: String, completion: @escaping (Bool) -> Void) {
        guard !isLockedOut else {
            completion(false)
            return
        }

        authState = .authenticating(.touchID)

        touchIDAuth.authenticate(reason: "Unlock \(appName)") { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.onAuthSuccess()
                completion(true)
            case .failure(let error):
                switch error {
                case .cancelled, .fallbackRequested:
                    // User cancelled — don't count as a failed attempt.
                    self.authState = .idle
                default:
                    self.onAuthFailure(error.localizedDescription ?? "Touch ID failed")
                }
                completion(false)
            }
        }
    }

    /// Authenticate using the app password.
    /// - Parameter password: The password the user entered.
    /// - Returns: `true` if authentication succeeded.
    func authenticateWithPassword(_ password: String) -> Bool {
        guard !isLockedOut else { return false }

        authState = .authenticating(.appPassword)

        if passwordAuth.verifyPassword(password) {
            onAuthSuccess()
            return true
        } else {
            onAuthFailure("Incorrect password")
            return false
        }
    }

    /// Reset the failed attempts counter (e.g., after successful auth).
    func resetAttempts() {
        failedAttempts = 0
        isLockedOut = false
        lockoutTimer?.invalidate()
        lockoutTimer = nil
        authState = .idle
    }

    // MARK: - Private

    private func onAuthSuccess() {
        authState = .success
        failedAttempts = 0
        isLockedOut = false
        lockoutTimer?.invalidate()
    }

    private func onAuthFailure(_ message: String) {
        failedAttempts += 1

        if failedAttempts >= FGConstants.maxFailedAttempts {
            isLockedOut = true
            authState = .lockedOut(FGConstants.lockoutDuration)

            // Auto-unlock after lockout duration.
            lockoutTimer = Timer.scheduledTimer(withTimeInterval: FGConstants.lockoutDuration, repeats: false) { [weak self] _ in
                self?.isLockedOut = false
                self?.failedAttempts = 0
                self?.authState = .idle
            }
        } else {
            authState = .failed(message)
        }
    }
}
