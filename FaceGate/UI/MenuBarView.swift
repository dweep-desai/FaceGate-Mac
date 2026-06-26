import SwiftUI
import Sparkle

/// Header for the native NSMenu.
struct MenuHeaderView: View {
    @ObservedObject var appMonitor = AppMonitor.shared
    unowned let builder: MenuBuilder
    
    // Subscribe to menu state updates
    @State private var id = UUID()
    
    private var statusColor: Color {
        if builder.isProtectionPaused { return .orange }
        return appMonitor.isMonitoring ? .green : .red
    }
    
    private var statusText: String {
        if builder.isProtectionPaused { return "Paused" }
        return appMonitor.isMonitoring ? "Active" : "Inactive"
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .scaleEffect(1.15) // Optically compensate for the native macOS icon's internal transparent padding
            } else {
                Image(systemName: "faceid")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
            }
            
            Text("FaceGate")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            
            Spacer()
            
            HStack(alignment: .center, spacing: 5) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .offset(y: 0.5) // Optical alignment for the tiny text caps relative to the bold 15pt title
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .id(id)
        .onReceive(NotificationCenter.default.publisher(for: .menuStateDidChange)) { _ in
            id = UUID()
        }
        .onAppear {
            if !UserDefaults.standard.bool(forKey: FGConstants.setupCompletedKey) {
                NotificationCenter.default.post(name: .openSetup, object: nil)
            } else if !appMonitor.isMonitoring {
                appMonitor.startMonitoring()
            }
        }
    }
}

/// Locked apps list for the native NSMenu.
struct MenuLockedAppsView: View {
    @ObservedObject var lockedAppsManager = LockedAppsManager.shared
    @ObservedObject var sessionManager = SessionManager.shared
    unowned let builder: MenuBuilder
    
    @State private var id = UUID()
    
    private var sortedLockedApps: [LockedApp] {
        lockedAppsManager.lockedApps.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
    
    var body: some View {
        Group {
            if lockedAppsManager.lockedApps.isEmpty {
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
                .frame(height: 100)
            } else {
                let appCount = sortedLockedApps.count
                let maxVisibleApps = 4
                let visibleCount = min(appCount, maxVisibleApps)
                let rowHeight: CGFloat = 40
                let spacing: CGFloat = 1
                let scrollHeight = CGFloat(visibleCount) * rowHeight + CGFloat(max(0, visibleCount - 1)) * spacing
                
                ScrollView {
                    VStack(spacing: spacing) {
                        ForEach(sortedLockedApps) { app in
                            LockedAppRow(
                                app: app,
                                hasActiveSession: builder.isProtectionPaused || sessionManager.hasActiveSession(for: app.bundleIdentifier)
                            )
                        }
                    }
                }
                .frame(height: scrollHeight)
            }
        }
        .padding(.bottom, 4)
        .id(id)
        .onReceive(NotificationCenter.default.publisher(for: .menuStateDidChange)) { _ in
            id = UUID()
        }
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
