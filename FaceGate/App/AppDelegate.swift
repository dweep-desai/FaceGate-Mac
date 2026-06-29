import AppKit
import SwiftUI
import Sparkle

/// AppDelegate for AppKit bridging — handles lifecycle events that SwiftUI can't.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate?

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    private var settingsWindow: NSWindow?
    private var setupWindow: NSWindow?
    private var settingsChromeState: SettingsChromeState?
    private var settingsSidebarToggleTarget: SettingsSidebarToggleTarget?
    private(set) var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize Sparkle updater for automatic updates.
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )

        // Pre-load the Core ML face embedding model to avoid cold-start delay.
        // The ANE compilation happens at load time (~200-500ms) — pay this cost now.
        FaceEmbedder.shared.loadModel()

        // Start the schedule manager so it begins evaluating lock/unlock time windows.
        _ = AppScheduleManager.shared

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

        // Sync uninstall protection state on startup.
        syncUninstallProtection()

        // Register secret kill hotkey.
        GlobalHotkeyManager.shared.registerShortcut()

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

        // Lock all apps when the Mac sleeps or locks (if enabled).
        let wsNC = NSWorkspace.shared.notificationCenter
        wsNC.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        wsNC.addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSWorkspace.screensDidSleepNotification,
            object: nil
        )
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(systemWillSleep),
            name: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil
        )
    }

    var isAuthorizedToQuit = false

    var isSettingsWindowVisible: Bool {
        settingsWindow?.isVisible ?? false
    }



    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // If settings window is open or we've pre-authorized, allow quitting without authentication.
        if isAuthorizedToQuit || isSettingsWindowVisible {
            cleanup()
            return .terminateNow
        }

        let setupDone = UserDefaults.standard.bool(forKey: FGConstants.setupCompletedKey)
        let hasLockedApps = !LockedAppsManager.shared.lockedApps.isEmpty

        if setupDone && hasLockedApps {
            // Show auth dialog alert fallback for system-level quit signals.
            let alert = NSAlert()
            alert.messageText = "Authenticate to Quit"
            alert.informativeText = "FaceGate is protecting your apps. Enter your password to quit."
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Quit Anyway")
            alert.alertStyle = .warning

            let response = alert.runModal()
            if response == .alertSecondButtonReturn {
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
        UserDefaults.standard.set(false, forKey: FGConstants.protectionDisabledKey)
        UserDefaults.standard.removeObject(forKey: FGConstants.protectionDisableExpiryKey)
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

        ActionAuthWindow.show(reason: "FaceGate Settings") { [weak self] in
            guard let self = self else { return }

            if let existing = self.settingsWindow {
                existing.orderFrontRegardless()
                existing.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return
            }

            let chromeState = SettingsChromeState()
            let settingsView = SettingsView(chromeState: chromeState)
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "FaceGate Settings"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.backgroundColor = .clear
            window.isMovableByWindowBackground = true
            window.minSize = NSSize(width: 850, height: 620)
            window.contentView = NSHostingView(rootView: settingsView)
            window.level = .floating
            installSettingsSidebarToggle(on: window, chromeState: chromeState)
            window.center()
            window.isReleasedWhenClosed = false
            
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            self.settingsChromeState = chromeState
            self.settingsWindow = window
        }
    }

    private func installSettingsSidebarToggle(on window: NSWindow, chromeState: SettingsChromeState) {
        let button = NSButton(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
        button.image = NSImage(systemSymbolName: "sidebar.leading", accessibilityDescription: "Toggle sidebar")
        button.imagePosition = .imageOnly
        button.bezelStyle = .rounded
        button.isBordered = true
        button.focusRingType = .none
        button.toolTip = "Toggle sidebar"

        let target = SettingsSidebarToggleTarget(chromeState: chromeState)
        button.target = target
        button.action = #selector(SettingsSidebarToggleTarget.toggleSidebar)
        settingsSidebarToggleTarget = target

        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = button
        accessory.layoutAttribute = .left
        window.addTitlebarAccessoryViewController(accessory)
    }

    @objc private func openSetupWindow() {
        closeMenuBarWindow()

        if let existing = setupWindow {
            existing.orderFrontRegardless()
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let setupView = SetupView(
            onSetupComplete: {
                AppMonitor.shared.startMonitoring()
                // Find and close the setup window
                for window in NSApp.windows {
                    if window.title == "FaceGate Setup" {
                        window.close()
                    }
                }
            },
            onOpenSettings: {
                AppMonitor.shared.startMonitoring()
                // Close the setup window
                for window in NSApp.windows {
                    if window.title == "FaceGate Setup" {
                        window.close()
                    }
                }
                // Open settings window
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FaceGate Setup"
        window.level = .floating
        window.contentView = NSHostingView(rootView: setupView)
        window.center()
        window.isReleasedWhenClosed = false
        
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        setupWindow = window
    }

    // MARK: - Sleep / Lock Handling

    @objc private func systemWillSleep() {
        guard UserDefaults.standard.bool(forKey: FGConstants.lockOnSleepKey) else { return }
        SessionManager.shared.revokeAllSessions()
    }

    private func syncUninstallProtection() {
        let shouldProtect = UserDefaults.standard.bool(forKey: FGConstants.uninstallProtectionKey)
        let bundleURL = Bundle.main.bundleURL
        
        do {
            let resourceValues = try bundleURL.resourceValues(forKeys: [.isUserImmutableKey])
            let currentImmutable = resourceValues.isUserImmutable ?? false
            if currentImmutable != shouldProtect {
                try? (bundleURL as NSURL).setResourceValue(shouldProtect, forKey: .isUserImmutableKey)
                print("[FaceGate] Synced bundle immutable state to \(shouldProtect).")
            }
        } catch {
            print("[FaceGate] Failed to sync uninstall protection on launch: \(error)")
        }
    }
}

// MARK: - Sparkle Updater Delegate

extension AppDelegate: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nsError = error as NSError
        guard nsError.domain == SUSparkleErrorDomain,
              nsError.code == 4012,
              UserDefaults.standard.bool(forKey: FGConstants.uninstallProtectionKey) else { return }

        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Update Failed — Uninstall Protection Is On"
            alert.informativeText = "FaceGate's uninstall protection prevents the app bundle from being modified. To update, disable Uninstall Protection in Settings → Advanced, then check for updates again."
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}

private final class SettingsSidebarToggleTarget: NSObject {
    private let chromeState: SettingsChromeState

    init(chromeState: SettingsChromeState) {
        self.chromeState = chromeState
    }

    @objc func toggleSidebar() {
        chromeState.isSidebarCollapsed.toggle()
    }
}
