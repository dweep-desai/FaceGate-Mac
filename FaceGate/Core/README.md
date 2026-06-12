# Core Infrastructure

The `Core` module is the beating heart of FaceGate's app monitoring and interception logic.

## Components

- **`AppMonitor`**: Interfaces with `NSWorkspace` to observe application launch events in real-time. It detects when a user attempts to launch a monitored bundle identifier.
- **`AppLocker`**: The enforcement layer. Upon launch detection, it immediately suppresses the target application's visibility (via `NSWorkspace` APIs) and triggers the high-level `NSPanel` authentication overlay.
- **`LockedAppsManager`**: Handles the persistence and retrieval of the user's locked applications list (stored securely in `UserDefaults` or a local plist).
- **`SessionManager`**: Manages the temporal unlock state. After a successful authentication, it maintains a short-lived token allowing the app to remain unlocked without re-prompting the user immediately.

## Architecture Notes

We explicitly avoid the `EndpointSecurity` framework. While ES provides a kernel-level block, it requires special entitlements (`com.apple.developer.endpoint-security.client`) that are inaccessible to open-source forks without Apple's explicit approval. Instead, we use an "observe-and-react" pattern using `NSWorkspace`.
