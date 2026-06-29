import AppKit
import ServiceManagement
import SwiftUI

final class SettingsChromeState: ObservableObject {
    @Published var isSidebarCollapsed = false
}

/// The main settings window with tabbed navigation.
struct SettingsView: View {
    @ObservedObject var lockedAppsManager = LockedAppsManager.shared
    @ObservedObject var chromeState: SettingsChromeState

    @State private var selectedTab: SettingsTab = .lockedApps

    init(chromeState: SettingsChromeState = SettingsChromeState()) {
        self.chromeState = chromeState
    }

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

        var description: String {
            switch self {
            case .lockedApps: return "Choose which apps require authentication."
            case .authentication: return "Tune Face Unlock, Touch ID, and password fallback."
            case .behavior: return "Adjust launch, locking, schedules, and emergency controls."
            case .about: return "Version, license, and project details."
            }
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.codexWindowBackground
                .ignoresSafeArea()

            HStack(spacing: 0) {
                if !chromeState.isSidebarCollapsed {
                    CodexSettingsSidebar(selectedTab: $selectedTab)
                        .frame(width: 292)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                SettingsDetailPane(selectedTab: selectedTab)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.86), value: chromeState.isSidebarCollapsed)
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 850, minHeight: 620)
        .toolbar(.hidden)
    }
}

private struct CodexSettingsSidebar: View {
    @Binding var selectedTab: SettingsView.SettingsTab

    var body: some View {
        ZStack {
            CodexSidebarVisualEffect(material: .sidebar, blendingMode: .behindWindow)

            LinearGradient(
                colors: [
                    Color(red: 0.30, green: 0.32, blue: 0.42).opacity(0.36),
                    Color(red: 0.12, green: 0.22, blue: 0.22).opacity(0.30),
                    Color.black.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("FaceGate")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                        Text("Settings")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.48))
                    }
                }
                .padding(.top, 34)
                .padding(.horizontal, 18)
                .padding(.bottom, 20)

                Text("Preferences")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.38))
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)

                VStack(spacing: 3) {
                    ForEach(SettingsView.SettingsTab.allCases) { tab in
                        CodexSidebarRow(
                            tab: tab,
                            isSelected: selectedTab == tab
                        ) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(.horizontal, 8)

                Spacer()

                HStack(spacing: 9) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                    Text("Protected locally")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .foregroundStyle(.white.opacity(0.54))
                .padding(.horizontal, 14)
                .padding(.vertical, 16)
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1)
        }
    }
}

private struct CodexSidebarRow: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 22)
                    .symbolRenderingMode(.hierarchical)

                Text(tab.rawValue)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                Spacer()
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.70))
            .padding(.horizontal, 9)
            .frame(height: 38)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.white.opacity(0.11))
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

private struct SettingsDetailPane: View {
    let selectedTab: SettingsView.SettingsTab

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedTab.rawValue)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                    Text(selectedTab.description)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.48))
                }

                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.top, 34)
            .padding(.bottom, 18)

            Divider()
                .overlay(Color.white.opacity(0.07))

            selectedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.codexWindowBackground)
        }
        .background(Color.codexWindowBackground)
    }

    @ViewBuilder
    private var selectedContent: some View {
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
}

private struct CodexSidebarVisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}

private extension Color {
    static let codexWindowBackground = Color(red: 0.075, green: 0.075, blue: 0.073)
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
    @State private var enrolledFaces: [FaceEnrollment.EnrolledFace] = []
    @State private var isAddingFace = false
    @State private var faceNames: [UUID: String] = [:]

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

                    // Enrolled Faces list
                    if faceEnrolled && !enrolledFaces.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Enrolled Faces (Max 3)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                                .padding(.top, 4)

                            ForEach(enrolledFaces) { face in
                                HStack(spacing: 8) {
                                    Image(systemName: "person.crop.circle.badge.checkmark")
                                        .font(.system(size: 14))
                                        .foregroundColor(.green)
                                    
                                    // Inline rename TextField
                                    TextField("Face Name", text: Binding(
                                        get: { faceNames[face.id] ?? face.name },
                                        set: { faceNames[face.id] = $0 }
                                    ), onEditingChanged: { isEditing in
                                        if !isEditing {
                                            if let name = faceNames[face.id] {
                                                renameFace(id: face.id, newName: name)
                                            }
                                        }
                                    }, onCommit: {
                                        if let name = faceNames[face.id] {
                                            renameFace(id: face.id, newName: name)
                                        }
                                    })
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        deleteFace(id: face.id)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(6)
                            }
                        }
                    }

                    // Enroll / Add Face / Delete buttons.
                    HStack {
                        if !faceEnrolled {
                            Button("Enroll Face") {
                                isAddingFace = false
                                showFaceEnrollment = true
                            }
                            .controlSize(.small)
                        } else {
                            if enrolledFaces.count < 3 {
                                Button("Add Face") {
                                    isAddingFace = true
                                    showFaceEnrollment = true
                                }
                                .controlSize(.small)
                            }
                            
                            Button("Re-enroll Fresh") {
                                isAddingFace = false
                                showFaceEnrollment = true
                            }
                            .controlSize(.small)

                            Button("Delete All Face Data") {
                                try? FaceDataStore.shared.delete()
                                refreshEnrolledFaces()
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
        .onAppear {
            refreshEnrolledFaces()
        }
        .sheet(isPresented: $showFaceEnrollment) {
            FaceEnrollmentView(
                onComplete: {
                    showFaceEnrollment = false
                    refreshEnrolledFaces()
                },
                isInSettings: true,
                isAddingFace: isAddingFace
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

    private func refreshEnrolledFaces() {
        faceEnrolled = UserDefaults.standard.bool(forKey: FGConstants.faceEnrolledKey)
        faceUnlockEnabled = UserDefaults.standard.bool(forKey: FGConstants.faceUnlockEnabledKey)
        if let enrollment = FaceDataStore.shared.load() {
            enrolledFaces = enrollment.faces
            for face in enrollment.faces {
                if faceNames[face.id] == nil {
                    faceNames[face.id] = face.name
                }
            }
        } else {
            enrolledFaces = []
            faceNames = [:]
        }
    }

    private func renameFace(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if let enrollment = FaceDataStore.shared.load(),
               let index = enrollment.faces.firstIndex(where: { $0.id == id }) {
                faceNames[id] = enrollment.faces[index].name
            }
            return
        }
        if var enrollment = FaceDataStore.shared.load() {
            if let index = enrollment.faces.firstIndex(where: { $0.id == id }) {
                enrollment.faces[index].name = trimmed
                try? FaceDataStore.shared.save(enrollment)
                faceNames[id] = trimmed
                refreshEnrolledFaces()
            }
        }
    }

    private func deleteFace(id: UUID) {
        if var enrollment = FaceDataStore.shared.load() {
            enrollment.faces.removeAll(where: { $0.id == id })
            faceNames.removeValue(forKey: id)  // clean up stale buffer entry
            if enrollment.faces.isEmpty {
                try? FaceDataStore.shared.delete()
            } else {
                try? FaceDataStore.shared.save(enrollment)
            }
            refreshEnrolledFaces()
        }
    }
}

// MARK: - Behavior Settings

private struct BehaviorSettingsView: View {
    @AppStorage(FGConstants.launchAtLoginKey) private var launchAtLogin = false
    @AppStorage(FGConstants.lockOnSleepKey) private var lockOnSleep = false
    @State private var sessionTimeoutMinutes: Double = FGConstants.defaultSessionTimeout / 60
    @State private var uninstallProtection = UserDefaults.standard.bool(forKey: FGConstants.uninstallProtectionKey)
    @State private var isUpdatingUninstallProtection = false

    @AppStorage(FGConstants.emergencyKillEnabledKey) private var emergencyKillEnabled = true
    @AppStorage(FGConstants.emergencyKillModifierKey) private var emergencyKillModifier = "Command"
    @AppStorage(FGConstants.emergencyKillTriggerKey) private var emergencyKillKey = "`"

    @AppStorage(FGConstants.sessionTimerFromFocusKey) private var sessionTimerFromFocus = false

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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Session Timeout")
                        Spacer()
                        if sessionTimeoutMinutes == FGConstants.indefiniteSliderValue {
                            Text("Keep Unlocked Indefinitely")
                                .foregroundColor(.secondary)
                        } else if sessionTimeoutMinutes == 0 {
                            Text("Lock Immediately")
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(Int(sessionTimeoutMinutes)) min")
                                .foregroundColor(.secondary)
                        }
                    }
                    Slider(value: $sessionTimeoutMinutes, in: 0...FGConstants.indefiniteSliderValue, step: 1)
                        .onChangeCompat(of: sessionTimeoutMinutes) { newValue in
                            let timeout: TimeInterval = newValue == FGConstants.indefiniteSliderValue ? FGConstants.indefiniteSessionValue : newValue * 60
                            SessionManager.shared.setSessionTimeout(timeout)
                        }
                    Text("After unlocking an app, it stays unlocked for this duration before re-locking. Set to 0 to lock immediately after use, or set to 31 to keep unlocked until you manually lock from the menu bar.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    if sessionTimeoutMinutes > 0 && sessionTimeoutMinutes < FGConstants.indefiniteSliderValue {
                        Picker("Timer Mode", selection: $sessionTimerFromFocus) {
                            Text("From last unlock").tag(false)
                            Text("From when app loses focus").tag(true)
                        }
                        .pickerStyle(.menu)
                        if sessionTimerFromFocus {
                            Text("The timer only counts down while the app is not in focus. Switch away for the full duration to trigger a lock.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            Text("The timer counts total elapsed time since unlock, regardless of whether you're actively using the app.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }
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

                    HStack(spacing: 4) {
                        Text("Lock all apps between")

                        DatePicker("", selection: $lockStartTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.field)
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
                            .datePickerStyle(.field)
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
                        Text("Lock and unlock windows overlap. Lock takes priority — unlock will be skipped during the overlap.")
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

                    HStack(spacing: 4) {
                        Text("Unlock all apps between")

                        DatePicker("", selection: $unlockStartTime, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.field)
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
                            .datePickerStyle(.field)
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
                        Text("Lock and unlock windows overlap. Lock takes priority — unlock will be skipped during the overlap.")
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
                            .datePickerStyle(.field)
                        
                        Spacer()
                        
                        DatePicker("End Time", selection: endTimeBinding, displayedComponents: .hourAndMinute)
                            .datePickerStyle(.field)
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
                    HStack {
                        Text("Emergency Kill Shortcut")
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Toggle(isOn: $emergencyKillEnabled) { EmptyView() }
                            .toggleStyle(.switch)
                            .labelsHidden()
                            .accessibilityLabel("Enable Emergency Kill Shortcut")
                            .onChangeCompat(of: emergencyKillEnabled) { _ in
                                GlobalHotkeyManager.shared.reRegisterShortcut()
                            }
                    }
                    
                    if emergencyKillEnabled {
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
                }
            } header: {
                Text("Emergency")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
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
        .onChangeCompat(of: sessionTimerFromFocus) { _ in
            for bundleId in SessionManager.shared.activeSessions.keys {
                SessionManager.shared.refreshSessionForTimerMode(bundleId)
            }
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
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
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

            Link(destination: URL(string: "https://github.com/dweep-desai/FaceGate-Mac")!) {
                HStack(spacing: 6) {
                    Image("GitHubIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 18, height: 18)
                    Text("GitHub Repository")
                        .font(.system(size: 12))
                }
            }

            Link(destination: URL(string: "https://github.com/sponsors/dweep-desai")!) {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 14, height: 14)
                        .foregroundColor(.pink)
                    Text("Sponsor on GitHub")
                        .font(.system(size: 12))
                }
            }

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
    @State private var path = NavigationPath()

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
        NavigationStack(path: $path) {
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
                        VStack(spacing: 0) {
                            Text("Click an app to customize its session timer")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 8)
                                .padding(.bottom, 2)
                            lockedAppsList
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
            .onAppear {
                loadAppsIfNeeded()
            }
            .onDisappear {
                installedApps = []
            }
            .navigationDestination(for: LockedApp.self) { app in
                LockedAppDetailView(app: app, path: $path)
            }
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
                    LockedRowView(app: app, onToggle: {
                        withAnimation(.spring(response: 0.18, dampingFraction: 0.8, blendDuration: 0)) {
                            lockedAppsManager.unlockApp(app.bundleIdentifier)
                        }
                    }, onClick: {
                        path.append(app)
                    })
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
    let onClick: () -> Void
    @State private var isLocked = true
    @State private var isHovered = false
    @State private var isProcessing = false
    
    var body: some View {
        HStack(spacing: 12) {
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
                    HStack(spacing: 6) {
                        Text(app.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        
                        if app.customSessionTimeout != nil {
                            Image(systemName: "timer")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        }
                    }
                    Text(app.bundleIdentifier)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onClick()
            }

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

private struct LockedAppDetailView: View {
    let app: LockedApp
    @Binding var path: NavigationPath
    
    @ObservedObject var lockedAppsManager = LockedAppsManager.shared
    
    @State private var hasCustomTimer = false
    @State private var customTimeoutMinutes: Double = 5
    @State private var appTimerMode: Int = 0 // 0=global, 1=fromUnlock, 2=fromFocus
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Back Button
            HStack {
                Button(action: {
                    path.removeLast()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(app.displayName)
                    .font(.system(size: 14, weight: .bold))
                
                Spacer()
                
                // Placeholder to balance the back button
                Text("Back")
                    .font(.system(size: 13))
                    .opacity(0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                            } else {
                                Image(systemName: "app.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                                    .foregroundColor(.secondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(app.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(app.bundleIdentifier)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        // Custom session timer configurations
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Toggle("Custom Session Timer", isOn: $hasCustomTimer)
                                    .toggleStyle(.checkbox)
                                
                                Spacer()
                                
                                if hasCustomTimer {
                                    if customTimeoutMinutes == FGConstants.indefiniteSliderValue {
                                        Text("Keep Unlocked Indefinitely")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.blue)
                                    } else if customTimeoutMinutes == 0 {
                                        Text("Lock Immediately")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.blue)
                                    } else {
                                        Text("\(Int(customTimeoutMinutes)) min")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.blue)
                                    }
                                } else {
                                    let globalTimeout = SessionManager.shared.sessionTimeout / 60
                                    if globalTimeout == 0 {
                                        Text("Using Global Timer (Lock Immediately)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Using Global Timer (\(Int(globalTimeout)) min)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            HStack(spacing: 12) {
                                Slider(value: $customTimeoutMinutes, in: 0...FGConstants.indefiniteSliderValue, step: 1)
                                    .disabled(!hasCustomTimer)
                                
                                Text("0-31m")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .opacity(hasCustomTimer ? 1.0 : 0.5)

                            if hasCustomTimer && customTimeoutMinutes > 0 && customTimeoutMinutes < FGConstants.indefiniteSliderValue {
                                Picker("Timer Mode", selection: $appTimerMode) {
                                    Text("Use Global Setting").tag(0)
                                    Text("From last unlock").tag(1)
                                    Text("From when app loses focus").tag(2)
                                }
                                .pickerStyle(.menu)
                                switch appTimerMode {
                                case 1:
                                    Text("The timer counts total elapsed time since unlock, regardless of whether you're actively using the app.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                case 2:
                                    Text("The timer only counts down while the app is not in focus. Switch away for the full duration to trigger a lock.")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                default:
                                    let globalMode = UserDefaults.standard.bool(forKey: FGConstants.sessionTimerFromFocusKey)
                                    if globalMode {
                                        Text("Using global: timer counts from when app loses focus.")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Using global: timer counts total elapsed time since unlock.")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .formStyle(.grouped)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            if let activeApp = lockedAppsManager.lockedApps.first(where: { $0.bundleIdentifier == app.bundleIdentifier }) {
                if let custom = activeApp.customSessionTimeout {
                    hasCustomTimer = true
                    customTimeoutMinutes = custom == FGConstants.indefiniteSessionValue ? FGConstants.indefiniteSliderValue : custom / 60
                } else {
                    hasCustomTimer = false
                    // Restore last selection from UserDefaults if available, otherwise default to 5
                    let lastSelection = UserDefaults.standard.double(forKey: "lastCustomTimeout_\(app.bundleIdentifier)")
                    customTimeoutMinutes = lastSelection > 0 ? lastSelection : 5
                }
                if let mode = activeApp.timerFromFocus {
                    appTimerMode = mode ? 2 : 1
                } else {
                    appTimerMode = 0
                }
            }
        }
        .onChangeCompat(of: hasCustomTimer) { newValue in
            saveChanges(hasCustom: newValue, minutes: customTimeoutMinutes)
        }
        .onChangeCompat(of: customTimeoutMinutes) { newValue in
            saveChanges(hasCustom: hasCustomTimer, minutes: newValue)
        }
        .onChangeCompat(of: appTimerMode) { newValue in
            let fromFocus: Bool?
            switch newValue {
            case 1: fromFocus = false
            case 2: fromFocus = true
            default: fromFocus = nil
            }
            lockedAppsManager.updateTimerFromFocus(for: app.bundleIdentifier, fromFocus: fromFocus)
            SessionManager.shared.refreshSessionForTimerMode(app.bundleIdentifier)
        }
    }
    
    private func saveChanges(hasCustom: Bool, minutes: Double) {
        let timeout: TimeInterval? = hasCustom ? (minutes == FGConstants.indefiniteSliderValue ? FGConstants.indefiniteSessionValue : minutes * 60) : nil
        lockedAppsManager.updateCustomSessionTimeout(for: app.bundleIdentifier, timeout: timeout)
        if hasCustom {
            UserDefaults.standard.set(minutes, forKey: "lastCustomTimeout_\(app.bundleIdentifier)")
        }
        // Revoke existing session so the new timeout takes effect immediately.
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
