import AppKit
import Foundation

/// Represents an application that can be locked by FaceGate.
struct LockedApp: Codable, Identifiable, Hashable {
    /// The app's bundle identifier (e.g., "com.apple.MobileSMS").
    let bundleIdentifier: String

    /// The human-readable display name (e.g., "Messages").
    let displayName: String

    /// The app's icon stored as PNG data for persistence.
    let iconData: Data?

    /// Whether this app is currently locked.
    var isLocked: Bool

    /// Custom session timeout in seconds for this individual app.
    var customSessionTimeout: TimeInterval?

    var id: String { bundleIdentifier }

    /// Creates a LockedApp from an NSRunningApplication or file path.
    init(bundleIdentifier: String, displayName: String, iconData: Data? = nil, isLocked: Bool = true, customSessionTimeout: TimeInterval? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.iconData = iconData
        self.isLocked = isLocked
        self.customSessionTimeout = customSessionTimeout
    }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier, displayName, iconData, isLocked, customSessionTimeout
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        displayName = try container.decode(String.self, forKey: .displayName)
        iconData = try container.decodeIfPresent(Data.self, forKey: .iconData)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? true
        customSessionTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .customSessionTimeout)
    }

    /// Convenience: get the NSImage icon from stored data.
    var icon: NSImage? {
        if let iconData = iconData {
            return NSImage(data: iconData)
        }
        return nil
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: LockedApp, rhs: LockedApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}
