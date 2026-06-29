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

    /// If true, the session timer counts from when the app last lost focus (not from unlock).
    /// If nil, uses the global setting.
    var timerFromFocus: Bool?

    var id: String { bundleIdentifier }

    /// Creates a LockedApp from an NSRunningApplication or file path.
    init(bundleIdentifier: String, displayName: String, iconData: Data? = nil, isLocked: Bool = true, customSessionTimeout: TimeInterval? = nil, timerFromFocus: Bool? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.displayName = displayName
        self.iconData = iconData
        self.isLocked = isLocked
        self.customSessionTimeout = customSessionTimeout
        self.timerFromFocus = timerFromFocus
    }

    private enum CodingKeys: String, CodingKey {
        case bundleIdentifier, displayName, iconData, isLocked, customSessionTimeout, timerFromFocus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        displayName = try container.decode(String.self, forKey: .displayName)
        iconData = try container.decodeIfPresent(Data.self, forKey: .iconData)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? true
        customSessionTimeout = try container.decodeIfPresent(TimeInterval.self, forKey: .customSessionTimeout)
        timerFromFocus = try container.decodeIfPresent(Bool.self, forKey: .timerFromFocus)
    }

    private static let iconCache = NSCache<NSString, NSImage>()

    /// Convenience: get the NSImage icon from stored data.
    var icon: NSImage? {
        guard let iconData = iconData else { return nil }
        let key = bundleIdentifier as NSString
        if let cached = Self.iconCache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(data: iconData) else { return nil }
        Self.iconCache.setObject(image, forKey: key)
        return image
    }

    static func clearIconCache() {
        iconCache.removeAllObjects()
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }

    static func == (lhs: LockedApp, rhs: LockedApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}
