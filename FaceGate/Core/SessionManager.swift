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
    /// A stored value of 0 means "lock immediately" — no session is created.
    /// When no value has been stored yet, returns the default (5 minutes).
    var sessionTimeout: TimeInterval {
        let stored = UserDefaults.standard.double(forKey: FGConstants.sessionTimeoutKey)
        if UserDefaults.standard.object(forKey: FGConstants.sessionTimeoutKey) != nil {
            return stored
        }
        return FGConstants.defaultSessionTimeout
    }

    private var cleanupTimer: Timer?

    private init() {
        startCleanupTimer()
    }

    // MARK: - Public API

    /// Record that an app has been successfully unlocked.
    /// The session will expire after `sessionTimeout` seconds, or the app's custom timeout if configured.
    /// A duration of 0 (lock immediately) skips session creation — the app locks on next activation.
    func createSession(for bundleIdentifier: String) {
        var duration = sessionTimeout
        
        if let app = LockedAppsManager.shared.lockedApps.first(where: { $0.bundleIdentifier == bundleIdentifier }),
           let customTimeout = app.customSessionTimeout {
            duration = customTimeout
        }
        
        guard duration > 0 else { return }
        
        let expiry = Date().addingTimeInterval(duration)
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
    /// Applies the change to all existing sessions immediately.
    func setSessionTimeout(_ timeout: TimeInterval) {
        UserDefaults.standard.set(timeout, forKey: FGConstants.sessionTimeoutKey)
        if timeout <= 0 {
            revokeAllSessions()
        } else {
            let newExpiry = Date().addingTimeInterval(timeout)
            for (bundleId, _) in activeSessions {
                activeSessions[bundleId] = newExpiry
            }
        }
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
