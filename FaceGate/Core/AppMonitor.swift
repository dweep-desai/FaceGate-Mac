import AppKit
import Combine
import Foundation

/// Monitors application launches and activations system-wide.
/// When a locked app is detected, notifies AppLocker to block access.
final class AppMonitor: ObservableObject {
    static let shared = AppMonitor()

    /// Whether monitoring is active.
    @Published private(set) var isMonitoring = false

    /// Callback invoked when a locked app launch/activation is detected.
    /// The parameter is the bundle identifier of the detected app.
    var onLockedAppDetected: ((String, NSRunningApplication) -> Void)?

    private var launchObserver: NSObjectProtocol?
    private var activateObserver: NSObjectProtocol?

    private let lockedAppsManager = LockedAppsManager.shared
    private let sessionManager = SessionManager.shared

    /// Cooldown to prevent re-lock loop right after unlock (used for "lock immediately" mode).
    private var recentlyUnlocked: [String: Date] = [:]

    private init() {}

    /// Record that an app was just unlocked (starts a 1-second cooldown against re-lock).
    func recordUnlock(for bundleIdentifier: String) {
        recentlyUnlocked[bundleIdentifier] = Date()
    }

    // MARK: - Public API

    /// Start monitoring app launches and activations.
    func startMonitoring() {
        guard !isMonitoring else { return }

        let center = NSWorkspace.shared.notificationCenter

        // Observe new app launches.
        launchObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppEvent(notification)
        }

        // Observe app activations (switching to an already-running app).
        activateObserver = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppEvent(notification)
        }

        isMonitoring = true
    }

    /// Stop monitoring app launches and activations.
    func stopMonitoring() {
        guard isMonitoring else { return }

        let center = NSWorkspace.shared.notificationCenter

        if let observer = launchObserver {
            center.removeObserver(observer)
            launchObserver = nil
        }

        if let observer = activateObserver {
            center.removeObserver(observer)
            activateObserver = nil
        }

        isMonitoring = false
    }

    // MARK: - Private

    private func handleAppEvent(_ notification: Notification) {
        // Check if protection is temporarily disabled.
        if isProtectionDisabled() { return }

        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return
        }

        // Check if this app is in the locked list.
        guard lockedAppsManager.isLocked(bundleId) else { return }

        // Check if there's an active unlock session.
        guard !sessionManager.hasActiveSession(for: bundleId) else { return }

        // Cooldown: don't re-lock within 1 second of being unlocked.
        // This prevents a re-lock loop when "lock immediately" (no session) is set.
        if let lastUnlock = recentlyUnlocked[bundleId],
           Date().timeIntervalSince(lastUnlock) < 1 {
            return
        }

        // Locked app detected — notify the AppLocker.
        onLockedAppDetected?(bundleId, app)
    }

    /// Check if the user has temporarily disabled protection.
    private func isProtectionDisabled() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: FGConstants.protectionDisabledKey) else { return false }

        if let expiry = defaults.object(forKey: FGConstants.protectionDisableExpiryKey) as? Date {
            if Date() < expiry {
                return true
            } else {
                // Temporary disable has expired — re-enable.
                defaults.set(false, forKey: FGConstants.protectionDisabledKey)
                defaults.removeObject(forKey: FGConstants.protectionDisableExpiryKey)
                return false
            }
        }

        return false
    }
}
