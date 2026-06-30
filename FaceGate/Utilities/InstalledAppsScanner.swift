import AppKit
import Foundation

/// Scans the system for installed applications and returns metadata
/// suitable for displaying in the app picker UI.
final class InstalledAppsScanner {
    /// Represents a discovered application on the system.
    struct DiscoveredApp: Identifiable, Hashable {
        let bundleIdentifier: String
        let displayName: String
        let icon: NSImage
        let path: URL

        var id: String { bundleIdentifier }

        func hash(into hasher: inout Hasher) {
            hasher.combine(bundleIdentifier)
        }

        static func == (lhs: DiscoveredApp, rhs: DiscoveredApp) -> Bool {
            lhs.bundleIdentifier == rhs.bundleIdentifier
        }
    }

    static let shared = InstalledAppsScanner()

    private init() {}

    /// Scan for installed applications in standard directories.
    /// - Returns: Array of discovered apps sorted by display name.
    func scanInstalledApps() -> [DiscoveredApp] {
        var apps: [String: DiscoveredApp] = [:]

        let searchPaths = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"),
        ]

        for searchPath in searchPaths {
            scanDirectory(searchPath, into: &apps, depth: 0, maxDepth: 2)
        }

        // Filter out FaceGate itself and system daemons without UI.
        let excludedBundleIDs: Set<String> = [
            "com.dweep.FaceGate",
            "com.apple.finder",  // Finder can't meaningfully be locked
        ]

        return apps.values
            .filter { !excludedBundleIDs.contains($0.bundleIdentifier) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Convert a DiscoveredApp into a LockedApp for persistence.
    func toLockedApp(_ discovered: DiscoveredApp, isLocked: Bool = true) -> LockedApp {
        let iconData = discovered.icon.tiffRepresentation.flatMap {
            NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
        }

        return LockedApp(
            bundleIdentifier: discovered.bundleIdentifier,
            displayName: discovered.displayName,
            iconData: iconData,
            isLocked: isLocked
        )
    }

    // MARK: - Private

    private func scanDirectory(_ directory: URL, into apps: inout [String: DiscoveredApp], depth: Int, maxDepth: Int) {
        guard depth <= maxDepth else { return }
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in contents {
            if url.pathExtension == "app" {
                if let app = createDiscoveredApp(from: url) {
                    // Use bundle ID as key to deduplicate.
                    apps[app.bundleIdentifier] = app
                }
            } else if (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                // Recurse into subdirectories (e.g., /Applications/Utilities/).
                scanDirectory(url, into: &apps, depth: depth + 1, maxDepth: maxDepth)
            }
        }
    }

    private func createDiscoveredApp(from appURL: URL) -> DiscoveredApp? {
        guard let bundle = Bundle(url: appURL),
              let bundleIdentifier = bundle.bundleIdentifier else {
            return nil
        }

        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? appURL.deletingPathExtension().lastPathComponent

        // Downscale to a single 64x64 thumbnail to avoid holding all .icns sizes (~5-8 MB per app).
        let fullIcon = NSWorkspace.shared.icon(forFile: appURL.path)
        let thumbnail = NSImage(size: NSSize(width: 64, height: 64))
        thumbnail.lockFocus()
        fullIcon.draw(in: NSRect(x: 0, y: 0, width: 64, height: 64),
                      from: NSRect(x: 0, y: 0, width: fullIcon.size.width, height: fullIcon.size.height),
                      operation: .copy, fraction: 1.0)
        thumbnail.unlockFocus()

        return DiscoveredApp(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            icon: thumbnail,
            path: appURL
        )
    }
}
