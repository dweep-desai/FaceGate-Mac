import AppKit
import ServiceManagement
import SwiftUI

// MARK: - Tab Enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case lockedApps = "Locked Apps"
    case authentication = "Authentication"
    case behavior = "Behavior"
    case about = "About"

    var id: String { rawValue }

    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .lockedApps: return "lock.app.dashed"
        case .authentication: return "person.badge.key.fill"
        case .behavior: return "gearshape.2.fill"
        case .about: return "info.circle.fill"
        }
    }
}

// MARK: - Navigation State

@MainActor
@Observable
final class SettingsNavigation {
    static let shared = SettingsNavigation()
    var selectedTab: SettingsTab? = .lockedApps
    private init() {}
}

// MARK: - Main Settings View

struct SettingsView: View {
    @State private var navigation = SettingsNavigation.shared
    @State private var navigationHistory: [SettingsTab] = [.lockedApps]
    @State private var historyIndex = 0
    @State private var isHistoryNavigation = false

    private var activeTab: SettingsTab {
        navigation.selectedTab ?? .lockedApps
    }

    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SettingsSidebarView(selectedTab: $navigation.selectedTab)
                .navigationSplitViewColumnWidth(
                    min: 200,
                    ideal: 220,
                    max: 260
                )
        } detail: {
            SettingsDetailView(tab: activeTab)
        }
        .navigationTitle("Settings")
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 660, minHeight: 540)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { goBack() } label: { Image(systemName: "chevron.left") }
                .disabled(!canGoBack)
                Button { goForward() } label: { Image(systemName: "chevron.right") }
                .disabled(!canGoForward)
            }
        }
        .onChangeCompat(of: navigation.selectedTab) { _ in recordNavigation() }
    }

    private var canGoBack: Bool { historyIndex > 0 }
    private var canGoForward: Bool { historyIndex < navigationHistory.count - 1 }

    private func goBack() {
        guard canGoBack else { return }
        isHistoryNavigation = true
        historyIndex -= 1
        navigation.selectedTab = navigationHistory[historyIndex]
        DispatchQueue.main.async { isHistoryNavigation = false }
    }

    private func goForward() {
        guard canGoForward else { return }
        isHistoryNavigation = true
        historyIndex += 1
        navigation.selectedTab = navigationHistory[historyIndex]
        DispatchQueue.main.async { isHistoryNavigation = false }
    }

    private func recordNavigation() {
        guard !isHistoryNavigation else { return }
        guard let tab = navigation.selectedTab else { return }
        if navigationHistory.last == tab { return }
        if historyIndex < navigationHistory.count - 1 {
            navigationHistory = Array(navigationHistory.prefix(historyIndex + 1))
        }
        navigationHistory.append(tab)
        historyIndex = navigationHistory.count - 1
    }
}

// MARK: - Sidebar

private struct SettingsSidebarView: View {
    @Binding var selectedTab: SettingsTab?
    @State private var showPermissions = false

    var body: some View {
        List(selection: $selectedTab) {
            ForEach(SettingsTab.allCases) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }
        }
        .listStyle(.sidebar)
        .scrollEdgeEffectStyleSoftIfAvailable()
        .safeAreaInset(edge: .bottom) {
            HStack {
                Button(action: { showPermissions = true }) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.orange)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                }
                .buttonStyle(.plain)
                .help("Permissions")

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showPermissions) {
            PermissionsDialogView()
        }
    }
}

// MARK: - Permissions Dialog

private struct PermissionsDialogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var accessibilityGranted = AXIsProcessTrusted()
    @State private var isResetting = false
    @State private var resetSuccess = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Permissions")
                .font(.system(size: 20, weight: .bold, design: .rounded))
            
            Text("FaceGate needs these permissions to protect your apps.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility")
                            .font(.system(size: 13, weight: .medium))
                        Text("Required to monitor and block app launches")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if accessibilityGranted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Grant") {
                            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                            _ = AXIsProcessTrustedWithOptions(options)
                        }
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))

                HStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Camera")
                            .font(.system(size: 13, weight: .medium))
                        Text("Required for Face Unlock")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text("Auto")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(nsColor: .windowBackgroundColor)))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            }
            
            HStack(spacing: 16) {
                if resetSuccess {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Restarting to apply...")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                } else {
                    Button(isResetting ? "Resetting..." : "Reset") {
                        isResetting = true
                        Task {
                            let process = Process()
                            process.launchPath = "/usr/bin/tccutil"
                            process.arguments = ["reset", "Accessibility", Bundle.main.bundleIdentifier ?? "com.dweep.FaceGate"]
                            try? process.run()
                            process.waitUntilExit()
                            
                            await MainActor.run {
                                resetSuccess = true
                            }
                            
                            try? await Task.sleep(nanoseconds: 1_000_000_000)
                            
                            await MainActor.run {
                                let restartProcess = Process()
                                restartProcess.launchPath = "/usr/bin/open"
                                restartProcess.arguments = ["-n", Bundle.main.bundlePath]
                                try? restartProcess.run()
                                exit(0)
                            }
                        }
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(isResetting)
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(width: 380)
        .task {
            while !Task.isCancelled {
                await MainActor.run {
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
                    let isTrusted = AXIsProcessTrustedWithOptions(options)
                    if accessibilityGranted != isTrusted {
                        accessibilityGranted = isTrusted
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}

// MARK: - Detail Router

private struct SettingsDetailView: View {
    let tab: SettingsTab

    var body: some View {
        Group {
            switch tab {
            case .lockedApps: LockedAppsSettingsView()
            case .authentication: AuthSettingsView()
            case .behavior: BehaviorSettingsView()
            case .about: AboutView()
            }
        }
        .navigationTitle(tab.title)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private extension View {
    @ViewBuilder
    func scrollEdgeEffectStyleSoftIfAvailable() -> some View {
        if #available(macOS 26.0, *) {
            scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}

// MARK: - Auth Settings

private struct AuthSettingsView: View {
    @State private var faceUnlockEnabled = UserDefaults.standard.bool(forKey: FGConstants.faceUnlockEnabledKey)
    @State private var faceEnrolled = UserDefaults.standard.bool(forKey: FGConstants.faceEnrolledKey)
    @State private var touchIDEnabled = TouchIDAuth.shared.isEnabled
    @State private var isTouchIDAvailable = TouchIDAuth.shared.isAvailable
    @State private var primaryAuthOption = UserDefaults.standard.string(forKey: FGConstants.primaryAuthOptionKey) ?? "face"
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
                    HStack(alignment: .top) {
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: "faceid")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 24, alignment: .center)
                            VStack(alignment: .leading) {
                                Text("Face Unlock")
                                    .font(.system(size: 13, weight: .semibold))
                                Text(faceEnrolled ? "Face enrolled and ready" : "No face enrolled yet")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 2)

                        Spacer()
                        VStack(alignment: .trailing, spacing: 10) {
                            if faceEnrolled {
                                Toggle("", isOn: $faceUnlockEnabled)
                                    .labelsHidden()
                                    .onChangeCompat(of: faceUnlockEnabled) { newValue in
                                        UserDefaults.standard.set(newValue, forKey: FGConstants.faceUnlockEnabledKey)
                                    }
                            }
                            
                            HStack(spacing: 8) {
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
                        }
                    }

                    // Divider and Primary Auth Option
                    Divider()
                        .padding(.vertical, 4)
                        
                    HStack {
                        Text("Default Authentication")
                            .font(.system(size: 13))
                        Spacer()
                        Picker("", selection: $primaryAuthOption) {
                            Text("Face Unlock").tag("face")
                            Text("Touch ID").tag("touchid")
                            Text("Password").tag("password")
                        }
                        .frame(width: 150)
                        .onChangeCompat(of: primaryAuthOption) { newValue in
                            UserDefaults.standard.set(newValue, forKey: FGConstants.primaryAuthOptionKey)
                        }
                    }

                    // Sensitivity slider (only shown if enrolled).
                    if faceEnrolled {
                        Divider()
                            .padding(.vertical, 4)
                            
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                Text("Sensitivity")
                                    .font(.system(size: 13))
                                    .padding(.top, 3)
                                Spacer()
                                VStack(spacing: 2) {
                                    Slider(value: $faceThreshold, in: 0.4...0.9, step: 0.05)
                                        .onChangeCompat(of: faceThreshold) { newValue in
                                            AuthenticationManager.shared.faceAuthManager.updateThreshold(newValue)
                                        }
                                        .labelsHidden()
                                    
                                    HStack {
                                        Text("Permissive")
                                        Spacer()
                                        Text("Strict")
                                    }
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                                }
                                .frame(width: 220)
                            }
                            
                            Text("Higher sensitivity requires a closer match. Lower is more permissive.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Primary")
            }

            // MARK: Touch ID Section
            Section {
                // Camera picker (visible only when multiple cameras are available).
                CameraPickerView()
            } header: {
                Text("Camera")
            }

            Section {
                Toggle(isOn: $touchIDEnabled) {
                    HStack {
                        Image(systemName: "touchid")
                            .font(.system(size: 18))
                            .foregroundColor(.pink)
                            .frame(width: 24, alignment: .center)
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
                            .frame(width: 24, alignment: .center)
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
                                LabeledContent("Current password") {
                                    SecureField("", text: $oldPassword)
                                        .labelsHidden()
                                        .textFieldStyle(.roundedBorder)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            LabeledContent("New password") {
                                SecureField("", text: $newPassword)
                                    .labelsHidden()
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.leading)
                            }
                            LabeledContent("Confirm new password") {
                                SecureField("", text: $confirmPassword)
                                    .labelsHidden()
                                    .textFieldStyle(.roundedBorder)
                                    .multilineTextAlignment(.leading)
                            }
                            
                            PasswordStrengthView(password: newPassword)

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
        .contentMargins(.top, 8, for: .scrollContent)
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
        guard newPassword.count >= 6 else {
            passwordError = "Password must be at least 6 characters"
            return
        }
        let hasUpper = newPassword.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil
        let hasLower = newPassword.rangeOfCharacter(from: CharacterSet.lowercaseLetters) != nil
        let hasNumber = newPassword.rangeOfCharacter(from: CharacterSet.decimalDigits) != nil
        let specialChars = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;':\",./<>?\\")
        let hasSpecial = newPassword.rangeOfCharacter(from: specialChars) != nil
        
        guard hasUpper && hasLower && hasNumber && hasSpecial else {
            passwordError = "Password must meet all strength criteria"
            return
        }
        guard newPassword == confirmPassword else {
            passwordError = "Passwords don't match"
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
    @AppStorage(FGConstants.lockOnSleepKey) private var lockOnSleep = false
    @State private var sessionTimeoutMinutes: Double = FGConstants.defaultSessionTimeout / 60
    @State private var uninstallProtection = UserDefaults.standard.bool(forKey: FGConstants.uninstallProtectionKey)
    @State private var isUpdatingUninstallProtection = false

    @AppStorage("emergencyKillModifier") private var emergencyKillModifier = "Command"
    @AppStorage("emergencyKillKey") private var emergencyKillKey = "`"

    @AppStorage(FGConstants.disableFaceUnlockHoursKey) private var disableFaceUnlockHours = false
    @AppStorage(FGConstants.faceUnlockDisabledStartHourKey) private var startHour = 22
    @AppStorage(FGConstants.faceUnlockDisabledStartMinuteKey) private var startMinute = 0
    @AppStorage(FGConstants.faceUnlockDisabledEndHourKey) private var endHour = 7
    @AppStorage(FGConstants.faceUnlockDisabledEndMinuteKey) private var endMinute = 0

    private var startTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let calendar = Calendar.current
                var comps = calendar.dateComponents([.year, .month, .day], from: Date())
                comps.hour = startHour
                comps.minute = startMinute
                return calendar.date(from: comps) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                startHour = comps.hour ?? 22
                startMinute = comps.minute ?? 0
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                let calendar = Calendar.current
                var comps = calendar.dateComponents([.year, .month, .day], from: Date())
                comps.hour = endHour
                comps.minute = endMinute
                return calendar.date(from: comps) ?? Date()
            },
            set: { newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                endHour = comps.hour ?? 7
                endMinute = comps.minute ?? 0
            }
        )
    }

    // Lock all apps schedule
    @AppStorage(FGConstants.lockAllScheduleEnabledKey) private var lockScheduleEnabled = false
    @AppStorage(FGConstants.lockAllStartHourKey) private var lockStartHour = 22
    @AppStorage(FGConstants.lockAllStartMinuteKey) private var lockStartMinute = 0
    @AppStorage(FGConstants.lockAllEndHourKey) private var lockEndHour = 7
    @AppStorage(FGConstants.lockAllEndMinuteKey) private var lockEndMinute = 0

    @State private var lockStartTime = Date()
    @State private var lockEndTime = Date()

    // Unlock all apps schedule
    @AppStorage(FGConstants.unlockAllScheduleEnabledKey) private var unlockScheduleEnabled = false
    @AppStorage(FGConstants.unlockAllStartHourKey) private var unlockStartHour = 7
    @AppStorage(FGConstants.unlockAllStartMinuteKey) private var unlockStartMinute = 0
    @AppStorage(FGConstants.unlockAllEndHourKey) private var unlockEndHour = 22
    @AppStorage(FGConstants.unlockAllEndMinuteKey) private var unlockEndMinute = 0

    @State private var unlockStartTime = Date()
    @State private var unlockEndTime = Date()

    @ObservedObject private var scheduleManager = AppScheduleManager.shared

    private var shortcutModifierSymbol: String {
        emergencyKillModifier == "Command" ? "⌘" : "⇧"
    }

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
                Toggle("App Deletion Protection (highly recommended)", isOn: Binding(
                    get: { uninstallProtection },
                    set: { newValue in
                        guard newValue != uninstallProtection, !isUpdatingUninstallProtection else { return }
                        setUninstallProtection(newValue)
                    }
                ))
                .disabled(isUpdatingUninstallProtection)
                Text("Changing this setting requires administrator authentication. When enabled, FaceGate is protected from deletion to safeguard your locked applications.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } header: {
                Text("Uninstall Protection")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Session Timeout")
                            .font(.system(size: 13))
                        Spacer(minLength: 16)
                        Picker("", selection: Binding(
                            get: { sessionTimeoutMinutes },
                            set: { newValue in
                                sessionTimeoutMinutes = newValue
                                let timeout: TimeInterval = newValue == FGConstants.indefiniteSliderValue ? FGConstants.indefiniteSessionValue : newValue * 60
                                SessionManager.shared.setSessionTimeout(timeout)
                            }
                        )) {
                            Text("Immediately").tag(0.0)
                            Text("For 1 minute").tag(1.0)
                            Text("For 2 minutes").tag(2.0)
                            Text("For 3 minutes").tag(3.0)
                            Text("For 5 minutes").tag(5.0)
                            Text("For 10 minutes").tag(10.0)
                            Text("For 20 minutes").tag(20.0)
                            Text("For 30 minutes").tag(30.0)
                            Text("For 1 hour").tag(60.0)
                            Text("For 1 hour, 30 minutes").tag(90.0)
                            Text("For 2 hours").tag(120.0)
                            Text("For 2 hours, 30 minutes").tag(150.0)
                            Text("For 3 hours").tag(180.0)
                            Divider()
                            Text("Never").tag(FGConstants.indefiniteSliderValue)
                        }
                        .frame(width: 200)
                    }
                    Text("After unlocking an app, it stays unlocked for this duration before re-locking. Set to Immediately to lock immediately after use, or Never to keep unlocked until you manually lock from the menu bar.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Locking")
            }

            Section {
                Toggle(isOn: $lockOnSleep) {
                    Text("Lock all apps when Mac sleeps or locks")
                }
                .toggleStyle(.checkbox)
                if lockOnSleep {
                    Text("All active unlock sessions will be revoked when the Mac goes to sleep, the display sleeps, or the screen is locked. This overrides app timers and indefinite unlock.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Section {
                HStack(spacing: 4) {
                    Toggle(isOn: $lockScheduleEnabled) { EmptyView() }
                        .toggleStyle(.checkbox)
                        .onChangeCompat(of: lockScheduleEnabled) { newValue in
                            scheduleManager.lockScheduleEnabled = newValue
                            scheduleManager.refresh()
                        }

                    HStack {
                        Text("Lock all apps between")

                        DatePicker("", selection: $lockStartTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                            .onChangeCompat(of: lockStartTime) { newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                lockStartHour = comps.hour ?? 22
                                lockStartMinute = comps.minute ?? 0
                                scheduleManager.lockStartHour = lockStartHour
                                scheduleManager.lockStartMinute = lockStartMinute
                                scheduleManager.refresh()
                            }

                        Text("and")

                        DatePicker("", selection: $lockEndTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                            .onChangeCompat(of: lockEndTime) { newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                lockEndHour = comps.hour ?? 7
                                lockEndMinute = comps.minute ?? 0
                                scheduleManager.lockEndHour = lockEndHour
                                scheduleManager.lockEndMinute = lockEndMinute
                                scheduleManager.refresh()
                            }
                    }
                    .disabled(!lockScheduleEnabled)
                    .opacity(lockScheduleEnabled ? 1 : 0.5)
                }

                if lockScheduleEnabled {
                    Text("All locked apps will be automatically locked during these hours. Manually unlocked apps are not affected.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                if scheduleManager.lockUnlockWindowsOverlap {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text("Lock and unlock windows overlap. Lock takes priority - unlock will be skipped during the overlap.")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                HStack(spacing: 4) {
                    Toggle(isOn: $unlockScheduleEnabled) { EmptyView() }
                        .toggleStyle(.checkbox)
                        .onChangeCompat(of: unlockScheduleEnabled) { newValue in
                            scheduleManager.unlockScheduleEnabled = newValue
                            scheduleManager.refresh()
                        }

                    HStack {
                        Text("Unlock all apps between")

                        DatePicker("", selection: $unlockStartTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                            .onChangeCompat(of: unlockStartTime) { newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                unlockStartHour = comps.hour ?? 7
                                unlockStartMinute = comps.minute ?? 0
                                scheduleManager.unlockStartHour = unlockStartHour
                                scheduleManager.unlockStartMinute = unlockStartMinute
                                scheduleManager.refresh()
                            }

                        Text("and")

                        DatePicker("", selection: $unlockEndTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.stepperField)
                            .labelsHidden()
                            .onChangeCompat(of: unlockEndTime) { newValue in
                                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                                unlockEndHour = comps.hour ?? 22
                                unlockEndMinute = comps.minute ?? 0
                                scheduleManager.unlockEndHour = unlockEndHour
                                scheduleManager.unlockEndMinute = unlockEndMinute
                                scheduleManager.refresh()
                            }
                    }
                    .disabled(!unlockScheduleEnabled)
                    .opacity(unlockScheduleEnabled ? 1 : 0.5)
                }

                if unlockScheduleEnabled {
                    Text("All locked apps will be automatically unlocked during these hours. Manually locked apps are not affected.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                if scheduleManager.lockUnlockWindowsOverlap {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                        Text("Lock and unlock windows overlap. Lock takes priority - unlock will be skipped during the overlap.")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Toggle("Disable Face Unlock during certain hours", isOn: $disableFaceUnlockHours)
                    .onChangeCompat(of: disableFaceUnlockHours) { newValue in
                        if newValue {
                            // Ensure start/end hours are written to UserDefaults immediately so that FaceAuthManager has them
                            UserDefaults.standard.set(startHour, forKey: FGConstants.faceUnlockDisabledStartHourKey)
                            UserDefaults.standard.set(startMinute, forKey: FGConstants.faceUnlockDisabledStartMinuteKey)
                            UserDefaults.standard.set(endHour, forKey: FGConstants.faceUnlockDisabledEndHourKey)
                            UserDefaults.standard.set(endMinute, forKey: FGConstants.faceUnlockDisabledEndMinuteKey)
                        }
                    }
                
                if disableFaceUnlockHours {
                    HStack {
                        DatePicker("Start Time", selection: startTimeBinding, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.stepperField)
                        
                        Spacer()
                        
                        DatePicker("End Time", selection: endTimeBinding, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.stepperField)
                    }
                    
                    Text("During these hours, App Lock remains active but face recognition is bypassed, forcing password/Touch ID entry.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Face Unlock Schedule")
            }

            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Emergency Kill Shortcut")
                        .font(.system(size: 13, weight: .semibold))
                    
                    HStack {
                        Text("Compulsory modifiers:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("⌃ Control + ⌥ Option")
                            .font(.system(size: 11, weight: .medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(4)
                    }
                    
                    HStack(spacing: 8) {
                        Text("Third Modifier:")
                            .font(.system(size: 11))
                        Picker("", selection: $emergencyKillModifier) {
                            Text("⌘ Command").tag("Command")
                            Text("⇧ Shift").tag("Shift")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 130)
                        .onChangeCompat(of: emergencyKillModifier) { _ in
                            GlobalHotkeyManager.shared.reRegisterShortcut()
                        }

                        Text("Key:")
                            .font(.system(size: 11))
                        Picker("", selection: $emergencyKillKey) {
                            Text("` (Backtick)").tag("`")
                            Text("Escape").tag("Escape")
                            Text("Space").tag("Space")
                            Text("Q").tag("Q")
                            Text("K").tag("K")
                            Text("X").tag("X")
                            Text("Delete").tag("Delete")
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 130)
                        .onChangeCompat(of: emergencyKillKey) { _ in
                            GlobalHotkeyManager.shared.reRegisterShortcut()
                        }
                    }
                    
                    Text("Current Shortcut: ⌃⌥\(shortcutModifierSymbol)\(emergencyKillKey)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.blue)
                    
                    Text("Pressing the shortcut above at any time will instantly quit FaceGate without requiring authentication.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Emergency")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
        .onAppear {
            // Sync uninstall protection state
            let currentStatus = getActualProtectionState()
            uninstallProtection = currentStatus
            UserDefaults.standard.set(currentStatus, forKey: FGConstants.uninstallProtectionKey)

            let storedTimeout = SessionManager.shared.sessionTimeout
            sessionTimeoutMinutes = storedTimeout == FGConstants.indefiniteSessionValue ? FGConstants.indefiniteSliderValue : storedTimeout / 60

            let calendar = Calendar.current
            let now = Date()



            // Load lock-all schedule dates
            var lockStartComponents = calendar.dateComponents([.year, .month, .day], from: now)
            lockStartComponents.hour = lockStartHour
            lockStartComponents.minute = lockStartMinute
            if let startDate = calendar.date(from: lockStartComponents) {
                lockStartTime = startDate
            }

            var lockEndComponents = calendar.dateComponents([.year, .month, .day], from: now)
            lockEndComponents.hour = lockEndHour
            lockEndComponents.minute = lockEndMinute
            if let endDate = calendar.date(from: lockEndComponents) {
                lockEndTime = endDate
            }

            // Load unlock-all schedule dates
            var unlockStartComponents = calendar.dateComponents([.year, .month, .day], from: now)
            unlockStartComponents.hour = unlockStartHour
            unlockStartComponents.minute = unlockStartMinute
            if let startDate = calendar.date(from: unlockStartComponents) {
                unlockStartTime = startDate
            }

            var unlockEndComponents = calendar.dateComponents([.year, .month, .day], from: now)
            unlockEndComponents.hour = unlockEndHour
            unlockEndComponents.minute = unlockEndMinute
            if let endDate = calendar.date(from: unlockEndComponents) {
                unlockEndTime = endDate
            }

            // Sync local AppStorage settings to scheduleManager on appear
            scheduleManager.lockScheduleEnabled = lockScheduleEnabled
            scheduleManager.lockStartHour = lockStartHour
            scheduleManager.lockStartMinute = lockStartMinute
            scheduleManager.lockEndHour = lockEndHour
            scheduleManager.lockEndMinute = lockEndMinute

            scheduleManager.unlockScheduleEnabled = unlockScheduleEnabled
            scheduleManager.unlockStartHour = unlockStartHour
            scheduleManager.unlockStartMinute = unlockStartMinute
            scheduleManager.unlockEndHour = unlockEndHour
            scheduleManager.unlockEndMinute = unlockEndMinute

            scheduleManager.refresh()
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

    private var protectionTargetPath: String {
        let installedPath = "/Applications/FaceGate.app"
        if FileManager.default.fileExists(atPath: installedPath) {
            return installedPath
        }
        return Bundle.main.bundlePath
    }

    private func getActualProtectionState() -> Bool {
        let bundlePath = protectionTargetPath
        let bundleURL = URL(fileURLWithPath: bundlePath)
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: bundlePath)
            let ownerName = attrs[.ownerAccountName] as? String
            
            let resourceValues = try bundleURL.resourceValues(forKeys: [.isUserImmutableKey])
            let isImmutable = resourceValues.isUserImmutable ?? false
            
            return ownerName == "root" || isImmutable
        } catch {
            return false
        }
    }

    private func setUninstallProtection(_ enabled: Bool) {
        guard !isUpdatingUninstallProtection else { return }
        isUpdatingUninstallProtection = true
        
        let bundlePath = protectionTargetPath
        let escapedPath = bundlePath.replacingOccurrences(of: "'", with: "'\\''")
        
        let command: String
        if enabled {
            command = "chown -R root:wheel '\(escapedPath)' && chflags -R uchg '\(escapedPath)'"
        } else {
            let username = NSUserName()
            command = "chflags -R nouchg '\(escapedPath)' && chown -R \(username):staff '\(escapedPath)'"
        }
        
        let source = "do shell script \"\(command)\" with administrator privileges with prompt \"FaceGate wants to make changes.\""
        
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let script = NSAppleScript(source: source)
            let result = script?.executeAndReturnError(&error)
            
            DispatchQueue.main.async {
                if let error = error {
                    NSLog("[FaceGate] Uninstall protection failed: \(error)")
                    self.uninstallProtection = self.getActualProtectionState()
                } else {
                    UserDefaults.standard.set(enabled, forKey: FGConstants.uninstallProtectionKey)
                    self.uninstallProtection = enabled
                }
                self.isUpdatingUninstallProtection = false
            }
        }
    }
    
}

// MARK: - About View

private struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 96, height: 96)
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 96, height: 96)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 6) {
                    Text("FaceGate")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Text("A privacy-focused app locker for macOS with face authentication.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                Divider()
                    .frame(maxWidth: 240)
                    .padding(.vertical, 4)

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
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.1))
                )
                
                VStack(spacing: 12) {
                    Link(destination: URL(string: "https://github.com/dweep-desai/FaceGate-Mac")!) {
                        HStack(spacing: 8) {
                            Image("GitHubIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                // Standard native button color usually applied automatically, or we can use primary
                                .foregroundColor(.primary)
                            Text("GitHub Repository")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .frame(width: 200, height: 28)
                    }
                    .buttonStyle(.link)

                    Link(destination: URL(string: "https://github.com/sponsors/dweep-desai")!) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                                .foregroundColor(.pink)
                            Text("Sponsor on GitHub")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .frame(width: 200, height: 28)
                    }
                    .buttonStyle(.link)
                }
                .padding(.vertical, 4)

                VStack(spacing: 4) {
                    Text("Open Source - MIT License")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("© 2026 Dweep Desai")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            .padding(.top, 48)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Locked Apps Settings View
struct LockedAppsSettingsView: View {
    @ObservedObject var lockedAppsManager = LockedAppsManager.shared
    @State private var editingApp: LockedApp?

    var body: some View {
        VStack(spacing: 0) {
            AppPickerView { app in
                editingApp = app
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
        }
        .sheet(item: $editingApp) { app in
            LockedAppSheetView(app: app, isPresented: Binding(
                get: { editingApp != nil },
                set: { if !$0 { editingApp = nil } }
            ))
        }
    }
}

private struct LockedAppSheetView: View {
    let app: LockedApp
    @Binding var isPresented: Bool
    
    @ObservedObject var lockedAppsManager = LockedAppsManager.shared
    
    @State private var hasCustomTimer = false
    @State private var customTimeoutMinutes: Double = 5
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                }
                Text("Configure Timer: \(app.displayName)")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Toggle("Custom Session Timer", isOn: $hasCustomTimer)
                            .toggleStyle(.checkbox)
                            .font(.system(size: 13))
                        
                        Spacer(minLength: 16)
                        
                        Picker("", selection: $customTimeoutMinutes) {
                            Text("Immediately").tag(0.0)
                            Text("For 1 minute").tag(1.0)
                            Text("For 2 minutes").tag(2.0)
                            Text("For 3 minutes").tag(3.0)
                            Text("For 5 minutes").tag(5.0)
                            Text("For 10 minutes").tag(10.0)
                            Text("For 20 minutes").tag(20.0)
                            Text("For 30 minutes").tag(30.0)
                            Text("For 1 hour").tag(60.0)
                            Text("For 1 hour, 30 minutes").tag(90.0)
                            Text("For 2 hours").tag(120.0)
                            Text("For 2 hours, 30 minutes").tag(150.0)
                            Text("For 3 hours").tag(180.0)
                            Divider()
                            Text("Never").tag(FGConstants.indefiniteSliderValue)
                        }
                        .frame(width: 200)
                        .disabled(!hasCustomTimer)
                    }
                    
                    if hasCustomTimer {
                        Text("Override the global timer for this specific app.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20) // Indent under toggle
                    } else {
                        let globalTimeout = SessionManager.shared.sessionTimeout / 60
                        let timeString = globalTimeout == 0 ? "Immediately" : (globalTimeout == FGConstants.indefiniteSliderValue ? "Never" : "\(Int(globalTimeout)) min")
                        Text("Using Global Timer (\(timeString))")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, 20)
                    }
                }
            }
            .padding(20)
            
            Spacer()
            
            Divider()
            
            HStack {
                Spacer()
                Button("Done") {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
            .padding()
        }
        .frame(width: 400)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let activeApp = lockedAppsManager.lockedApps.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                if let custom = activeApp.customSessionTimeout {
                    hasCustomTimer = true
                    customTimeoutMinutes = custom == FGConstants.indefiniteSessionValue ? FGConstants.indefiniteSliderValue : custom / 60
                } else {
                    hasCustomTimer = false
                    let lastSelection = UserDefaults.standard.double(forKey: "lastCustomTimeout_\(app.bundleIdentifier)")
                    customTimeoutMinutes = lastSelection > 0 ? lastSelection : 5
                }
            }
        }
        .onChangeCompat(of: hasCustomTimer) { newValue in
            saveChanges(hasCustom: newValue, minutes: customTimeoutMinutes)
        }
        .onChangeCompat(of: customTimeoutMinutes) { newValue in
            saveChanges(hasCustom: hasCustomTimer, minutes: newValue)
        }
    }
    
    private func saveChanges(hasCustom: Bool, minutes: Double) {
        let timeout: TimeInterval? = hasCustom ? (minutes == FGConstants.indefiniteSliderValue ? FGConstants.indefiniteSessionValue : minutes * 60) : nil
        lockedAppsManager.updateCustomSessionTimeout(for: app.bundleIdentifier, timeout: timeout)
        if hasCustom {
            UserDefaults.standard.set(minutes, forKey: "lastCustomTimeout_\(app.bundleIdentifier)")
        }
        SessionManager.shared.revokeSession(for: app.bundleIdentifier)
    }
}

// MARK: - Camera Picker

private struct CameraPickerView: View {
    @ObservedObject private var cameraManager = AuthenticationManager.shared.faceAuthManager.cameraManager
    @State private var selectedID: String = ""

    var body: some View {
        Picker(selection: $selectedID) {
            ForEach(cameraManager.availableCameras, id: \.uniqueID) { camera in
                HStack {
                    Image(systemName: camera.deviceType == .external ? "web.camera.fill" : "camera.fill")
                        .foregroundColor(.secondary)
                    Text(camera.localizedName)
                }
                .tag(camera.uniqueID)
            }
        } label: {
            HStack {
                Image(systemName: "video.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                VStack(alignment: .leading) {
                    Text("Camera")
                        .font(.system(size: 13, weight: .medium))
                    Text(selectedCameraLabel)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .disabled(cameraManager.availableCameras.count <= 1)
        .onAppear {
            cameraManager.refreshAvailableCameras()
            if selectedID.isEmpty {
                selectedID = cameraManager.selectedCameraID ?? cameraManager.availableCameras.first?.uniqueID ?? ""
            }
        }
        .onChangeCompat(of: selectedID) { newValue in
            cameraManager.selectedCameraID = newValue
        }
    }

    private var selectedCameraLabel: String {
        if let cam = cameraManager.availableCameras.first(where: { $0.uniqueID == selectedID }) {
            return cam.localizedName
        }
        return cameraManager.availableCameras.first?.localizedName ?? "No camera found"
    }
}
