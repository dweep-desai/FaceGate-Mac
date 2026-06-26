import AppKit
import SwiftUI

// MARK: - Custom Window
class SettingsWindow: NSWindow {
    private var toolbarObserver: NSKeyValueObservation?
    
    override var toolbar: NSToolbar? {
        didSet {
            toolbarObserver?.invalidate()
            toolbarObserver = toolbar?.observe(\.showsBaselineSeparator, options: [.initial, .new]) { toolbar, _ in
                if toolbar.showsBaselineSeparator {
                    toolbar.showsBaselineSeparator = false
                }
            }
        }
    }
}

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static var shared: SettingsWindowController?

    /// Returns true if the settings window is currently open and visible.
    static var isVisible: Bool {
        return shared?.window?.isVisible == true
    }

    /// Show the settings window, optionally jumping to a specific tab.
    static func show(tab: SettingsTab? = nil) {
        if let tab {
            SettingsNavigation.shared.selectedTab = tab
        }

        if shared == nil {
            shared = SettingsWindowController()
        }

        shared?.showWindow(nil)
    }

    private init() {
        let window = SettingsWindow(
            contentRect: NSRect(origin: .zero, size: CGSize(width: 850, height: 620)),
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .miniaturizable,
                .fullSizeContentView,  // Required for liquid glass rounded corners
            ],
            backing: .buffered,
            defer: false
        )

        super.init(window: window)
        configureWindow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureWindow() {
        guard let window else { return }

        window.title = "Settings"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.titlebarSeparatorStyle = .none
        window.toolbarStyle = .automatic
        window.isMovableByWindowBackground = true
        window.setFrameAutosaveName("FaceGateSettingsWindow")
        window.minSize = NSSize(width: 700, height: 500)
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenPrimary]
        
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) {
            let x = screen.frame.midX - window.frame.width / 2
            let y = screen.frame.midY - window.frame.height / 2
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
        
        window.delegate = self
        window.isReleasedWhenClosed = false

        let hostingController = NSHostingController(rootView: SettingsView())
        window.contentViewController = hostingController
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        Self.shared = nil
    }
}
