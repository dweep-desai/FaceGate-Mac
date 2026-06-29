import AppKit
import SwiftUI

/// Manages the "shield" — hiding locked apps and presenting auth overlays.
/// Coordinates between AppMonitor (detection) and AuthenticationManager (auth).
final class AppLocker: ObservableObject {
    static let shared = AppLocker()

    /// The bundle ID of the app currently being blocked (if any).
    @Published private(set) var currentlyBlockedApp: String?

    /// The running application instance being blocked.
    private(set) var blockedRunningApp: NSRunningApplication?

    /// Active overlay panels (one per screen for multi-display).
    private var overlayPanels: [AuthOverlayPanel] = []

    private let sessionManager = SessionManager.shared
    private let appMonitor = AppMonitor.shared

    private init() {}

    // MARK: - Public API

    /// Block a locked app: hide it and show the auth overlay.
    /// - Parameters:
    ///   - bundleIdentifier: The locked app's bundle ID.
    ///   - runningApp: The NSRunningApplication instance to hide.
    func blockApp(bundleIdentifier: String, runningApp: NSRunningApplication) {
        // Avoid re-blocking if we're already blocking this app.
        if currentlyBlockedApp == bundleIdentifier { return }

        currentlyBlockedApp = bundleIdentifier
        blockedRunningApp = runningApp

        // Step 1: Immediately hide the locked app.
        runningApp.hide()

        // Step 2: Present auth overlays on all screens.
        showOverlays(for: bundleIdentifier)
    }

    /// Called when authentication succeeds — reveal the app and dismiss overlays.
    func unlockCurrentApp() {
        guard let bundleId = currentlyBlockedApp else { return }

        // Save references before clearing state.
        let app = blockedRunningApp

        // Clear state BEFORE activate to prevent re-block during activation notification.
        currentlyBlockedApp = nil
        blockedRunningApp = nil

        // Create an unlock session (no-op for "lock immediately" — duration is 0).
        sessionManager.createSession(for: bundleId)
        appMonitor.recordUnlock(for: bundleId)

        // Dismiss overlays.
        dismissOverlays()

        // Unhide and activate the app.
        if let app = app {
            app.unhide()
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }

    /// Called when authentication fails and user chooses to cancel.
    /// Terminates the locked app instead of revealing it.
    func terminateBlockedApp() {
        dismissOverlays()

        if let app = blockedRunningApp {
            app.terminate()

            // Force terminate after a brief delay if the app doesn't comply.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !app.isTerminated {
                    app.forceTerminate()
                }
            }
        }

        currentlyBlockedApp = nil
        blockedRunningApp = nil
    }

    /// Dismiss all overlays without unlocking (e.g., if FaceGate is quitting).
    func dismissOverlays() {
        for panel in overlayPanels {
            panel.orderOut(nil)
        }
        overlayPanels.removeAll()
    }

    // MARK: - Private

    /// Create and show auth overlay panels on all connected screens.
    private func showOverlays(for bundleIdentifier: String) {
        dismissOverlays()

        let appName = LockedAppsManager.shared.displayName(for: bundleIdentifier) ?? "Application"

        let screens = NSScreen.screens
        let mouseLocation = NSEvent.mouseLocation
        let activeScreen = screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main ?? screens.first

        for screen in screens {
            let panel = AuthOverlayPanel(
                screen: screen,
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                onAuthenticated: { [weak self] in
                    self?.unlockCurrentApp()
                },
                onCancel: { [weak self] in
                    self?.terminateBlockedApp()
                }
            )
            if screen == activeScreen {
                panel.makeKeyAndOrderFront(nil)
            } else {
                panel.orderFront(nil)
            }
            overlayPanels.append(panel)
        }

        // Activate FaceGate so it becomes the active app and can receive keyboard input.
        NSApp.activate(ignoringOtherApps: true)

        // Hiding a running app causes macOS to asynchronously focus the next app.
        // We activate again on the next runloop tick to override this focus shift.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            if let activeScreen = activeScreen {
                self.overlayPanels.first(where: { $0.screen == activeScreen })?.makeKeyAndOrderFront(nil)
            }
        }
    }
}
