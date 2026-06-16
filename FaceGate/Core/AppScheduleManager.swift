import Combine
import Foundation

/// Manages time-range schedules for automatically locking or unlocking all apps.
/// Evaluates schedules every 30 seconds and respects user overrides so that
/// manual toggles are never reverted by the scheduler.
final class AppScheduleManager: ObservableObject {
    static let shared = AppScheduleManager()

    @Published var lockScheduleEnabled: Bool
    @Published var lockStartHour: Int
    @Published var lockStartMinute: Int
    @Published var lockEndHour: Int
    @Published var lockEndMinute: Int

    @Published var unlockScheduleEnabled: Bool
    @Published var unlockStartHour: Int
    @Published var unlockStartMinute: Int
    @Published var unlockEndHour: Int
    @Published var unlockEndMinute: Int

    /// User overrides: bundleIdentifier → user's desired state (true = wants locked, false = wants unlocked).
    private var userOverrides: [String: Bool] = [:]

    private var timer: Timer?
    private var wasInLockWindow = false
    private var wasInUnlockWindow = false

    private init() {
        let defaults = UserDefaults.standard

        lockScheduleEnabled = defaults.bool(forKey: FGConstants.lockAllScheduleEnabledKey)
        lockStartHour = defaults.integer(forKey: FGConstants.lockAllStartHourKey)
        lockStartMinute = defaults.integer(forKey: FGConstants.lockAllStartMinuteKey)
        lockEndHour = defaults.integer(forKey: FGConstants.lockAllEndHourKey)
        lockEndMinute = defaults.integer(forKey: FGConstants.lockAllEndMinuteKey)

        unlockScheduleEnabled = defaults.bool(forKey: FGConstants.unlockAllScheduleEnabledKey)
        unlockStartHour = defaults.integer(forKey: FGConstants.unlockAllStartHourKey)
        unlockStartMinute = defaults.integer(forKey: FGConstants.unlockAllStartMinuteKey)
        unlockEndHour = defaults.integer(forKey: FGConstants.unlockAllEndHourKey)
        unlockEndMinute = defaults.integer(forKey: FGConstants.unlockAllEndMinuteKey)

        if let data = defaults.data(forKey: FGConstants.userOverrideTimestampsKey),
           let overrides = try? JSONDecoder().decode([String: Bool].self, from: data) {
            userOverrides = overrides
        }

        startTimer()
    }

    // MARK: - Public API

    /// Records that the user manually set an app's desired lock state.
    /// The scheduler will respect this choice and not revert it.
    func recordUserOverride(for bundleID: String, wantsLocked: Bool) {
        userOverrides[bundleID] = wantsLocked
        saveOverrides()
    }

    /// Removes a user override for an app (e.g. when the app is removed from the locked list).
    func clearOverride(for bundleID: String) {
        userOverrides.removeValue(forKey: bundleID)
        saveOverrides()
    }

    /// Returns whether the given app has an active user override.
    func isOverridden(_ bundleID: String) -> Bool {
        userOverrides.keys.contains(bundleID)
    }

    // MARK: - Timer

    private func startTimer() {
        timer?.invalidate()
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            self?.evaluateSchedules()
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        evaluateSchedules()
    }

    // MARK: - Schedule Evaluation

    private func evaluateSchedules() {
        let now = Date()
        let inLockWindow = lockScheduleEnabled && isInWindow(
            startHour: lockStartHour, startMinute: lockStartMinute,
            endHour: lockEndHour, endMinute: lockEndMinute,
            now: now
        )
        let inUnlockWindow = unlockScheduleEnabled && isInWindow(
            startHour: unlockStartHour, startMinute: unlockStartMinute,
            endHour: unlockEndHour, endMinute: unlockEndMinute,
            now: now
        )

        if inLockWindow {
            applyLockSchedule()
        }

        if inUnlockWindow {
            applyUnlockSchedule()
        }

        if wasInLockWindow && !inLockWindow {
            userOverrides.removeAll()
            saveOverrides()
        }

        if wasInUnlockWindow && !inUnlockWindow {
            userOverrides.removeAll()
            saveOverrides()
        }

        wasInLockWindow = inLockWindow
        wasInUnlockWindow = inUnlockWindow
    }

    private func applyLockSchedule() {
        for app in LockedAppsManager.shared.lockedApps {
            if userOverrides[app.bundleIdentifier] == false { continue }
            SessionManager.shared.revokeSession(for: app.bundleIdentifier)
        }
    }

    private func applyUnlockSchedule() {
        for app in LockedAppsManager.shared.lockedApps {
            if userOverrides[app.bundleIdentifier] == true { continue }
            SessionManager.shared.createSession(for: app.bundleIdentifier)
        }
    }

    /// Checks if `now` falls within the time window defined by `startHour:startMinute` to `endHour:endMinute`.
    /// Supports windows that cross midnight (e.g. 10 PM → 7 AM).
    private func isInWindow(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, now: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: now)
        guard let currentHour = components.hour, let currentMinute = components.minute else { return false }

        let currentTotal = currentHour * 60 + currentMinute
        let startTotal = startHour * 60 + startMinute
        let endTotal = endHour * 60 + endMinute

        if startTotal <= endTotal {
            return currentTotal >= startTotal && currentTotal < endTotal
        } else {
            return currentTotal >= startTotal || currentTotal < endTotal
        }
    }

    // MARK: - Persistence

    private func saveOverrides() {
        guard let data = try? JSONEncoder().encode(userOverrides) else { return }
        UserDefaults.standard.set(data, forKey: FGConstants.userOverrideTimestampsKey)
    }
}
