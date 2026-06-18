<p align="center">
  <img src="non-app-assets/logos/square_icon.png" width="128" alt="FaceGate Logo"/>
</p>

<h1 align="center">FaceGate</h1>
<p align="center"><em>Application-level locking with on-device face recognition for macOS. Stronger than any other Mac app-locker.</em></p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014.0%2B-000000?style=flat-square" alt="Platform"/>
  <img src="https://img.shields.io/badge/swift-5.9%2B-F5A623?style=flat-square" alt="Swift"/>
  <img src="https://img.shields.io/github/license/dweep-desai/FaceGate-Mac?style=flat-square" alt="License"/>
  <img src="https://img.shields.io/github/stars/dweep-desai/FaceGate-Mac?style=flat-square&color=F5A623" alt="Stars"/>
  <img src="https://img.shields.io/github/v/release/dweep-desai/FaceGate-Mac?style=flat-square" alt="Release"/>
  <img src="https://img.shields.io/github/downloads/dweep-desai/FaceGate-Mac/total?style=flat-square" alt="Downloads"/>
  <img src="https://hits.seeyoufarm.com/api/count/incr/badge.svg?url=https%3A%2F%2Fgithub.com%2Fdweep-desai%2FFaceGate-Mac&count_bg=%2379C83D&title_bg=%23555555&title=views&edge_flat=true" alt="Views"/>
</p>

<p align="center">
  <img src="non-app-assets/logos/banner.png" alt="FaceGate Banner" width="100%"/>
</p>

---

FaceGate is a native macOS utility that brings app-level locking with FaceUnlock to your Mac. Lock sensitive applications behind FaceUnlock, Touch ID, or a secure password — all processed entirely on-device with zero telemetry.

macOS natively lacks the ability to restrict individual applications. Although other App-lockers exist, none of them use face recognition and are not as feature rich as FaceGate. 

All controls in your hands - 100% free & open source , 100% malware free , 100% local . 

---

## Features

- **App Locking** — Lock any installed app. FaceGate intercepts launches in real-time and prevents access until authenticated.
- **On-Device Face Recognition** — Software-based face embedding pipeline running entirely on your Mac via the Apple Neural Engine. No cloud, no data leaving your device.
- **Liveness Detection** — Head-pose challenges (turn left, turn right, tilt) to prevent photo and video spoofing.
- **Touch ID** — Seamless integration with macOS Touch ID.
- **Password** — Encrypted PIN stored in the macOS Keychain.
- **Per-App Session Timers** — Customizable unlock duration per app, including "Keep Unlocked Indefinitely." and "Lock immediately"
- **Lock-on-Sleep** — Automatically lock all apps when your Mac sleeps or the screen locks.
- **Uninstall Protection** — Prevents casual deletion by making the app bundle immutable and requires Admin Privileges to uninstall.
- **Scheduled App-Lock/Unlock** — Time-based auto-lock and auto-unlock windows.
- **FaceUnlock Schedule** — Disable face recognition during specific hours (e.g., when dark or in public spaces) to automatically fallback to Touch ID/Password.
- **Auto-Optimization** — Automatically boost display brightness and trigger Center Stage to improve camera visibility and face detection accuracy.
- **Customizable Sensitivity** — Fine-tune face recognition similarity thresholds to balance convenience and security.
- **Menu Bar Control** — Monitor locked/unlocked apps and lock them directly from the menu bar popup.
- **Secure Operations** — Require authentication to quit the application or configure settings to prevent unauthorized tampering.
- **Emergency Kill Hotkey** — Global keyboard shortcut to instantly terminate.
- **Menu Bar Agent** — Runs silently in the menu bar — no Dock icon, no distractions.

---

## Installation - Give the repo a ⭐️ so you don't miss future updates.

### Recommended: Homebrew

```bash
brew install --cask --no-quarantine dweep-desai/tap/facegate
```

`--no-quarantine` is required because FaceGate is not Apple-notarized (due to a lack of developer funds). This flag prevents Gatekeeper from blocking the app on first launch.

### Or download & install automatically

```bash
curl -fsSL https://raw.githubusercontent.com/dweep-desai/FaceGate-Mac/main/install.sh | bash
```

The script fetches the latest DMG from GitHub Releases, installs it to `/Applications`, and removes the quarantine flag.

### Manual Install

> [!IMPORTANT]
> FaceGate is not Apple-notarized, so simply double-clicking the app will not open it. Follow the steps below.

1. Download the latest `.dmg` from the [Releases](https://github.com/dweep-desai/FaceGate-Mac/releases) page.
2. Mount the volume and drag `FaceGate.app` to `/Applications`.
3. Right-click `FaceGate.app`, select **Open**, and acknowledge the Gatekeeper warning.

---

## Security & Privacy

FaceGate is designed as a **convenience layer against casual physical access**, not a defense against targeted attacks using high-fidelity spoofing. The built-in 2D FaceTime camera lacks depth sensing.

- Face embeddings are AES-256-GCM encrypted and stored locally.
- Encryption keys are held in the macOS Keychain.
- The password uses SHA-256 with a random 32-byte salt, stored in the Keychain.
- **Zero telemetry.** The app is fully offline and makes no network requests.
- Face unlock sensitivity is configurable (default similarity threshold: 0.65).

---

## Requirements

- macOS 14.0 (Sonoma) or later
- A Mac with a built-in or external camera (for face unlock)
- Touch ID-compatible Mac (optional, for Touch ID fallback)

---

## Building from Source

```bash
git clone https://github.com/dweep-desai/FaceGate-Mac.git
cd FaceGate-Mac
brew install xcodegen
xcodegen generate
open FaceGate.xcodeproj
```

Build with `Cmd+B` or `Cmd+R`. You may need to update the signing configuration for your development team.

See [developer.md](developer.md) for the complete technical architecture and contribution guide.

---

## License

MIT License. See [LICENSE](LICENSE).

---

<p align="center"><em>Authored by Dweep Desai</em></p>
