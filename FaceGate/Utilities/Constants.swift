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

    /// Number of face frames to capture during enrollment.
    static let enrollmentFrameCount = 7

    /// Minimum face capture quality score (0.0–1.0) for enrollment.
    static let minimumCaptureQuality: Float = 0.4

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
    static let menuBarIcon = "face.smiling"

    /// App display name.
    static let appName = "FaceGate"
}
