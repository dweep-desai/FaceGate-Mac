import AppKit
import SwiftUI

/// A custom floating authentication window used for FaceGate settings or actions.
/// Size: 360x520, borderless, with rounded corners and shadow.
final class ActionAuthWindow: NSPanel {
    private static var activeWindow: ActionAuthWindow?

    /// Show the authentication window for a specific action/reason.
    /// - Parameters:
    ///   - reason: Display name of the action (e.g. "FaceGate Settings").
    ///   - onAuthenticated: Callback if authentication succeeds.
    static func show(reason: String, onAuthenticated: @escaping () -> Void, onCancelled: (() -> Void)? = nil) {
        // Ensure any previous authentication dialog is closed.
        activeWindow?.close()

        let appIcon: NSImage
        if let appIconImage = NSApp.applicationIconImage {
            appIcon = appIconImage
        } else {
            appIcon = NSWorkspace.shared.icon(for: .applicationBundle)
        }

        let panel = ActionAuthWindow(
            reason: reason,
            appIcon: appIcon,
            onAuthenticated: {
                let cachedWindow = activeWindow
                activeWindow = nil
                cachedWindow?.close()
                AuthenticationManager.shared.stopFaceAuth()
                onAuthenticated()
            },
            onCancel: {
                let cachedWindow = activeWindow
                activeWindow = nil
                cachedWindow?.close()
                AuthenticationManager.shared.stopFaceAuth()
                onCancelled?()
            }
        )
        
        activeWindow = panel
        panel.center()
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if AuthenticationManager.shared.isFaceUnlockAvailable {
            AuthenticationManager.shared.authenticateWithFace { _ in }
        }
    }

    init(
        reason: String,
        appIcon: NSImage,
        onAuthenticated: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 520),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces]
        self.isMovable = true
        self.isMovableByWindowBackground = true

        let overlayView = AuthOverlayView(
            appName: reason,
            appIcon: appIcon,
            isAppLocking: false,
            cancelButtonTitle: "Cancel",
            onAuthenticated: onAuthenticated,
            onCancel: onCancel
        )

        // Clip to beautiful rounded corners.
        let hostingView = NSHostingView(rootView: overlayView.cornerRadius(16))
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 520)
        self.contentView = hostingView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    deinit {
        AuthenticationManager.shared.stopFaceAuth()
    }
}
