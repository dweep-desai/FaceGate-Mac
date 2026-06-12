# FaceGate

FaceGate is a native, open-source macOS utility that introduces application-level locking backed by on-device face recognition. It intercepts application launches and requires authentication—via face recognition, Touch ID, or a secure fallback password—before granting access.

macOS natively lacks the ability to restrict individual applications. FaceGate bridges this gap, offering a frictionless authentication layer for sensitive apps like Mail, Messages, or password managers.

## Capabilities

- **Application Locking**: Intercepts app launches in real-time, preventing access until authenticated.
- **On-Device Face Recognition**: Uses a software-based face embedding pipeline that runs entirely on your Mac for privacy-preserving face matching.
- **Fallback Authentication**: Seamless integration with Touch ID and a custom encrypted PIN as secure alternatives.
- **Menu Bar Agent**: Runs quietly in the background without cluttering the Dock.
- **Zero Telemetry**: Fully offline. Face data is mathematically embedded, encrypted, and never leaves your device.

## Security Architecture & Threat Model

**Disclaimer**: FaceGate uses the built-in 2D FaceTime camera. It is not equivalent to Apple's Face ID and lacks depth-sensing hardware. It is designed as a convenience layer against casual physical access, not to thwart targeted attacks using high-fidelity spoofing.

For maximum security, rely on the Touch ID or password fallbacks.

- **Face Embeddings**: FaceGate does not store images. It extracts a 128-dimensional embedding vector from cropped face images, which is AES-256 encrypted and stored in the local filesystem.
- **App Interception**: The daemon monitors `NSWorkspace` for process execution. When a locked app is launched, FaceGate immediately suppresses its window and overlays an un-dismissible, high-level `NSPanel` for authentication.
- **Local Authentication**: Touch ID integration uses standard `LocalAuthentication` frameworks, while the fallback password utilizes salted SHA-256 hashes stored in the macOS Keychain.

## Technical Foundation

- **Language**: Swift 5.9+
- **UI**: SwiftUI & AppKit
- **Face Recognition**: Built-in software embedder (128-dim vectors) with optional Core ML upgrade path (MobileFaceNet on ANE)
- **Computer Vision**: Apple Vision Framework (`VNDetectFaceRectanglesRequest`, `VNDetectFaceCaptureQualityRequest`)
- **Media**: AVFoundation for real-time sample buffer processing
- **Security**: CryptoKit (AES-256-GCM), macOS Keychain, Accelerate (vDSP)

## Installation

### Automated Install (Recommended)

You can download and install the latest compiled release automatically. This script downloads the binary and strips the quarantine attribute to bypass Gatekeeper's unnotarized warnings seamlessly.

```bash
curl -fsSL https://raw.githubusercontent.com/dweep-desai/FaceGate-Mac/main/install.sh | bash
```

### Manual Install

1. Download the latest `.dmg` from the [Releases](https://github.com/dweep-desai/FaceGate-Mac/releases) page.
2. Mount the volume and drag `FaceGate.app` to `/Applications`.
3. To open for the first time, right-click `FaceGate.app`, select **Open**, and acknowledge the Gatekeeper warning.

## Local Development

FaceGate is built using XcodeGen to maintain a clean Git history and reproducible project files.

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build Instructions

1. Clone the repository:
   ```bash
   git clone https://github.com/dweep-desai/FaceGate-Mac.git
   cd FaceGate-Mac
   ```
2. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
3. Open `FaceGate.xcodeproj` and build the target using `Cmd+B` or run with `Cmd+R`.

*Note: You may need to update the signing configuration in Xcode to use your personal developer team.*

### Creating a DMG for Distribution

```bash
make dmg
```

This generates, archives, and packages the app into `build/FaceGate.dmg` — ready for end users.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

*Authored by Dweep Desai*