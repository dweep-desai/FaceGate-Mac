import Foundation

/// App-wide constants for FaceGate.
enum FGConstants {
    // MARK: - Keychain

    /// Keychain service name for all FaceGate entries.
    static let keychainService = "com.dweep.FaceGate"

    /// Keychain account key for the hashed app password.
    static let keychainPasswordAccount = "appPassword"

    /// Keychain account key for the password salt.
    static let keychainSaltAccount = "appPasswordSalt"

    /// Keychain account key for the face data encryption key.
    static let keychainFaceDataKeyAccount = "faceDataEncryptionKey"

    // MARK: - UserDefaults Keys

    /// Key: array of locked app bundle identifiers (encoded LockedApp data).
    static let lockedAppsKey = "lockedApps"

    /// Key: whether the initial setup has been completed.
    static let setupCompletedKey = "setupCompleted"

    /// Key: whether face unlock is enabled.
    static let faceUnlockEnabledKey = "faceUnlockEnabled"

    /// Key: whether Touch ID is enabled as a fallback.
    static let touchIDEnabledKey = "touchIDEnabled"

    /// Key: whether the user has enrolled their face.
    static let faceEnrolledKey = "faceEnrolled"

    /// Key: face unlock sensitivity threshold (Float, 0.0–1.0).
    static let faceUnlockThresholdKey = "faceUnlockThreshold"

    /// Key: session timeout in seconds.
    static let sessionTimeoutKey = "sessionTimeout"

    /// Key: whether to launch at login.
    static let launchAtLoginKey = "launchAtLogin"

    /// Key: whether protection is temporarily disabled.
    static let protectionDisabledKey = "protectionTemporarilyDisabled"

    /// Key: timestamp when temporary disable expires.
    static let protectionDisableExpiryKey = "protectionDisableExpiry"

    /// Key: whether to disable face unlock during certain hours.
    static let disableFaceUnlockHoursKey = "disableFaceUnlockHours"

    /// Key: start hour for disabling face unlock.
    static let faceUnlockDisabledStartHourKey = "faceUnlockDisabledStartHour"

    /// Key: start minute for disabling face unlock.
    static let faceUnlockDisabledStartMinuteKey = "faceUnlockDisabledStartMinute"

    /// Key: end hour for disabling face unlock.
    static let faceUnlockDisabledEndHourKey = "faceUnlockDisabledEndHour"

    /// Key: end minute for disabling face unlock.
    static let faceUnlockDisabledEndMinuteKey = "faceUnlockDisabledEndMinute"

    // MARK: - App Schedule

    /// Key: whether the lock-all-apps schedule is enabled.
    static let lockAllScheduleEnabledKey = "lockAllScheduleEnabled"

    /// Key: start hour for locking all apps.
    static let lockAllStartHourKey = "lockAllStartHour"

    /// Key: start minute for locking all apps.
    static let lockAllStartMinuteKey = "lockAllStartMinute"

    /// Key: end hour for locking all apps.
    static let lockAllEndHourKey = "lockAllEndHour"

    /// Key: end minute for locking all apps.
    static let lockAllEndMinuteKey = "lockAllEndMinute"

    /// Key: whether the unlock-all-apps schedule is enabled.
    static let unlockAllScheduleEnabledKey = "unlockAllScheduleEnabled"

    /// Key: start hour for unlocking all apps.
    static let unlockAllStartHourKey = "unlockAllStartHour"

    /// Key: start minute for unlocking all apps.
    static let unlockAllStartMinuteKey = "unlockAllStartMinute"

    /// Key: end hour for unlocking all apps.
    static let unlockAllEndHourKey = "unlockAllEndHour"

    /// Key: end minute for unlocking all apps.
    static let unlockAllEndMinuteKey = "unlockAllEndMinute"

    /// Key: user override timestamps for schedule (encoded [String: Bool]).
    static let userOverrideTimestampsKey = "userOverrideTimestamps"

    // MARK: - Defaults

    /// Default face unlock similarity threshold (balanced).
    static let defaultFaceUnlockThreshold: Float = 0.65

    /// Default session timeout: 5 minutes (seconds).
    static let defaultSessionTimeout: TimeInterval = 300

    /// Maximum failed auth attempts before lockout.
    static let maxFailedAttempts = 5

    /// Lockout duration after max failed attempts (seconds).
    static let lockoutDuration: TimeInterval = 60

    // MARK: - Face Enrollment

    /// Number of face frames to capture during enrollment (2 for each direction: straight, left, right, tilt).
    static let enrollmentFrameCount = 8

    /// Minimum face capture quality score (0.0–1.0) for enrollment.
    static let minimumCaptureQuality: Float = 0.35

    // MARK: - File Paths

    /// Directory for FaceGate application support data.
    static var appSupportDirectory: URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let faceGuardDir = appSupport.appendingPathComponent("FaceGate")
        try? fileManager.createDirectory(at: faceGuardDir, withIntermediateDirectories: true)
        return faceGuardDir
    }

    /// Path to the encrypted face embedding data file.
    static var faceDataFilePath: URL {
        appSupportDirectory.appendingPathComponent("face_data.encrypted")
    }

    // MARK: - UI

    /// Menu bar icon SF Symbol name.
    static let menuBarIcon = "MenuBarIcon"

    /// App display name.
    static let appName = "FaceGate"
}
