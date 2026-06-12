import Foundation

/// Manages temporary unlock sessions per app.
/// After successful authentication, an app is "unlocked" for a configurable duration.
/// When the session expires, the app re-locks on next activation.
final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    /// Active unlock sessions keyed by bundle identifier.
    /// Value is the session expiry date.
    @Published private(set) var activeSessions: [String: Date] = [:]

    /// Session timeout duration (read from UserDefaults, with fallback).
    var sessionTimeout: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: FGConstants.sessionTimeoutKey)
        return stored > 0 ? stored : FGConstants.defaultSessionTimeout
    }

    private var cleanupTimer: Timer?

    private init() {
        startCleanupTimer()
    }

    // MARK: - Public API

    /// Record that an app has been successfully unlocked.
    /// The session will expire after `sessionTimeout` seconds.
    func createSession(for bundleIdentifier: String) {
        let expiry = Date().addingTimeInterval(sessionTimeout)
        activeSessions[bundleIdentifier] = expiry
    }

    /// Check if an app has an active (non-expired) unlock session.
    func hasActiveSession(for bundleIdentifier: String) -> Bool {
        guard let expiry = activeSessions[bundleIdentifier] else { return false }
        if Date() < expiry {
            return true
        } else {
            // Session expired — clean up.
            activeSessions.removeValue(forKey: bundleIdentifier)
            return false
        }
    }

    /// Manually revoke the session for a specific app (re-lock it).
    func revokeSession(for bundleIdentifier: String) {
        activeSessions.removeValue(forKey: bundleIdentifier)
    }

    /// Revoke all active sessions (lock everything).
    func revokeAllSessions() {
        activeSessions.removeAll()
    }

    /// Update the session timeout duration.
    func setSessionTimeout(_ timeout: TimeInterval) {
        UserDefaults.standard.set(timeout, forKey: FGConstants.sessionTimeoutKey)
    }

    // MARK: - Private

    /// Periodically clean up expired sessions.
    private func startCleanupTimer() {
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.cleanupExpiredSessions()
        }
    }

    private func cleanupExpiredSessions() {
        let now = Date()
        activeSessions = activeSessions.filter { _, expiry in expiry > now }
    }
}
