# Developer Guide

## Project Structure

```
FaceGate-Mac/
├── FaceGate/                          # Main app target
│   ├── App/                           # App entry points
│   │   ├── FaceGateApp.swift          # SwiftUI app entry, scene phase monitoring
│   │   └── AppDelegate.swift          # NSApplicationDelegate (menu bar, NSWindow management, AX observer)
│   ├── Auth/                          # Lock/unlock logic per app
│   │   ├── AppAuthManager.swift       # Central auth coordinator (lock/unlock requests, session timers)
│   │   ├── AppLockState.swift         # Per-app lock state model (locked, unlocked, timer expiry)
│   │   └── AppListManager.swift       # Manages list of locked apps (add/remove, permission checks)
│   ├── Camera/                        # Camera pipeline
│   │   ├── CameraManager.swift        # AVCaptureSession lifecycle, camera permissions, frame dispatch
│   │   ├── CameraViewModel.swift      # ObservableObject for SwiftUI camera preview binding
│   │   └── FrameProcessor.swift       # Processes CMSampleBuffer → CVPixelBuffer for ML pipeline
│   ├── Face/                          # Face detection & recognition
│   │   ├── AuthFaceDetector.swift     # Apple Vision face detection, tracks face state (present/absent)
│   │   ├── FaceEmbedder.swift         # MobileFaceNet Core ML inference → 512-dim embedding
│   │   ├── FaceMatchManager.swift     # Core: similarity scores, thresholding, liveness-gated authentication
│   │   ├── FaceStorageManager.swift   # AES-256-GCM encrypt/decrypt, CRUD of enrolled embeddings on disk
│   │   ├── LivenessDetector.swift     # Head-pose challenge (yaw/pitch) for spoof resistance
│   │   └── LivenessChallenge.swift    # Challenge model: random sequence of turn left/right/straight
│   ├── Keychain/                      # Secure storage
│   │   └── KeychainManager.swift      # Keychain wrapper (token CRUD, SHA-256 password hashing)
│   ├── LockScreen/                    # Full-screen lock UI
│   │   ├── LockScreenView.swift       # SwiftUI lock screen (face/preview/Touch ID/password tabs)
│   │   └── LockScreenManager.swift    # Lock screen lifecycle (show/dismiss, run-loop observer for re-lock)
│   ├── ML/                            # Machine learning assets
│   │   ├── MobileFaceNet.mlpackage/   # Core ML model bundle
│   │   └── README.md                  # ML model documentation
│   ├── MenuBar/                       # Menu bar interface
│   │   └── MenuBarManager.swift       # NSMenu construction, state observation, global hotkey registration
│   ├── Monitor/                       # System monitoring
│   │   ├── AppLaunchMonitor.swift     # NSWorkspace observing NSWorkspaceDidLaunchApplicationNotification
│   │   ├── LockedAppMonitor.swift     # Periodic NSWorkspace.runningApplications scan for locked apps
│   │   ├── ScreenSleepMonitor.swift   # CGDisplayRegisterReconfigurationCallback + NSWorkspace sleep notifications
│   │   └── AXObserverManager.swift    # Accessibility observer for NSWindow visibility changes
│   ├── Persistence/                   # Data & configuration persistence
│   │   └── AppPersistenceManager.swift# JSON-file-based locked-app list, scheduled lock/unlock, app-settings persistence
│   ├── Preferences/                   # Settings UI
│   │   ├── ContentView.swift          # Root SwiftUI view (List of locked apps, add/remove row actions)
│   │   ├── AddAppSheetView.swift      # Sheet to browse and add applications
│   │   ├── SettingsDetailFlow.swift   # Per-app settings view (timer, lock-on-sleep, scheduled lock/unlock)
│   │   ├── PreferencesView.swift      # Global preference toggles (launch at login, hotkey, etc.)
│   │   └── FaceSetupView.swift        # Enrollment UI (capture face images, build reference embeddings)
│   ├── Protocols/                     # Abstraction protocols
│   │   └── Protocols.swift            # FaceMatchManaging, AppAuthManaging, LockScreenManaging, CameraManaging, etc.
│   ├── Utils/                         # Utilities
│   │   ├── Constants.swift            # App-wide constants (thresholds, hotkey defaults, file paths)
│   │   ├── Extensions.swift           # Swift extensions (CVPixelBuffer, Data, NSImage, etc.)
│   │   ├── LockscreenOverlayWindow.swift # NSWindow subclass for full-screen lock overlay
│   │   ├── NSApplication+AXPermission.swift  # Accessibility permission helpers
│   │   └── NSWorkspace+Apps.swift     # NSWorkspace app enumeration helpers
│   ├── Supporting Files/
│   │   ├── Info.plist                 # Bundle configuration, usage descriptions, LSUIElement
│   │   └── FaceGate.entitlements      # Sandbox exemptions, Keychain, SIP-policy bypass
│   └── Assets.xcassets/               # App icon and asset catalog
├── non-app-assets/                    # Marketing & non-app resources
│   └── lg1.png                        # App logo for README
├── opencode.json                      # opencode agent configuration
├── README.md                          # User-facing documentation
├── developer.md                       # This file
├── install.sh                         # Automated install script
├── project.yml                        # XcodeGen project specification
├── Package.resolved                   # SPM dependency lockfile
└── FaceGate.xcodeproj/                # Generated Xcode project
```

---

## Architecture Overview

FaceGate follows a **coordinator pattern** built on protocols with `@MainActor` concurrency.

### Core Auth Flow

```
App Launch Monitor ──► Lock Screen Manager ──► Camera Pipeline
       │                       │                     │
       ▼                       ▼                     ▼
   LockedApp? ──►  Face/Liveness/PIN/TouchID     Frame Dispatch
       │                       │                     │
       └─────── Auth Result ───┴──► Unlock or Kill
```

1. **`AppLaunchMonitor`** observes `NSWorkspaceDidLaunchApplicationNotification`. If the launched app is in the locked list, it immediately terminates it (SIGKILL) and triggers the lock screen.
2. **`LockScreenManager`** shows a full-screen, level-floating `NSPanel` that captures all input. It has three auth tabs: **Face**, **PIN**, **Touch ID**.
3. On switch to the **Face** tab, `CameraManager` starts the `AVCaptureSession` and delivers frames to `FrameProcessor` → `AuthFaceDetector` (Vision) → `FaceEmbedder` (Core ML) → `FaceMatchManager` (cosine similarity vs stored embeddings).
4. **`LivenessDetector`** interposes a head-pose challenge after the face is detected, requiring the user to follow random direction prompts before matching proceeds.
5. On match success, the lock screen dismisses, the app window is brought forward, and an **unlock session timer** starts.
6. On failure or timeout, the app stays locked.

### Lock Screen Re-Lock Mechanism

`LockScreenManager` installs a `CFRunLoopObserver` that fires on every main run-loop iteration. If the lock screen is dismissed (e.g. via PID mismatch, unexpected close), the observer instantly re-shows it.

### AX Observer

When the unlock succeeds, `AXObserverManager` watches the unlocked app's `kAXFocusedWindowChangedNotification` and `kAXApplicationActivatedNotification` to detect `NSWindow` visibility changes. If the last visible window closes, the app is re-locked.

---

## Key Design Decisions

### Menubar-Only (LSUIElement)
The app is `LSUIElement` (`Application is agent` = `YES` in Info.plist). No Dock icon. All interaction is through the menu bar item and the lock screen overlay window.

### App Termination (Not Hiding)
When `AppLaunchMonitor` catches a locked app launch, it sends `SIGKILL` to terminate the process. The lock screen then monitors for the user to authenticate, at which point it launches the app normally via `NSWorkspace.shared.openApplication`.

### Face Embedding Storage
Reference embeddings are stored as 512 `Float32` values → `Data` → AES-256-GCM encrypted → written to a JSON file in `~/Library/Application Support/FaceGate/`. The encryption key is stored in the Keychain.

### Protocol-Based Abstraction
`FaceGate/Protocols/Protocols.swift` defines protocols like `FaceMatchManaging`, `AppAuthManaging`, `LockScreenManaging`, etc. The concrete implementations (`FaceMatchManager`, `AppAuthManager`, `LockScreenManager`) conform to these, making the system testable and swappable.

---

## Building

### Prerequisites

```bash
brew install xcodegen
```

### Generate & Build

```bash
xcodegen generate         # Generates FaceGate.xcodeproj from project.yml
open FaceGate.xcodeproj   # Open in Xcode
```

Select a development team in **Signing & Capabilities** and build with `Cmd+B`.

### Code Signing

The entitlements file (`FaceGate.entitlements`) includes:

- `com.apple.security.device.camera` — camera access
- `com.apple.security.device.microphone` — unused but declared
- `com.apple.security.personal-information.location` — unused but declared
- `com.apple.security.cs.disable-library-validation` — allows loading unsigned frameworks
- `com.apple.security.cs.allow-unsigned-executable-memory` — JIT for ML runtime
- `com.apple.security.temporary-exception.apple-events` — allows `nsopen` on locked apps
- `com.apple.security.temporary-exception.apple-events.set-frontmost` — bring locked apps to front
- `com.apple.security.cs.allow-dyld-environment-variables` — DYLD_INSERT_LIBRARIES for testing
- `com.apple.security.temporary-exception.sbpl` — Seatbelt exception for process enumeration

For distribution, a Developer ID certificate is required (not a development team cert).

---

## Dependencies

FaceGate has **no external Swift Package dependencies**. The entire app uses Apple SDKs:

| Framework | Purpose |
|-----------|---------|
| SwiftUI | Preferences UI, Lock Screen UI |
| AppKit | Menu bar, NSWindow management, NSWorkspace monitoring |
| AVFoundation | Camera capture session |
| Vision | Face detection, face capture quality, face landmarks |
| CoreMedia / CoreVideo | Pixel buffer handling |
| CoreImage | CIImage filtering, head-pose estimation |
| Core ML | Face embedding inference |
| LocalAuthentication | Touch ID |
| Security | Keychain services |
| CryptoKit | AES-256-GCM encryption |

---

## Testing

The project targets macOS 14.0+ with Swift 5.9 concurrency (async/await, @MainActor, Sendable).

Current testing state: **No unit or UI tests are implemented.** Test targets can be added to `project.yml` and should use `XCTest`. The protocol-based design makes it straightforward to inject mock implementations:

```swift
class MockFaceMatchManager: FaceMatchManaging {
    func startVerification() async throws -> FaceMatchResult {
        return .success(embedding: .init())
    }
}
```

---

## Contribution Guidelines

1. **Use protocols.** New features should accept protocol conformances rather than concrete types.
2. **Run `xcodegen generate`** after modifying `project.yml`.
3. **Keep the app offline.** No networking code — FaceGate is a zero-telemetry app.
4. **Maintain LSUIElement.** The app must not show a Dock icon.
5. **Test on a real Mac.** Face unlock needs a physical camera.
6. **Avoid new dependencies.** Prefer Apple SDKs over external packages.

---

## Common Development Tasks

### Adding a New Lock Method

1. Add a new case to a method enum (e.g. `LockMethod.face`, `.pin`, `.touchID`).
2. Create the corresponding auth UI tab in `LockScreenView.swift`.
3. Wire the auth result back through `FaceMatchManaging` or add a new protocol method.
4. Update `LockScreenManager` to fall through to the new method if previous ones fail.

### Adding a New System Monitor

1. Create a class in `FaceGate/Monitor/` that observes the relevant notification/event.
2. Add a protocol method in `Protocols.swift` if the monitor needs to report state.
3. Wire it into `AppDelegate.swift` or `AppAuthManager` depending on scope.

### Modifying the ML Model

See `FaceGate/ML/README.md` for the conversion pipeline from InsightFace's ONNX to Core ML.

---

## Resources

- [InsightFace](https://github.com/deepinsight/insightface) — MobileFaceNet training pipeline
- [Core ML Tools](https://coremltools.readme.io/) — ONNX → Core ML conversion
- [Apple Vision Framework](https://developer.apple.com/documentation/vision) — Face detection
- [LocalAuthentication](https://developer.apple.com/documentation/localauthentication) — Touch ID
