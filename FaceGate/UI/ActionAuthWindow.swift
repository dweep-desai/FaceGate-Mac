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
                onAuthenticated()
            },
            onCancel: {
                let cachedWindow = activeWindow
                activeWindow = nil
                cachedWindow?.close()
                onCancelled?()
            }
        )
        activeWindow = panel
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Ensure the window is perfectly centered on the screen containing the mouse,
        // done asynchronously so NSHostingController has time to calculate its intrinsic size.
        DispatchQueue.main.async {
            panel.layoutIfNeeded()
            if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
                let screenRect = screen.visibleFrame
                let newRect = NSRect(
                    x: screenRect.midX - panel.frame.width / 2,
                    y: screenRect.midY - panel.frame.height / 2,
                    width: panel.frame.width,
                    height: panel.frame.height
                )
                panel.setFrame(newRect, display: true)
            } else {
                panel.center()
            }
        }
    }

    init(
        reason: String,
        appIcon: NSImage,
        onAuthenticated: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
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

        // Clip to beautiful rounded corners and fix only the width
        let fixedSizeView = overlayView
            .frame(width: 360)
            .cornerRadius(16)
            
        let hostingController = NSHostingController(rootView: fixedSizeView)
        hostingController.sizingOptions = [.intrinsicContentSize]
        self.contentViewController = hostingController
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
