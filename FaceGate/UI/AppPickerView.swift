import SwiftUI

/// View for selecting which installed apps to lock.
/// Shows a searchable grid of installed apps with toggle switches.
struct AppPickerView: View {
    @ObservedObject var lockedAppsManager = LockedAppsManager.shared
    @State private var installedApps: [InstalledAppsScanner.DiscoveredApp] = []
    @State private var searchText: String = ""
    @State private var isLoading = true

    /// Set of bundle IDs that are currently locked.
    private var lockedBundleIDs: Set<String> {
        Set(lockedAppsManager.lockedApps.map { $0.bundleIdentifier })
    }

    private var filteredApps: [InstalledAppsScanner.DiscoveredApp] {
        if searchText.isEmpty {
            return installedApps
        }
        return installedApps.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar.
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search apps…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            if isLoading {
                Spacer()
                ProgressView("Scanning installed apps…")
                    .progressViewStyle(.circular)
                Spacer()
            } else if filteredApps.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No apps found")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                // App list.
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredApps) { app in
                            AppRow(
                                app: app,
                                isLocked: lockedBundleIDs.contains(app.bundleIdentifier),
                                onToggle: { toggleApp(app) }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear {
            loadApps()
        }
    }

    // MARK: - Private

    private func loadApps() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = InstalledAppsScanner.shared.scanInstalledApps()
            DispatchQueue.main.async {
                installedApps = apps
                isLoading = false
            }
        }
    }

    private func toggleApp(_ app: InstalledAppsScanner.DiscoveredApp) {
        if lockedBundleIDs.contains(app.bundleIdentifier) {
            lockedAppsManager.unlockApp(app.bundleIdentifier)
        } else {
            let startTime = Date()
            DispatchQueue.global(qos: .userInitiated).async {
                let lockedApp = InstalledAppsScanner.shared.toLockedApp(app, isLocked: true)
                let elapsed = Date().timeIntervalSince(startTime)
                let remainingDelay = max(0, 0.20 - elapsed)
                DispatchQueue.main.asyncAfter(deadline: .now() + remainingDelay) {
                    withAnimation(.spring(response: 0.18, dampingFraction: 0.8, blendDuration: 0)) {
                        lockedAppsManager.lockApp(lockedApp)
                    }
                }
            }
        }
    }
}

// MARK: - App Row

private struct AppRow: View {
    let app: InstalledAppsScanner.DiscoveredApp
    let isLocked: Bool
    let onToggle: () -> Void

    @State private var isHovered = false
    @State private var isLockedState = false
    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 12) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(app.bundleIdentifier)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: $isLockedState)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .allowsHitTesting(!isProcessing)
                .onChangeCompat(of: isLockedState) { newValue in
                    guard !isProcessing else { return }
                    if newValue != isLocked {
                        isProcessing = true
                        if !newValue { // Unlocking
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                onToggle()
                            }
                        } else { // Locking
                            onToggle()
                        }
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
        .onAppear {
            isLockedState = isLocked
        }
        .onChangeCompat(of: isLocked) { newValue in
            isLockedState = newValue
            isProcessing = false
        }
    }
}
