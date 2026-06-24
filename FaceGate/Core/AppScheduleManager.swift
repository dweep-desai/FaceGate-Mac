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
    private var cancellables = Set<AnyCancellable>()

    /// Whether the lock and unlock windows currently overlap at any point.
    @Published private(set) var lockUnlockWindowsOverlap = false

    private init() {
        let defaults = UserDefaults.standard

        lockScheduleEnabled = defaults.bool(forKey: FGConstants.lockAllScheduleEnabledKey)
        lockStartHour = defaults.object(forKey: FGConstants.lockAllStartHourKey) != nil ? defaults.integer(forKey: FGConstants.lockAllStartHourKey) : 22
        lockStartMinute = defaults.integer(forKey: FGConstants.lockAllStartMinuteKey)
        lockEndHour = defaults.object(forKey: FGConstants.lockAllEndHourKey) != nil ? defaults.integer(forKey: FGConstants.lockAllEndHourKey) : 7
        lockEndMinute = defaults.integer(forKey: FGConstants.lockAllEndMinuteKey)

        unlockScheduleEnabled = defaults.bool(forKey: FGConstants.unlockAllScheduleEnabledKey)
        unlockStartHour = defaults.object(forKey: FGConstants.unlockAllStartHourKey) != nil ? defaults.integer(forKey: FGConstants.unlockAllStartHourKey) : 7
        unlockStartMinute = defaults.integer(forKey: FGConstants.unlockAllStartMinuteKey)
        unlockEndHour = defaults.object(forKey: FGConstants.unlockAllEndHourKey) != nil ? defaults.integer(forKey: FGConstants.unlockAllEndHourKey) : 22
        unlockEndMinute = defaults.integer(forKey: FGConstants.unlockAllEndMinuteKey)

        if let data = defaults.data(forKey: FGConstants.userOverrideTimestampsKey),
           let overrides = try? JSONDecoder().decode([String: Bool].self, from: data) {
            userOverrides = overrides
        }

        // Auto-recalculate overlap whenever any schedule property changes.
        let publishers: [AnyPublisher<Void, Never>] = [
            $lockScheduleEnabled.map { _ in }.eraseToAnyPublisher(),
            $lockStartHour.map { _ in }.eraseToAnyPublisher(),
            $lockStartMinute.map { _ in }.eraseToAnyPublisher(),
            $lockEndHour.map { _ in }.eraseToAnyPublisher(),
            $lockEndMinute.map { _ in }.eraseToAnyPublisher(),
            $unlockScheduleEnabled.map { _ in }.eraseToAnyPublisher(),
            $unlockStartHour.map { _ in }.eraseToAnyPublisher(),
            $unlockStartMinute.map { _ in }.eraseToAnyPublisher(),
            $unlockEndHour.map { _ in }.eraseToAnyPublisher(),
            $unlockEndMinute.map { _ in }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(publishers)
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.lockUnlockWindowsOverlap = self?.windowsOverlap() ?? false
            }
            .store(in: &cancellables)

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

    /// Force an immediate schedule re-evaluation (e.g. after time changes in Settings).
    func refresh() {
        evaluateSchedules()
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
        lockUnlockWindowsOverlap = windowsOverlap()

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

        // Prevent overlap: unlock only fires when lock is NOT active.
        // Lock wins — security-first.
        if inUnlockWindow && !inLockWindow {
            applyUnlockSchedule()
        }

        wasInLockWindow = inLockWindow
        wasInUnlockWindow = inUnlockWindow && !inLockWindow
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

    /// Returns true if the lock and unlock time windows overlap at any point.
    private func windowsOverlap() -> Bool {
        guard lockScheduleEnabled && unlockScheduleEnabled else { return false }
        
        let lockStart = lockStartHour * 60 + lockStartMinute
        let lockEnd = lockEndHour * 60 + lockEndMinute
        let unlockStart = unlockStartHour * 60 + unlockStartMinute
        let unlockEnd = unlockEndHour * 60 + unlockEndMinute
        
        // If either window is empty, there is no overlap
        if lockStart == lockEnd || unlockStart == unlockEnd {
            return false
        }
        
        func inWindow(start: Int, end: Int, m: Int) -> Bool {
            if start < end {
                return m >= start && m < end
            } else {
                return m >= start || m < end
            }
        }
        
        for m in 0..<1440 {
            if inWindow(start: lockStart, end: lockEnd, m: m) &&
               inWindow(start: unlockStart, end: unlockEnd, m: m) {
                return true
            }
        }
        return false
    }

    /// Checks whether a specific time (checkHour:checkMinute) falls within a window.
    private func timeInWindow(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, checkHour: Int, checkMinute: Int) -> Bool {
        let checkTotal = checkHour * 60 + checkMinute
        let startTotal = startHour * 60 + startMinute
        let endTotal = endHour * 60 + endMinute

        if startTotal <= endTotal {
            return checkTotal >= startTotal && checkTotal < endTotal
        } else {
            return checkTotal >= startTotal || checkTotal < endTotal
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
