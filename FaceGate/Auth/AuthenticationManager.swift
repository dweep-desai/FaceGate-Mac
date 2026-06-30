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
    let faceAuthManager = FaceAuthManager()

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

    /// Whether face unlock is available and enrolled.
    var isFaceUnlockAvailable: Bool {
        faceAuthManager.isAvailable
    }

    /// Get the list of available auth methods for the current session.
    func availableAuthMethods() -> [AuthMethod] {
        var methods: [AuthMethod] = []

        if faceAuthManager.isAvailable {
            methods.append(.faceUnlock)
        }

        if touchIDAuth.canUse {
            methods.append(.touchID)
        }

        if passwordAuth.isPasswordSet {
            methods.append(.appPassword)
        }

        return methods
    }

    /// Authenticate using Face Unlock.
    /// - Parameter completion: Called with the result.
    func authenticateWithFace(completion: @escaping (Bool) -> Void) {
        guard !isLockedOut else {
            completion(false)
            return
        }

        authState = .authenticating(.faceUnlock)

        faceAuthManager.startAuthentication { [weak self] success in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if success {
                    self.onAuthSuccess()
                    completion(true)
                } else {
                    // Don't count face auth timeout as a failure — let user try fallbacks.
                    self.authState = .idle
                    completion(false)
                }
            }
        }
    }

    /// Stop any in-progress face authentication.
    func stopFaceAuth() {
        faceAuthManager.stopAuthentication()
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
            // Ignore stale callbacks from cancelled/invalidated LAContext that arrive
            // after another auth method (e.g. password) already changed the state.
            guard case .authenticating(.touchID) = self.authState else { return }
            switch result {
            case .success:
                self.onAuthSuccess()
                completion(true)
            case .failure(let error):
                switch error {
                case .cancelled, .fallbackRequested:
                    self.authState = .idle
                default:
                    self.onAuthFailure(error.localizedDescription)
                }
                completion(false)
            }
        }
    }

    /// Stop any in-progress Touch ID authentication.
    func stopTouchIDAuth() {
        touchIDAuth.cancelAuthentication()
        if case .authenticating(let method) = authState, method == .touchID {
            authState = .idle
        }
    }

    /// Authenticate using the app password.
    /// - Parameter password: The password the user entered.
    /// - Returns: `true` if authentication succeeded.
    func authenticateWithPassword(_ password: String) -> Bool {
        guard !isLockedOut else { return false }

        stopTouchIDAuth() // Ensure Touch ID is cancelled if active
        
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
        stopFaceAuth()
    }

    // MARK: - Private

    private func onAuthSuccess() {
        authState = .success
        failedAttempts = 0
        isLockedOut = false
        lockoutTimer?.invalidate()
        stopFaceAuth()
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
