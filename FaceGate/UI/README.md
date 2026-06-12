# User Interface

The `UI` module handles everything the user interacts with, built primarily using SwiftUI with AppKit bridging for specific macOS windowing behaviors.

## Key Views

- **`AuthOverlayPanel` & `AuthOverlayView`**: The most critical UI component. This is a custom `NSPanel` subclass configured to hover above all other windows (`NSWindow.Level.screenSaver`) to block access to the underlying app while presenting the authentication challenge.
- **`MenuBarView`**: The agent interface. FaceGate runs without a Dock icon; this view handles the menu bar popover for quick actions.
- **`FaceEnrollmentView`**: The onboarding camera interface that captures reference frames for the embedding model.
- **`SettingsView`**: The standard multi-tab preferences window.

## AppKit vs SwiftUI

While views are written in SwiftUI, we rely on AppKit (`NSApp`, `NSPanel`, `NSWorkspace`) for process-level control and advanced window management. Standard SwiftUI `WindowGroup` is insufficient for the high-level security overlay required by an app locker.
