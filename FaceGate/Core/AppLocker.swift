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

    /// Active overlay panels mapped by window IDs (or dummy IDs for fullscreen).
    private var overlayPanels: [CGWindowID: AuthOverlayPanel] = [:]

    /// Timer used to poll for window creation when app is launching.
    private var windowDetectionTimer: Timer?

    /// Timer used to periodically update overlays if the locked app's windows move/resize.
    private var windowAlignmentTimer: Timer?

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

        // Step 1: Immediately hide the locked app if in Full Screen mode.
        let overlayMode = UserDefaults.standard.integer(forKey: FGConstants.authOverlayModeKey)
        if overlayMode == 0 {
            runningApp.hide()
        } else {
            runningApp.activate(options: [.activateIgnoringOtherApps])
        }

        // Start Face ID authentication if available.
        if AuthenticationManager.shared.isFaceUnlockAvailable {
            AuthenticationManager.shared.authenticateWithFace { [weak self] success in
                if success {
                    self?.unlockCurrentApp()
                }
            }
        }

        // Step 2: Present auth overlays.
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

        // Stop face authentication.
        AuthenticationManager.shared.stopFaceAuth()

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
        AuthenticationManager.shared.stopFaceAuth()

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
        windowDetectionTimer?.invalidate()
        windowDetectionTimer = nil
        windowAlignmentTimer?.invalidate()
        windowAlignmentTimer = nil
        for panel in overlayPanels.values {
            panel.orderOut(nil)
        }
        overlayPanels.removeAll()
    }

    // MARK: - Private

    /// Create and show auth overlay panels.
    private func showOverlays(for bundleIdentifier: String) {
        dismissOverlays()

        let appName = LockedAppsManager.shared.displayName(for: bundleIdentifier) ?? "Application"
        let overlayMode = UserDefaults.standard.integer(forKey: FGConstants.authOverlayModeKey)

        if overlayMode == 1, let app = blockedRunningApp {
            let windows = getAppWindowFrames(for: app.processIdentifier)
            if !windows.isEmpty {
                for (windowID, frame) in windows {
                    let adjustedFrame = calculateOverlayFrame(from: convertQuartzToAppKit(rect: frame))
                    let panel = AuthOverlayPanel(
                        frame: adjustedFrame,
                        appName: appName,
                        bundleIdentifier: bundleIdentifier,
                        onAuthenticated: { [weak self] in
                            self?.unlockCurrentApp()
                        },
                        onCancel: { [weak self] in
                            self?.terminateBlockedApp()
                        }
                    )
                    panel.orderFront(nil)
                    overlayPanels[windowID] = panel
                }
                
                if let first = overlayPanels.values.first {
                    first.makeKeyAndOrderFront(nil)
                }
                
                // Track window updates periodically
                startWindowAlignmentTimer(for: app.processIdentifier, appName: appName, bundleIdentifier: bundleIdentifier)
            } else {
                // If no window found (e.g. launching), show a temporary full screen shield on main screen and poll.
                showTemporaryFullScreenOverlay(appName: appName, bundleIdentifier: bundleIdentifier)
            }
        } else {
            // Present auth overlays on all screens.
            let screens = NSScreen.screens
            let mouseLocation = NSEvent.mouseLocation
            let activeScreen = screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main ?? screens.first

            for (index, screen) in screens.enumerated() {
                let panel = AuthOverlayPanel(
                    frame: screen.frame,
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
                overlayPanels[CGWindowID(1000 + index)] = panel
            }
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

    /// Called when the user switches focus to another app.
    /// Gracefully hides the blocked application and dismisses overlays.
    func handleSwitchAway() {
        let overlayMode = UserDefaults.standard.integer(forKey: FGConstants.authOverlayModeKey)
        if overlayMode == 0 {
            blockedRunningApp?.hide()
        }
        dismissOverlays()
        currentlyBlockedApp = nil
        blockedRunningApp = nil
    }

    /// Bring existing overlay panels back to the front of the window stack.
    /// Called when the user Cmd+Tabs or clicks back to a locked app in App Window mode.
    func bringOverlaysToFront() {
        guard !overlayPanels.isEmpty else { return }
        for panel in overlayPanels.values {
            panel.orderFront(nil)
        }
        if let first = overlayPanels.values.first {
            first.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - App Window Mode Helpers

    /// Retrieve all onscreen window frames and IDs for a given process PID.
    private func getAppWindowFrames(for pid: pid_t) -> [(CGWindowID, CGRect)] {
        let options = CGWindowListOption.optionAll
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var windows: [(CGWindowID, CGRect)] = []
        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == pid else { continue }
            
            // Layer 0 is standard application windows.
            guard let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }
            
            guard let windowID = window[kCGWindowNumber as String] as? CGWindowID else { continue }
            
            if let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
               let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                // Ignore small accessory/dock/shadow/helper elements.
                if rect.width > 120 && rect.height > 120 {
                    windows.append((windowID, rect))
                }
            }
        }
        return windows
    }

    /// Convert Quartz (top-left origin) coordinates to AppKit (bottom-left origin) coordinates.
    private func convertQuartzToAppKit(rect: CGRect) -> CGRect {
        guard let mainScreen = NSScreen.screens.first else { return rect }
        let mainScreenHeight = mainScreen.frame.height
        let appKitY = mainScreenHeight - rect.origin.y - rect.height
        return CGRect(x: rect.origin.x, y: appKitY, width: rect.width, height: rect.height)
    }

    /// Enforce a minimum size of 400x500 for the overlay to avoid clipping UI components.
    private func calculateOverlayFrame(from windowFrame: CGRect) -> CGRect {
        let minWidth: CGFloat = 400
        let minHeight: CGFloat = 500
        
        var targetFrame = windowFrame
        
        if targetFrame.width < minWidth {
            let delta = minWidth - targetFrame.width
            targetFrame.origin.x -= delta / 2
            targetFrame.size.width = minWidth
        }
        
        if targetFrame.height < minHeight {
            let delta = minHeight - targetFrame.height
            targetFrame.origin.y -= delta / 2
            targetFrame.size.height = minHeight
        }
        
        return targetFrame
    }

    /// Start a timer to dynamically adjust the overlays if the locked app's windows move/resize/open/close.
    private func startWindowAlignmentTimer(for pid: pid_t, appName: String, bundleIdentifier: String) {
        windowAlignmentTimer?.invalidate()
        windowAlignmentTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let windows = self.getAppWindowFrames(for: pid)
            guard !windows.isEmpty else { return }
            
            let existingIDs = Set(self.overlayPanels.keys)
            let newIDs = Set(windows.map { $0.0 })
            
            if existingIDs == newIDs {
                for (windowID, frame) in windows {
                    if let panel = self.overlayPanels[windowID] {
                        let adjustedFrame = self.calculateOverlayFrame(from: self.convertQuartzToAppKit(rect: frame))
                        if panel.frame != adjustedFrame {
                            panel.setFrame(adjustedFrame, display: true, animate: false)
                        }
                    }
                }
            } else {
                // If window configuration changed, recreate the overlays
                self.showOverlays(for: bundleIdentifier)
            }
        }
    }

    /// Show a temporary full screen shield on the active screen and poll for window creation.
    private func showTemporaryFullScreenOverlay(appName: String, bundleIdentifier: String) {
        guard let activeScreen = NSScreen.main ?? NSScreen.screens.first else { return }
        
        let panel = AuthOverlayPanel(
            frame: activeScreen.frame,
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            onAuthenticated: { [weak self] in
                self?.unlockCurrentApp()
            },
            onCancel: { [weak self] in
                self?.terminateBlockedApp()
            }
        )
        panel.makeKeyAndOrderFront(nil)
        overlayPanels[0] = panel
        
        var attempts = 0
        windowDetectionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self, let app = self.blockedRunningApp else {
                timer.invalidate()
                return
            }
            
            attempts += 1
            let windows = self.getAppWindowFrames(for: app.processIdentifier)
            
            if !windows.isEmpty {
                timer.invalidate()
                self.windowDetectionTimer = nil
                
                // Transition to window-specific overlays
                self.showOverlays(for: bundleIdentifier)
            } else if attempts >= 20 { // Timeout after 2 seconds, keep full screen
                timer.invalidate()
                self.windowDetectionTimer = nil
            }
        }
    }
}
