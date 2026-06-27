import SwiftUI
import ServiceManagement

/// First-run onboarding wizard.
/// Guides the user through: permissions → face enrollment → set password → select apps to lock.
struct SetupView: View {
    @State private var currentStep: SetupStep = .welcome
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var passwordError: String?
    @State private var accessibilityGranted = false
    @State private var checkTimer: Timer?
    
    /// The name chosen for the first biometric face profile during onboarding setup.
    @State private var profileName = "Primary Face"

    /// Called when setup is complete.
    var onSetupComplete: () -> Void

    /// Called when user chooses to open settings instead.
    var onOpenSettings: (() -> Void)?

    enum SetupStep: Int, CaseIterable {
        case welcome
        case permissions
        case nameProfile
        case faceEnrollment
        case setPassword
        case selectApps
        case complete
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator.
            HStack(spacing: 8) {
                ForEach(SetupStep.allCases, id: \.rawValue) { step in
                    Capsule()
                        .fill(step.rawValue <= currentStep.rawValue
                              ? Color(hue: 0.58, saturation: 0.6, brightness: 0.85)
                              : Color(nsColor: .separatorColor))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            .padding(.bottom, 8)

            // Step content.
            Group {
                switch currentStep {
                case .welcome:
                    welcomeStep
                case .permissions:
                    permissionsStep
                case .nameProfile:
                    nameProfileStep
                case .faceEnrollment:
                    faceEnrollmentStep
                case .setPassword:
                    passwordStep
                case .selectApps:
                    selectAppsStep
                case .complete:
                    completeStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
        .frame(width: 560, height: 620)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
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

            VStack(spacing: 8) {
                Text("Welcome to FaceGate")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                Text("Lock your apps. Unlock with your face.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "faceid", color: .blue, title: "Face Unlock", subtitle: "Just look at your camera to unlock apps")
                FeatureRow(icon: "touchid", color: .pink, title: "Touch ID", subtitle: "Use your fingerprint as a fallback")
                FeatureRow(icon: "key.fill", color: .orange, title: "App Password", subtitle: "Set a custom password for emergency access")
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)

            Spacer()

            setupButton("Get Started") {
                currentStep = .permissions
            }
            .padding(.bottom, 30)
        }
    }

    private var permissionsStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Permissions")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("FaceGate needs these permissions to protect your apps.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            VStack(spacing: 16) {
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Required to monitor and block app launches",
                    isGranted: accessibilityGranted,
                    action: openAccessibilitySettings
                )

                PermissionRow(
                    icon: "camera.fill",
                    title: "Camera",
                    description: "Required for Face Unlock (granted on first use)",
                    isGranted: nil,
                    action: nil
                )
            }
            .padding(.horizontal, 40)

            Spacer()

            HStack(spacing: 12) {
                Button("Back") { currentStep = .welcome }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                setupButton("Continue") {
                    currentStep = .nameProfile
                }
            }
            .padding(.bottom, 30)
        }
        .onAppear {
            startAccessibilityCheck()
        }
        .onDisappear {
            checkTimer?.invalidate()
        }
    }

    private var faceEnrollmentStep: some View {
        VStack(spacing: 0) {
            FaceEnrollmentView(
                onComplete: {
                    currentStep = .setPassword
                },
                isInSettings: false,
                profileName: profileName
            )
        }
    }

    /// Step view prompting the user to name their face profile during onboarding setup.
    private var nameProfileStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "faceid.badge.plus")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Name Your Face Profile")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("Give your first face profile a name. This helps you identify and manage different registered faces later in settings.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    TextField("Profile Name (e.g. Primary Face, Work)", text: $profileName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                        .multilineTextAlignment(.leading)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .frame(maxWidth: 300)

                if profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Profile name cannot be empty")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                
                ProfilePreviewCard(name: profileName)
                    .padding(.top, 4)
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Back") { currentStep = .permissions }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                setupButton("Start Enrollment") {
                    if !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        currentStep = .faceEnrollment
                    }
                }
                .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
            }
            .padding(.bottom, 30)
        }
    }

    private var passwordStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 36))
                .foregroundColor(.orange)

            Text("Set App Password")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("This password is your emergency access method.\nYou'll use it if Face Unlock or Touch ID are unavailable.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            if PasswordAuth.shared.isPasswordSet {
                Text("A stored password from your previous install was found in the Keychain. You can keep it and skip this step.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .padding(.top, 4)
            }

            VStack(spacing: 12) {
                PasswordField(placeholder: PasswordAuth.shared.isPasswordSet ? "Choose a new password (optional)" : "Choose a password", text: $password)
                    .frame(maxWidth: 300)
                PasswordField(placeholder: PasswordAuth.shared.isPasswordSet ? "Confirm new password" : "Confirm password", text: $confirmPassword)
                    .frame(maxWidth: 300)

                if let error = passwordError {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button("Back") { currentStep = .faceEnrollment }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                if PasswordAuth.shared.isPasswordSet {
                    Button("Use Existing Password") {
                        currentStep = .selectApps
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(
                        Capsule()
                            .strokeBorder(Color.blue.opacity(0.5), lineWidth: 1)
                    )
                }

                setupButton("Set Password") {
                    savePassword()
                }
                .disabled(PasswordAuth.shared.isPasswordSet && password.isEmpty)
                .opacity(PasswordAuth.shared.isPasswordSet && password.isEmpty ? 0.5 : 1.0)
            }
            .padding(.bottom, 30)
        }
    }

    private var selectAppsStep: some View {
        VStack(spacing: 12) {
            Text("Select Apps to Lock")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .padding(.top, 20)

            Text("Choose which apps require authentication to open.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            AppPickerView()
                .frame(maxHeight: .infinity)

            HStack(spacing: 12) {
                Button("Back") { currentStep = .setPassword }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)

                setupButton("Finish Setup") {
                    currentStep = .complete
                }
            }
            .padding(.bottom, 20)
        }
    }

    private var completeStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.system(size: 24, weight: .bold, design: .rounded))

            VStack(spacing: 4) {
                let faceEnrolled = UserDefaults.standard.bool(forKey: FGConstants.faceEnrolledKey)
                if faceEnrolled {
                    Text("Face Unlock enrolled and enabled")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                } else {
                    Text("Face Unlock not enrolled (you can set it up later in Settings)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Text("FaceGate is now protecting your apps.\nLook for the shield icon in your menu bar.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            HStack(spacing: 4) {
                Image(FGConstants.menuBarIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("Find me in the menu bar")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            Spacer()

            VStack(spacing: 12) {
                setupButton("Start Protecting") {
                    finalizeSetup()
                    onSetupComplete()
                }

                Button("Configure Settings") {
                    finalizeSetup()
                    onOpenSettings?()
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .font(.system(size: 13))
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Helpers

    private func finalizeSetup() {
        UserDefaults.standard.set(true, forKey: FGConstants.setupCompletedKey)
        UserDefaults.standard.set(true, forKey: FGConstants.touchIDEnabledKey)
        UserDefaults.standard.set(true, forKey: FGConstants.launchAtLoginKey)
        if #available(macOS 13.0, *) {
            do {
                try SMAppService.mainApp.register()
            } catch {
                print("Failed to automatically register login item during setup: \(error)")
            }
        }
        for window in NSApp.windows {
            if window.title == "FaceGate Setup" {
                window.close()
            }
        }
    }

    private func setupButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 200, height: 38)
                .background(
                    Capsule()
                        .fill(Color.blue)
                )
        }
        .buttonStyle(.plain)
    }

    private func savePassword() {
        passwordError = nil
        guard !password.isEmpty else {
            passwordError = "Password cannot be empty"
            return
        }
        guard password.count >= 4 else {
            passwordError = "Password must be at least 4 characters"
            return
        }
        guard password == confirmPassword else {
            passwordError = "Passwords don't match"
            return
        }

        do {
            try PasswordAuth.shared.setPassword(password)
            currentStep = .selectApps
        } catch {
            passwordError = "Failed to save: \(error.localizedDescription)"
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func startAccessibilityCheck() {
        checkAccessibility()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            checkAccessibility()
        }
    }

    private func checkAccessibility() {
        accessibilityGranted = AXIsProcessTrusted()
    }
}

// MARK: - Supporting Views

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool?
    let action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let granted = isGranted {
                if granted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if let action = action {
                    Button("Grant", action: action)
                        .controlSize(.small)
                }
            } else {
                Text("Auto")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(nsColor: .controlBackgroundColor)))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

/// A premium real-time preview card displaying the name and type of biometric key profile being registered.
private struct ProfilePreviewCard: View {
    let name: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 28))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "New Profile" : name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Biometric Key Profile")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .frame(maxWidth: 300)
    }
}
