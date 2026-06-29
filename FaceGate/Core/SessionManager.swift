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

    /// Tracks when each unlocked app last lost focus (for "from focus" timer mode).
    private var appFocusLostAt: [String: Date] = [:]

    /// Duration per app used when session was created (needed for focus mode check).
    private var sessionDurations: [String: TimeInterval] = [:]

    private var cleanupTimer: Timer?

    private init() {
        startCleanupTimer()
    }

    /// Whether "from focus" timer mode is enabled for the given app.
    private func timerFromFocus(for bundleIdentifier: String) -> Bool {
        if let app = LockedAppsManager.shared.lockedApps.first(where: { $0.bundleIdentifier == bundleIdentifier }),
           let appMode = app.timerFromFocus {
            return appMode
        }
        return UserDefaults.standard.bool(forKey: FGConstants.sessionTimerFromFocusKey)
    }

    // MARK: - Public API

    /// Record that an app has been successfully unlocked.
    /// The session will expire after `sessionTimeout` seconds, or the app's custom timeout if configured.
    /// A duration of 0 (lock immediately) skips session creation — the app locks on next activation.
    /// A duration of -1 (indefinite) creates a session that never expires.
    func createSession(for bundleIdentifier: String) {
        var duration = sessionTimeout
        
        if let app = LockedAppsManager.shared.lockedApps.first(where: { $0.bundleIdentifier == bundleIdentifier }),
           let customTimeout = app.customSessionTimeout {
            duration = customTimeout
        }
        
        appFocusLostAt.removeValue(forKey: bundleIdentifier)
        
        if duration == FGConstants.indefiniteSessionValue {
            activeSessions[bundleIdentifier] = .distantFuture
            sessionDurations[bundleIdentifier] = duration
            return
        }
        
        guard duration > 0 else { return }
        
        let expiry = Date().addingTimeInterval(duration)
        activeSessions[bundleIdentifier] = expiry
        sessionDurations[bundleIdentifier] = duration
    }

    /// Check if an app has an active (non-expired) unlock session.
    func hasActiveSession(for bundleIdentifier: String) -> Bool {
        guard let expiry = activeSessions[bundleIdentifier] else { return false }
        if Date() < expiry {
            return true
        } else {
            // Session expired — clean up.
            activeSessions.removeValue(forKey: bundleIdentifier)
            sessionDurations.removeValue(forKey: bundleIdentifier)
            appFocusLostAt.removeValue(forKey: bundleIdentifier)
            return false
        }
    }

    /// Called when an app gains focus. For "from focus" mode, checks if the
    /// out-of-focus duration exceeded the timeout. If still within limit, extends
    /// the session expiry so the timer resets on each return.
    func appDidFocus(_ bundleIdentifier: String) {
        guard timerFromFocus(for: bundleIdentifier),
              let duration = sessionDurations[bundleIdentifier],
              duration > 0, duration != FGConstants.indefiniteSessionValue else { return }

        if let lostAt = appFocusLostAt[bundleIdentifier] {
            let outOfFocus = Date().timeIntervalSince(lostAt)
            appFocusLostAt.removeValue(forKey: bundleIdentifier)
            if outOfFocus > duration {
                revokeSession(for: bundleIdentifier)
                return
            }
        }

        // Extend the wall-clock expiry so the session doesn't expire while the app is in focus.
        activeSessions[bundleIdentifier] = Date().addingTimeInterval(duration)
    }

    /// Called when the timer mode is changed mid-session (globally or per-app).
    /// Extends the session expiry so the new mode takes effect immediately.
    func refreshSessionForTimerMode(_ bundleIdentifier: String) {
        guard timerFromFocus(for: bundleIdentifier),
              activeSessions[bundleIdentifier] != nil,
              let duration = sessionDurations[bundleIdentifier],
              duration > 0, duration != FGConstants.indefiniteSessionValue else { return }
        activeSessions[bundleIdentifier] = Date().addingTimeInterval(duration)
    }

    /// Called when an app loses focus. For "from focus" mode, records the time
    /// so the out-of-focus duration can be checked on next activation.
    func appDidBlur(_ bundleIdentifier: String) {
        guard timerFromFocus(for: bundleIdentifier),
              activeSessions[bundleIdentifier] != nil else { return }
        appFocusLostAt[bundleIdentifier] = Date()
    }

    /// Manually revoke the session for a specific app (re-lock it).
    func revokeSession(for bundleIdentifier: String) {
        activeSessions.removeValue(forKey: bundleIdentifier)
        sessionDurations.removeValue(forKey: bundleIdentifier)
        appFocusLostAt.removeValue(forKey: bundleIdentifier)
    }

    /// Revoke all active sessions (lock everything).
    func revokeAllSessions() {
        activeSessions.removeAll()
        sessionDurations.removeAll()
        appFocusLostAt.removeAll()
    }

    /// Update the session timeout duration.
    /// Applies the change to all existing sessions immediately.
    func setSessionTimeout(_ timeout: TimeInterval) {
        UserDefaults.standard.set(timeout, forKey: FGConstants.sessionTimeoutKey)
        if timeout == FGConstants.indefiniteSessionValue {
            for (bundleId, _) in activeSessions {
                activeSessions[bundleId] = .distantFuture
                sessionDurations[bundleId] = timeout
            }
        } else if timeout <= 0 {
            revokeAllSessions()
        } else {
            let newExpiry = Date().addingTimeInterval(timeout)
            for (bundleId, _) in activeSessions {
                activeSessions[bundleId] = newExpiry
                sessionDurations[bundleId] = timeout
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
