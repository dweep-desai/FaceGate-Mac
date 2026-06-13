import ServiceManagement
import SwiftUI

/// The main settings window with tabbed navigation.
struct SettingsView: View {
    @ObservedObject var lockedAppsManager = LockedAppsManager.shared

    @State private var selectedTab: SettingsTab = .lockedApps

    enum SettingsTab: String, CaseIterable, Identifiable {
        case lockedApps = "Locked Apps"
        case authentication = "Authentication"
        case behavior = "Behavior"
        case about = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .lockedApps: return "lock.app.dashed"
            case .authentication: return "person.badge.key.fill"
            case .behavior: return "gearshape.2.fill"
            case .about: return "info.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            Group {
                switch selectedTab {
                case .lockedApps:
                    LockedAppsSettingsView()
                case .authentication:
                    AuthSettingsView()
                case .behavior:
                    BehaviorSettingsView()
                case .about:
                    AboutView()
                }
            }
            .frame(minWidth: 450, minHeight: 400)
        }
        .frame(minWidth: 650, minHeight: 450)
    }
}

// MARK: - Auth Settings

private struct AuthSettingsView: View {
    @State private var faceUnlockEnabled = UserDefaults.standard.bool(forKey: FGConstants.faceUnlockEnabledKey)
    @State private var faceEnrolled = UserDefaults.standard.bool(forKey: FGConstants.faceEnrolledKey)
    @State private var touchIDEnabled = TouchIDAuth.shared.isEnabled
    @State private var isTouchIDAvailable = TouchIDAuth.shared.isAvailable
    @State private var showChangePassword = false
    @State private var showFaceEnrollment = false
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var passwordError: String?
    @State private var passwordSuccess = false
    @State private var faceThreshold: Float = {
        let stored = UserDefaults.standard.float(forKey: FGConstants.faceUnlockThresholdKey)
        return stored > 0 ? stored : FGConstants.defaultFaceUnlockThreshold
    }()

    var body: some View {
        Form {
            // MARK: Face Unlock Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "faceid")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text("Face Unlock")
                                .font(.system(size: 13, weight: .semibold))
                            Text(faceEnrolled ? "Face enrolled and ready" : "No face enrolled yet")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if faceEnrolled {
                            Toggle("", isOn: $faceUnlockEnabled)
                                .labelsHidden()
                                .onChangeCompat(of: faceUnlockEnabled) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: FGConstants.faceUnlockEnabledKey)
                                }
                        }
                    }

                    // Enroll / Re-enroll button.
                    HStack {
                        Button(faceEnrolled ? "Re-enroll Face" : "Enroll Face") {
                            showFaceEnrollment = true
                        }
                        .controlSize(.small)

                        if faceEnrolled {
                            Button("Delete Face Data") {
                                try? FaceDataStore.shared.delete()
                                faceEnrolled = false
                                faceUnlockEnabled = false
                            }
                            .controlSize(.small)
                            .foregroundColor(.red)
                        }
                    }

                    // Sensitivity slider (only shown if enrolled).
                    if faceEnrolled {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Sensitivity")
                                    .font(.system(size: 12))
                                Spacer()
                                Text(sensitivityLabel)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $faceThreshold, in: 0.4...0.9, step: 0.05)
                                .onChangeCompat(of: faceThreshold) { newValue in
                                    AuthenticationManager.shared.faceAuthManager.updateThreshold(newValue)
                                }
                            Text("Higher sensitivity requires a closer match. Lower is more permissive.")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                }
            } header: {
                Text("Primary")
            }

            // MARK: Touch ID Section
            Section {
                Toggle(isOn: $touchIDEnabled) {
                    HStack {
                        Image(systemName: "touchid")
                            .font(.system(size: 18))
                            .foregroundColor(.pink)
                        VStack(alignment: .leading) {
                            Text("Touch ID")
                                .font(.system(size: 13, weight: .medium))
                            Text(isTouchIDAvailable ? "Available on this Mac" : "Not available on this Mac")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(!isTouchIDAvailable)
                .onChangeCompat(of: touchIDEnabled) { newValue in
                    TouchIDAuth.shared.isEnabled = newValue
                }
            } header: {
                Text("Fallbacks")
            }

            // MARK: Password Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "key.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.orange)
                        VStack(alignment: .leading) {
                            Text("App Password")
                                .font(.system(size: 13, weight: .medium))
                            Text(PasswordAuth.shared.isPasswordSet ? "Password is set" : "No password set")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Change") {
                            showChangePassword.toggle()
                        }
                    }

                    if showChangePassword {
                        VStack(alignment: .leading, spacing: 8) {
                            if PasswordAuth.shared.isPasswordSet {
                                SecureField("Current password", text: $oldPassword)
                                    .textFieldStyle(.roundedBorder)
                            }
                            SecureField("New password", text: $newPassword)
                                .textFieldStyle(.roundedBorder)
                            SecureField("Confirm new password", text: $confirmPassword)
                                .textFieldStyle(.roundedBorder)

                            if let error = passwordError {
                                Text(error)
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                            }

                            if passwordSuccess {
                                Text("Password changed successfully!")
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                            }

                            HStack {
                                Button("Cancel") {
                                    resetPasswordFields()
                                }
                                Button("Save") {
                                    changePassword()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .padding(.leading, 24)
                    }
                }
            }

            // MARK: Security Disclaimer
            Section {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 14))
                    Text("Face Unlock uses your Mac's built-in camera for convenience-level authentication. It is not equivalent to Apple's Face ID and may be susceptible to photo-based spoofing. For high security, use Touch ID or your app password.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Security Notice")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showFaceEnrollment) {
            FaceEnrollmentView(
                onComplete: {
                    showFaceEnrollment = false
                    faceEnrolled = UserDefaults.standard.bool(forKey: FGConstants.faceEnrolledKey)
                    faceUnlockEnabled = UserDefaults.standard.bool(forKey: FGConstants.faceUnlockEnabledKey)
                },
                isInSettings: true
            )
        }
    }

    private var sensitivityLabel: String {
        if faceThreshold < 0.5 {
            return "Very Permissive"
        } else if faceThreshold < 0.6 {
            return "Permissive"
        } else if faceThreshold < 0.7 {
            return "Balanced"
        } else if faceThreshold < 0.8 {
            return "Strict"
        } else {
            return "Very Strict"
        }
    }

    private func changePassword() {
        passwordError = nil
        passwordSuccess = false

        guard !newPassword.isEmpty else {
            passwordError = "Password cannot be empty"
            return
        }
        guard newPassword == confirmPassword else {
            passwordError = "Passwords don't match"
            return
        }
        guard newPassword.count >= 4 else {
            passwordError = "Password must be at least 4 characters"
            return
        }

        if PasswordAuth.shared.isPasswordSet {
            guard PasswordAuth.shared.changePassword(from: oldPassword, to: newPassword) else {
                passwordError = "Current password is incorrect"
                return
            }
        } else {
            do {
                try PasswordAuth.shared.setPassword(newPassword)
            } catch {
                passwordError = "Failed to save password: \(error.localizedDescription)"
                return
            }
        }

        passwordSuccess = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            resetPasswordFields()
        }
    }

    private func resetPasswordFields() {
        showChangePassword = false
        oldPassword = ""
        newPassword = ""
        confirmPassword = ""
        passwordError = nil
        passwordSuccess = false
    }
}

// MARK: - Behavior Settings

private struct BehaviorSettingsView: View {
    @AppStorage(FGConstants.launchAtLoginKey) private var launchAtLogin = false
    @State private var sessionTimeoutMinutes: Double = FGConstants.defaultSessionTimeout / 60

    var body: some View {
        Form {
            Section {
                Toggle("Launch FaceGate at Login", isOn: $launchAtLogin)
                    .onChangeCompat(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            } header: {
                Text("Startup")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Session Timeout")
                        Spacer()
                        Text("\(Int(sessionTimeoutMinutes)) min")
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $sessionTimeoutMinutes, in: 1...30, step: 1)
                        .onChangeCompat(of: sessionTimeoutMinutes) { newValue in
                            SessionManager.shared.setSessionTimeout(newValue * 60)
                        }
                    Text("After unlocking an app, it stays unlocked for this duration before re-locking.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Locking")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            sessionTimeoutMinutes = SessionManager.shared.sessionTimeout / 60
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "register" : "unregister") login item: \(error)")
            }
        }
    }
}

// MARK: - About View

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 4) {
                Text("FaceGate")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Version 1.0.0")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Text("A privacy-focused app locker for macOS with face authentication.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Divider()
                .frame(maxWidth: 200)

            VStack(spacing: 8) {
                Text("⚠️ Security Disclaimer")
                    .font(.system(size: 12, weight: .semibold))

                Text("Face Unlock is a convenience feature using the built-in camera. It is NOT equivalent to Apple's Face ID and may be susceptible to photo-based spoofing. For maximum security, use Touch ID or the app password.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 350)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orange.opacity(0.08))
            )

            VStack(spacing: 4) {
                Text("Open Source — MIT License")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("© 2026 Dweep Desai")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Locked Apps Settings View

struct LockedAppsSettingsView: View {
    @ObservedObject var lockedAppsManager = LockedAppsManager.shared
    @State private var showingAddApps = false
    @State private var installedApps: [InstalledAppsScanner.DiscoveredApp] = []
    @State private var isLoading = false
    @State private var searchText = ""

    private var filteredLockedApps: [LockedApp] {
        if searchText.isEmpty {
            return lockedAppsManager.lockedApps
        }
        return lockedAppsManager.lockedApps.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredUnlockedApps: [InstalledAppsScanner.DiscoveredApp] {
        let lockedBundleIDs = Set(lockedAppsManager.lockedApps.map { $0.bundleIdentifier })
        let unlocked = installedApps.filter { !lockedBundleIDs.contains($0.bundleIdentifier) }
        if searchText.isEmpty {
            return unlocked
        }
        return unlocked.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if showingAddApps {
                addAppsHeader
                Divider()
                if isLoading {
                    loadingView
                } else if filteredUnlockedApps.isEmpty {
                    emptyUnlockedView
                } else {
                    unlockedAppsList
                }
            } else {
                lockedAppsHeader
                Divider()
                if lockedAppsManager.lockedApps.isEmpty {
                    emptyLockedView
                } else if filteredLockedApps.isEmpty {
                    noSearchResultsView
                } else {
                    lockedAppsList
                }
            }
        }
        .onAppear {
            loadAppsIfNeeded()
        }
    }

    // MARK: - Loading State View
    @ViewBuilder
    private var loadingView: some View {
        Spacer()
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Scanning installed apps…")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        Spacer()
    }

    // MARK: - Empty States
    @ViewBuilder
    private var emptyLockedView: some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "lock.open")
                .font(.system(size: 36))
                .foregroundColor(.secondary)
            VStack(spacing: 4) {
                Text("No Apps Locked")
                    .font(.system(size: 14, weight: .semibold))
                Text("Protect your apps by adding them to the lock list.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 260)
            
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    searchText = ""
                    showingAddApps = true
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Apps")
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue)
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        Spacer()
    }

    @ViewBuilder
    private var emptyUnlockedView: some View {
        Spacer()
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.green.opacity(0.8))
            VStack(spacing: 4) {
                Text("All Apps Locked")
                    .font(.system(size: 14, weight: .semibold))
                Text("You've locked all discovered applications on this system.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 260)
        }
        Spacer()
    }

    @ViewBuilder
    private var noSearchResultsView: some View {
        Spacer()
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No results matching \"\(searchText)\"")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        Spacer()
    }

    // MARK: - Headers
    private var lockedAppsHeader: some View {
        HStack(spacing: 12) {
            Text("Locked Apps")
                .font(.system(size: 15, weight: .bold))

            Spacer()

            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(width: 160)

            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    searchText = ""
                    showingAddApps = true
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                    Text("Add Apps…")
                }
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue)
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var addAppsHeader: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    searchText = ""
                    showingAddApps = false
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Done")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            Text("Add Apps to Lock")
                .font(.system(size: 15, weight: .bold))

            Spacer()

            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(width: 180)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Lists
    private var lockedAppsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(filteredLockedApps, id: \.bundleIdentifier) { app in
                    LockedRowView(app: app) {
                        withAnimation(.spring(response: 0.18, dampingFraction: 0.8, blendDuration: 0)) {
                            lockedAppsManager.unlockApp(app.bundleIdentifier)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .scale(scale: 0.7).combined(with: .opacity)
                    ))
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var unlockedAppsList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(filteredUnlockedApps, id: \.bundleIdentifier) { app in
                    UnlockedRowView(app: app) {
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
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95)),
                        removal: .scale(scale: 0.7).combined(with: .opacity)
                    ))
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Private Helpers
    private func loadAppsIfNeeded() {
        guard installedApps.isEmpty else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = InstalledAppsScanner.shared.scanInstalledApps()
            DispatchQueue.main.async {
                installedApps = apps
                isLoading = false
            }
        }
    }
}

// MARK: - Individual Row Views

private struct LockedRowView: View {
    let app: LockedApp
    let onToggle: () -> Void
    @State private var isLocked = true
    @State private var isHovered = false
    @State private var isProcessing = false

    var body: some View {
        HStack(spacing: 12) {
            if let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .foregroundColor(.secondary)
            }

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

            Toggle("", isOn: $isLocked)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .allowsHitTesting(!isProcessing)
                .onChangeCompat(of: isLocked) { newValue in
                    guard !isProcessing else { return }
                    if !newValue {
                        isProcessing = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
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
    }
}

private struct UnlockedRowView: View {
    let app: InstalledAppsScanner.DiscoveredApp
    let onToggle: () -> Void
    @State private var isLocked = false
    @State private var isHovered = false
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

            Toggle("", isOn: $isLocked)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .allowsHitTesting(!isProcessing)
                .onChangeCompat(of: isLocked) { newValue in
                    guard !isProcessing else { return }
                    if newValue {
                        isProcessing = true
                        onToggle()
                    }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
