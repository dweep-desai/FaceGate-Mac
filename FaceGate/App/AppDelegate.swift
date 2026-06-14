import AppKit
import SwiftUI

/// AppDelegate for AppKit bridging — handles lifecycle events that SwiftUI can't.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settingsWindow: NSWindow?
    private var setupWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Pre-load the Core ML face embedding model to avoid cold-start delay.
        // The ANE compilation happens at load time (~200-500ms) — pay this cost now.
        FaceEmbedder.shared.loadModel()

        // Wire up AppMonitor ↔ AppLocker.
        AppMonitor.shared.onLockedAppDetected = { [weak self] bundleId, runningApp in
            _ = self  // silence warning
            AppLocker.shared.blockApp(bundleIdentifier: bundleId, runningApp: runningApp)
        }

        // Initialize as accessory to let SwiftUI's MenuBarExtra initialize first.
        NSApp.setActivationPolicy(.accessory)

        // Start monitoring if setup is complete, otherwise open setup after a delay.
        if UserDefaults.standard.bool(forKey: FGConstants.setupCompletedKey) {
            AppMonitor.shared.startMonitoring()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.openSetupWindow()
            }
        }

        // Listen for "open settings" notifications from MenuBarView.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSettingsWindow),
            name: .openSettings,
            object: nil
        )

        // Listen for "open setup" notifications from MenuBarView.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(openSetupWindow),
            name: .openSetup,
            object: nil
        )
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Require authentication to quit if setup is complete and apps are locked.
        let setupDone = UserDefaults.standard.bool(forKey: FGConstants.setupCompletedKey)
        let hasLockedApps = !LockedAppsManager.shared.lockedApps.isEmpty

        if setupDone && hasLockedApps {
            // Show auth dialog before quitting.
            let alert = NSAlert()
            alert.messageText = "Authenticate to Quit"
            alert.informativeText = "FaceGate is protecting your apps. Enter your password to quit."
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Quit Anyway")
            alert.alertStyle = .warning

            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
                // User confirmed quit.
                cleanup()
                return .terminateNow
            } else {
                return .terminateCancel
            }
        }

        cleanup()
        return .terminateNow
    }

    private func cleanup() {
        AppLocker.shared.dismissOverlays()
        AppMonitor.shared.stopMonitoring()
        AuthenticationManager.shared.stopFaceAuth()
    }

    // MARK: - Settings Window

    private func closeMenuBarWindow() {
        for window in NSApp.windows {
            let className = String(describing: type(of: window))
            if className.contains("StatusItem") || className.contains("MenuWindow") || (window.title.isEmpty && window.isVisible && className.contains("Window")) {
                window.close()
            }
        }
    }

    @objc private func openSettingsWindow() {
        closeMenuBarWindow()

        if let existing = settingsWindow {
            existing.orderFrontRegardless()
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 650, height: 450),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FaceGate Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc private func openSetupWindow() {
        closeMenuBarWindow()

        if let existing = setupWindow {
            existing.orderFrontRegardless()
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let setupView = SetupView {
            AppMonitor.shared.startMonitoring()
            // Find and close the setup window
            for window in NSApp.windows {
                if window.title == "FaceGate Setup" {
                    window.close()
                }
            }
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FaceGate Setup"
        window.contentView = NSHostingView(rootView: setupView)
        window.center()
        window.isReleasedWhenClosed = false
        
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        setupWindow = window
    }
}
