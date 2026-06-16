import Combine
import Foundation

/// Manages the list of locked applications — CRUD + persistence.
/// Acts as the single source of truth for which apps are locked.
final class LockedAppsManager: ObservableObject {
    static let shared = LockedAppsManager()

    /// All apps the user has chosen to lock.
    @Published var lockedApps: [LockedApp] = []

    private let defaults = UserDefaults.standard

    private init() {
        loadLockedApps()
    }

    // MARK: - Public API

    /// Check if an app with the given bundle identifier is currently locked.
    func isLocked(_ bundleIdentifier: String) -> Bool {
        lockedApps.contains { $0.bundleIdentifier == bundleIdentifier && $0.isLocked }
    }

    /// Update the custom session timeout for an app.
    func updateCustomSessionTimeout(for bundleIdentifier: String, timeout: TimeInterval?) {
        if let index = lockedApps.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
            lockedApps[index].customSessionTimeout = timeout
            saveLockedApps()
        }
    }

    /// Add an app to the locked list.
    func lockApp(_ app: LockedApp) {
        if let index = lockedApps.firstIndex(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
            lockedApps[index].isLocked = true
        } else {
            var newApp = app
            newApp.isLocked = true
            lockedApps.append(newApp)
        }
        saveLockedApps()
        AppScheduleManager.shared.recordUserOverride(for: app.bundleIdentifier, wantsLocked: true)
    }

    /// Remove an app from the locked list (or mark it unlocked).
    func unlockApp(_ bundleIdentifier: String) {
        lockedApps.removeAll { $0.bundleIdentifier == bundleIdentifier }
        saveLockedApps()
        AppScheduleManager.shared.clearOverride(for: bundleIdentifier)
    }

    /// Toggle an app's lock state.
    func toggleLock(for bundleIdentifier: String) {
        if let index = lockedApps.firstIndex(where: { $0.bundleIdentifier == bundleIdentifier }) {
            lockedApps[index].isLocked.toggle()
            if !lockedApps[index].isLocked {
                lockedApps.remove(at: index)
                AppScheduleManager.shared.clearOverride(for: bundleIdentifier)
            } else {
                AppScheduleManager.shared.recordUserOverride(for: bundleIdentifier, wantsLocked: true)
            }
            saveLockedApps()
        }
    }

    /// Set the entire locked apps list (used during setup).
    func setLockedApps(_ apps: [LockedApp]) {
        lockedApps = apps.filter { $0.isLocked }
        saveLockedApps()
    }

    /// Get the display name for a locked app.
    func displayName(for bundleIdentifier: String) -> String? {
        lockedApps.first { $0.bundleIdentifier == bundleIdentifier }?.displayName
    }

    // MARK: - Persistence

    private func saveLockedApps() {
        guard let data = try? JSONEncoder().encode(lockedApps) else { return }
        defaults.set(data, forKey: FGConstants.lockedAppsKey)
    }

    private func loadLockedApps() {
        guard let data = defaults.data(forKey: FGConstants.lockedAppsKey),
              let apps = try? JSONDecoder().decode([LockedApp].self, from: data) else {
            return
        }
        lockedApps = apps
    }
}
