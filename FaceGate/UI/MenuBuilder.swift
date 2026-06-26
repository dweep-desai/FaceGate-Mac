import AppKit
import SwiftUI

@MainActor
class MenuBuilder: NSObject, NSMenuDelegate {
    
    // Shared state variables that need to be accessible
    private var disableTimer: Timer?
    private var isTemporarilyDisabled = false
    private var disableTimeRemaining: TimeInterval = 0
    
    // We will keep a reference to the disable item so we can update its title dynamically
    private var disableMenuItem: NSMenuItem?
    
    override init() {
        super.init()
        checkTemporaryDisable()
    }
    
    func buildMenu() -> NSMenu {
        let menu = NSMenu(title: "FaceGate")
        menu.delegate = self
        // Pre-populate so it's not totally empty on first click before delegate fires
        populateMenu(menu)
        return menu
    }
    
    nonisolated func menuNeedsUpdate(_ menu: NSMenu) {
        // AppKit calls menuNeedsUpdate on the main thread right before display.
        // We MUST populate the menu synchronously to prevent the visual glitch 
        // where the menu animates open while the async task is still swapping items.
        MainActor.assumeIsolated {
            self.populateMenu(menu)
        }
    }
    
    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        
        // 1. Header View
        let headerItem = createMenuItem(view: MenuHeaderView(builder: self))
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Locked Apps View (ScrollView of apps)
        let appsItem = createMenuItem(view: MenuLockedAppsView(builder: self))
        menu.addItem(appsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Quick Actions
        
        // Temporarily Disable
        let disableItem = NSMenuItem(
            title: isTemporarilyDisabled ? "Resume Protection (\(formattedTimeRemaining))" : "Disable for 5 min",
            action: #selector(toggleTemporaryDisable),
            keyEquivalent: ""
        )
        // Add icon
        disableItem.image = NSImage(systemSymbolName: isTemporarilyDisabled ? "play.circle" : "pause.circle", accessibilityDescription: nil)
        disableItem.target = self
        self.disableMenuItem = disableItem
        menu.addItem(disableItem)
        
        // Re-lock all
        let relockItem = NSMenuItem(
            title: "Re-lock All Apps",
            action: #selector(relockAllApps),
            keyEquivalent: ""
        )
        relockItem.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
        relockItem.target = self
        menu.addItem(relockItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Check for Updates
        let updatesItem = NSMenuItem(
            title: "Check for Updates",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updatesItem.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
        updatesItem.target = self
        menu.addItem(updatesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.image = NSImage(systemSymbolName: "gearshape.fill", accessibilityDescription: nil)
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit FaceGate",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
        quitItem.target = self
        menu.addItem(quitItem)
    }
    
    // MARK: - State Management
    
    var isProtectionPaused: Bool {
        return isTemporarilyDisabled
    }
    
    private var formattedTimeRemaining: String {
        let minutes = Int(disableTimeRemaining) / 60
        let seconds = Int(disableTimeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    @objc private func toggleTemporaryDisable() {
        if isTemporarilyDisabled {
            UserDefaults.standard.set(false, forKey: FGConstants.protectionDisabledKey)
            UserDefaults.standard.removeObject(forKey: FGConstants.protectionDisableExpiryKey)
            isTemporarilyDisabled = false
            disableTimer?.invalidate()
            SessionManager.shared.revokeAllSessions()
            updateDisableMenuItem()
        } else {
            ActionAuthWindow.show(reason: "Disable Protection") {
                DispatchQueue.main.async {
                    let expiry = Date().addingTimeInterval(300)
                    UserDefaults.standard.set(true, forKey: FGConstants.protectionDisabledKey)
                    UserDefaults.standard.set(expiry, forKey: FGConstants.protectionDisableExpiryKey)
                    self.isTemporarilyDisabled = true
                    self.disableTimeRemaining = 300
                    self.startDisableCountdown()
                    self.updateDisableMenuItem()
                }
            }
        }
    }
    
    @objc private func relockAllApps() {
        SessionManager.shared.revokeAllSessions()
        if isTemporarilyDisabled {
            UserDefaults.standard.set(false, forKey: FGConstants.protectionDisabledKey)
            UserDefaults.standard.removeObject(forKey: FGConstants.protectionDisableExpiryKey)
            isTemporarilyDisabled = false
            disableTimer?.invalidate()
            updateDisableMenuItem()
        }
    }
    
    private func startDisableCountdown() {
        disableTimer?.invalidate()
        disableTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.disableTimeRemaining -= 1
                if self.disableTimeRemaining <= 0 {
                    self.isTemporarilyDisabled = false
                    UserDefaults.standard.set(false, forKey: FGConstants.protectionDisabledKey)
                    self.disableTimer?.invalidate()
                    SessionManager.shared.revokeAllSessions()
                }
                self.updateDisableMenuItem()
                NotificationCenter.default.post(name: .menuStateDidChange, object: nil)
            }
        }
    }
    
    private func checkTemporaryDisable() {
        if UserDefaults.standard.bool(forKey: FGConstants.protectionDisabledKey),
           let expiry = UserDefaults.standard.object(forKey: FGConstants.protectionDisableExpiryKey) as? Date {
            let remaining = expiry.timeIntervalSinceNow
            if remaining > 0 {
                isTemporarilyDisabled = true
                disableTimeRemaining = remaining
                startDisableCountdown()
            } else {
                UserDefaults.standard.set(false, forKey: FGConstants.protectionDisabledKey)
                UserDefaults.standard.removeObject(forKey: FGConstants.protectionDisableExpiryKey)
                isTemporarilyDisabled = false
                SessionManager.shared.revokeAllSessions()
            }
        } else {
            isTemporarilyDisabled = false
        }
    }
    
    private func updateDisableMenuItem() {
        guard let item = disableMenuItem else { return }
        item.title = isTemporarilyDisabled ? "Resume Protection (\(formattedTimeRemaining))" : "Disable for 5 min"
        item.image = NSImage(systemSymbolName: isTemporarilyDisabled ? "play.circle" : "pause.circle", accessibilityDescription: nil)
    }
    
    @objc private func checkForUpdates() {
        AppDelegate.shared?.updaterController?.updater.checkForUpdates()
    }
    
    @objc private func openSettings() {
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
    
    @objc private func quitApplication() {
        let appDelegate = AppDelegate.shared
        let isSettingsOpen = appDelegate?.isSettingsWindowVisible ?? false
        if isSettingsOpen {
            NSApplication.shared.terminate(nil)
        } else {
            ActionAuthWindow.show(reason: "Quit FaceGate") {
                appDelegate?.isAuthorizedToQuit = true
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    // MARK: - Helper
    
    private let menuWidth: CGFloat = 280
    
    private func createMenuItem<V: View>(view: V) -> NSMenuItem {
        let hostingView = NSHostingView(rootView: view)
        let height = hostingView.fittingSize.height
        hostingView.frame = NSRect(
            x: 0,
            y: 0,
            width: menuWidth,
            height: height
        )
        
        let menuItem = NSMenuItem()
        menuItem.view = hostingView
        return menuItem
    }
}

extension Notification.Name {
    static let menuStateDidChange = Notification.Name("com.dweep.FaceGate.menuStateDidChange")
    static let openSettings = Notification.Name("com.dweep.FaceGate.openSettings")
    static let openSetup = Notification.Name("com.dweep.FaceGate.openSetup")
}
