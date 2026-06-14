import SwiftUI

/// The menu bar popover/dropdown content view.
/// Shows locked apps, quick controls, and access to settings.
struct MenuBarView: View {
    @ObservedObject var lockedAppsManager = LockedAppsManager.shared
    @ObservedObject var appMonitor = AppMonitor.shared
    @ObservedObject var sessionManager = SessionManager.shared

    @State private var showSettings = false
    @State private var isTemporarilyDisabled = false
    @State private var disableTimeRemaining: TimeInterval = 0
    @State private var disableTimer: Timer?

    private var sortedLockedApps: [LockedApp] {
        lockedAppsManager.lockedApps.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header.
            HStack {
                Image(FGConstants.menuBarIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hue: 0.58, saturation: 0.7, brightness: 0.95),
                                     Color(hue: 0.61, saturation: 0.75, brightness: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("FaceGate")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                Spacer()

                // Status indicator.
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Locked apps section.
            if lockedAppsManager.lockedApps.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "lock.open")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                    Text("No apps locked")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Open Settings to lock apps")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(sortedLockedApps) { app in
                            LockedAppRow(
                                app: app,
                                hasActiveSession: isTemporarilyDisabled || sessionManager.hasActiveSession(for: app.bundleIdentifier)
                            )
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }

            Divider()

            // Quick actions.
            VStack(spacing: 2) {
                // Temporarily Disable.
                MenuButton(
                    icon: isTemporarilyDisabled ? "play.circle" : "pause.circle",
                    title: isTemporarilyDisabled ? "Resume Protection (\(formattedTimeRemaining))" : "Disable for 5 min",
                    action: toggleTemporaryDisable
                )

                // Re-lock all.
                MenuButton(
                    icon: "lock.fill",
                    title: "Re-lock All Apps",
                    action: relockAllApps
                )

                Divider()
                    .padding(.vertical, 2)

                // Settings.
                MenuButton(
                    icon: "gearshape.fill",
                    title: "Settings…",
                    action: { openSettings() }
                )

                // Quit (should require auth — simplified for Phase 1).
                MenuButton(
                    icon: "xmark.circle",
                    title: "Quit FaceGate",
                    isDestructive: true,
                    action: { NSApplication.shared.terminate(nil) }
                )
            }
            .padding(.vertical, 4)
        }
        .frame(width: 280, height: 350)
        .onAppear {
            checkTemporaryDisable()
            // If setup was never finished, open the Setup Wizard immediately.
            if !UserDefaults.standard.bool(forKey: FGConstants.setupCompletedKey) {
                NotificationCenter.default.post(name: .openSetup, object: nil)
            } else if !appMonitor.isMonitoring {
                // Failsafe: start monitoring if it somehow got stopped
                appMonitor.startMonitoring()
            }
        }
    }

    // MARK: - Computed

    private var statusColor: Color {
        if isTemporarilyDisabled { return .orange }
        return appMonitor.isMonitoring ? .green : .red
    }

    private var statusText: String {
        if isTemporarilyDisabled { return "Paused" }
        return appMonitor.isMonitoring ? "Active" : "Inactive"
    }

    private var formattedTimeRemaining: String {
        let minutes = Int(disableTimeRemaining) / 60
        let seconds = Int(disableTimeRemaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Actions

    private func toggleTemporaryDisable() {
        if isTemporarilyDisabled {
            // Re-enable protection.
            UserDefaults.standard.set(false, forKey: FGConstants.protectionDisabledKey)
            UserDefaults.standard.removeObject(forKey: FGConstants.protectionDisableExpiryKey)
            isTemporarilyDisabled = false
            disableTimer?.invalidate()
            sessionManager.revokeAllSessions()
        } else {
            // Disable for 5 minutes.
            let expiry = Date().addingTimeInterval(300)
            UserDefaults.standard.set(true, forKey: FGConstants.protectionDisabledKey)
            UserDefaults.standard.set(expiry, forKey: FGConstants.protectionDisableExpiryKey)
            isTemporarilyDisabled = true
            disableTimeRemaining = 300
            startDisableCountdown()
        }
    }

    private func relockAllApps() {
        sessionManager.revokeAllSessions()
        if isTemporarilyDisabled {
            UserDefaults.standard.set(false, forKey: FGConstants.protectionDisabledKey)
            UserDefaults.standard.removeObject(forKey: FGConstants.protectionDisableExpiryKey)
            isTemporarilyDisabled = false
            disableTimer?.invalidate()
        }
    }

    private func startDisableCountdown() {
        disableTimer?.invalidate()
        disableTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            disableTimeRemaining -= 1
            if disableTimeRemaining <= 0 {
                isTemporarilyDisabled = false
                UserDefaults.standard.set(false, forKey: FGConstants.protectionDisabledKey)
                disableTimer?.invalidate()
                sessionManager.revokeAllSessions()
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
                sessionManager.revokeAllSessions()
            }
        } else {
            isTemporarilyDisabled = false
        }
    }

    private func openSettings() {
        // Post a notification to open the settings window.
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }
}

// MARK: - Locked App Row

private struct LockedAppRow: View {
    let app: LockedApp
    let hasActiveSession: Bool

    var body: some View {
        HStack(spacing: 10) {
            AppIconView(iconData: app.iconData, size: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(app.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }

            Spacer()

            LockToggleButton(bundleIdentifier: app.bundleIdentifier, hasActiveSession: hasActiveSession)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}

private struct LockToggleButton: View {
    let bundleIdentifier: String
    let hasActiveSession: Bool
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: {
            if hasActiveSession {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                    SessionManager.shared.revokeSession(for: bundleIdentifier)
                }
            }
        }) {
            Group {
                if #available(macOS 14.0, *) {
                    Image(systemName: hasActiveSession ? "lock.open.fill" : "lock.fill")
                        .contentTransition(.symbolEffect(.replace))
                } else {
                    Image(systemName: hasActiveSession ? "lock.open.fill" : "lock.fill")
                }
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(hasActiveSession ? .green : .secondary)
            .frame(width: 24, height: 24)
            .background(
                Circle()
                    .fill(hasActiveSession && isHovered ? Color.green.opacity(0.12) : Color.clear)
            )
            .scaleEffect(isHovered && hasActiveSession ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            if hasActiveSession {
                withAnimation(.easeOut(duration: 0.15)) {
                    isHovered = hovering
                }
            } else {
                isHovered = false
            }
        }
    }
}

// MARK: - Menu Button

private struct MenuButton: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .foregroundColor(isDestructive ? .red.opacity(0.8) : .secondary)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(isDestructive ? .red.opacity(0.8) : .primary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let openSettings = Notification.Name("com.dweep.FaceGate.openSettings")
    static let openSetup = Notification.Name("com.dweep.FaceGate.openSetup")
}
