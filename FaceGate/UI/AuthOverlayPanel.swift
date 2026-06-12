import AppKit
import SwiftUI

/// A full-screen, non-dismissable NSPanel that overlays a locked app's content.
/// Presented at screenSaver window level to block all interaction with the underlying app.
/// Hosts the SwiftUI AuthOverlayView via NSHostingView.
final class AuthOverlayPanel: NSPanel {
    /// Create an overlay panel covering the given screen.
    /// - Parameters:
    ///   - screen: The screen to cover.
    ///   - appName: Display name of the locked app.
    ///   - bundleIdentifier: Bundle ID of the locked app.
    ///   - onAuthenticated: Called when authentication succeeds.
    ///   - onCancel: Called when the user cancels / wants to quit the locked app.
    init(
        screen: NSScreen,
        appName: String,
        bundleIdentifier: String,
        onAuthenticated: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Panel configuration for maximum blocking.
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isReleasedWhenClosed = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovable = false
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.canHide = false
        self.becomesKeyOnlyIfNeeded = false
        self.acceptsMouseMovedEvents = false

        // Ignore all mouse events on the panel background (SwiftUI view handles interaction).
        self.ignoresMouseEvents = false

        // Load the app icon for display.
        let appIcon = loadAppIcon(bundleIdentifier: bundleIdentifier)

        // Host the SwiftUI auth overlay view.
        let overlayView = AuthOverlayView(
            appName: appName,
            appIcon: appIcon,
            onAuthenticated: onAuthenticated,
            onCancel: onCancel
        )

        let hostingView = NSHostingView(rootView: overlayView)
        hostingView.frame = screen.frame
        self.contentView = hostingView
    }

    // Prevent closing via keyboard shortcuts.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    // MARK: - Private

    private func loadAppIcon(bundleIdentifier: String) -> NSImage {
        // Try to find the app path via its bundle identifier.
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 64, height: 64)
            return icon
        }

        // Fallback: generic application icon.
        return NSWorkspace.shared.icon(for: .applicationBundle)
    }
}
