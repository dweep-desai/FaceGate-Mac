# Release Process

This document describes the exact steps to release a new version of FaceGate and cast it via Sparkle.

---

## Prerequisites

- **Xcode** installed
- **xcodegen** installed (`brew install xcodegen`)
- **Sparkle** CLI tools installed (`brew install sparkle`)
- **Developer ID certificate** for distribution (optional — ad-hoc works for testing)
- The **Sparkle EdDSA private key** (`releases/sparkle_private.pem`) — **keep this safe and never commit it**

---

## Step-by-Step

### 1. Update Version

Edit `project.yml` and bump `MARKETING_VERSION` and/or `CURRENT_PROJECT_VERSION`:

```yaml
MARKETING_VERSION: "1.1.0"       # user-visible version
CURRENT_PROJECT_VERSION: "2"     # build number, increment each release
```

### 2. Generate Xcode Project

```bash
xcodegen generate
```

### 3. Build the App (without RAM spike)

```bash
# 3a. Extract pre-compiled model from the previous DMG
hdiutil attach -nobrowse -mountpoint /tmp/fg_mnt FaceGate-1.0.0.dmg
cp -R /tmp/fg_mnt/FaceGate.app/Contents/Resources/FaceEmbedding.mlmodelc /tmp/
hdiutil detach /tmp/fg_mnt

# 3b. Swap the .mlpackage for the pre-compiled .mlmodelc
mv FaceGate/ML/FaceEmbedding.mlpackage /tmp/FaceEmbedding.mlpackage.bak
cp -R /tmp/FaceEmbedding.mlmodelc FaceGate/ML/

# 3c. Copy the generated Swift wrapper
# Find the FaceEmbedding.swift from a previous build:
# build/DerivedData/.../DerivedSources/CoreMLGenerated/FaceEmbedding/FaceEmbedding.swift
# Copy it to FaceGate/ML/FaceEmbedding.swift

# 3d. Update project.yml to exclude mlpackage and include mlmodelc
#     sources -> excludes -> add "**/FaceEmbedding.mlpackage"
#     resources -> add "FaceGate/ML/FaceEmbedding.mlmodelc"

# 3e. Generate and build
xcodegen generate
xcodebuild -project FaceGate.xcodeproj -scheme FaceGate -configuration Release build

# 3f. Restore project.yml and source tree
rm -rf FaceGate/ML/FaceEmbedding.mlmodelc
rm -f FaceGate/ML/FaceEmbedding.swift
mv /tmp/FaceEmbedding.mlpackage.bak FaceGate/ML/FaceEmbedding.mlpackage
git checkout project.yml
```

### 4. Create the DMG

```bash
make dmg
```

The DMG is at `build/FaceGate.dmg`.

### 5. Sign the Update Archive

```bash
/opt/homebrew/Caskroom/sparkle/2.9.3/bin/sign_update \
  -f releases/sparkle_private.pem \
  build/FaceGate.dmg
```

This outputs a signature like:
```
sparkle:edSignature="ABCDEF..."
```
Save the signature text (everything after `sparkle:`).

### 6. Upload the DMG

Upload `build/FaceGate.dmg` to a GitHub Release at:
https://github.com/dweep-desai/FaceGate-Mac/releases

The download URL will be:
```
https://github.com/dweep-desai/FaceGate-Mac/releases/download/v1.1.0/FaceGate.dmg
```

### 7. Update the Appcast

Edit `releases/appcast.xml`. Add a new `<item>`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>FaceGate Changelog</title>
    <description>Most recent changes to FaceGate.</description>
    <language>en</language>
    <item>
      <title>Version 1.1.0</title>
      <description><![CDATA[
        <ul>
          <li>What's new in this release</li>
          <li>Bug fixes</li>
        </ul>
      ]]></description>
      <pubDate>Mon, 01 Jan 2026 00:00:00 +0000</pubDate>
      <enclosure
        url="https://github.com/dweep-desai/FaceGate-Mac/releases/download/v1.1.0/FaceGate.dmg"
        sparkle:version="2"
        sparkle:shortVersionString="1.1.0"
        sparkle:edSignature="ABCDEF..."
        length="10000000"
        type="application/octet-stream" />
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
    </item>
  </channel>
</rss>
```

Key enclosure fields:

| Field | Value |
|-------|-------|
| `url` | GitHub Release download URL |
| `sparkle:version` | `CURRENT_PROJECT_VERSION` (build number) |
| `sparkle:shortVersionString` | `MARKETING_VERSION` |
| `sparkle:edSignature` | output from `sign_update` step |
| `length` | file size in bytes (`stat -f%z build/FaceGate.dmg`) |
| `type` | `application/octet-stream` |

`pubDate` format: RFC 2822 (`date -R`).

### 8. Commit and Push

```bash
git add project.yml releases/appcast.xml
git commit -m "Bump version to 1.1.0"
git tag v1.1.0
git push && git push --tags
```

### 9. Create GitHub Release

1. Go to https://github.com/dweep-desai/FaceGate-Mac/releases
2. Click **Draft a new release**
3. Tag: `v1.1.0`
4. Title: `v1.1.0`
5. Write release notes
6. Attach `build/FaceGate.dmg`
7. Publish

Users will be prompted to update via the app's "Check for Updates" menu item within 24 hours (or immediately on manual check).

---

## Appcast Hosting

The appcast is served from `releases/appcast.xml` via GitHub's raw CDN:

```
https://raw.githubusercontent.com/dweep-desai/FaceGate-Mac/main/releases/appcast.xml
```

This URL is set in `Info.plist` -> `SUFeedURL`. No hosting setup needed — just commit the updated `appcast.xml` to `main`.

---

## Core ML RAM Spike Workaround

`coremlc` (Core ML compiler) uses 30 GB+ RAM and can force-shutdown your Mac.

**The fix:** Replace the `.mlpackage` with the pre-compiled `.mlmodelc` from the last DMG before building. The mlmodelc is architecture-specific (arm64) but works universally on Apple Silicon Macs. The detailed steps are in section 3 above.

