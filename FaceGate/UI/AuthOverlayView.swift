import AppKit
import SwiftUI

/// The SwiftUI view displayed inside the auth overlay panel.
/// Shows the locked app's icon, name, and authentication options.
/// When face unlock is enabled, shows live camera preview with face scanning animation.
struct AuthOverlayView: View {
    let appName: String
    let appIcon: NSImage
    var isAppLocking: Bool = true
    var cancelButtonTitle: String = "Cancel & Close App"
    var subtitleMessage: String? = nil
    let onAuthenticated: () -> Void
    let onCancel: () -> Void

    @StateObject private var authManager = AuthenticationManager.shared
    @ObservedObject private var faceAuthManager = AuthenticationManager.shared.faceAuthManager
    @State private var passwordInput: String = ""
    @FocusState private var isPasswordFocused: Bool
    @State private var showPasswordField: Bool = false
    @State private var showFallbacks: Bool = false
    @State private var shakePassword: Bool = false
    @State private var faceAuthStarted: Bool = false
    @State private var isTimedOut: Bool = false

    var body: some View {
        ZStack {
            // Dark blurred background.
            VisualEffectBackground(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Semi-transparent dark overlay for extra dimming.
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Content.
            VStack(spacing: 0) {
                Spacer()

                // Menu bar icon.
                Image(FGConstants.menuBarIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hue: 0.58, saturation: 0.7, brightness: 0.95),
                                     Color(hue: 0.61, saturation: 0.75, brightness: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.bottom, 12)

                // App name.
                Text("FaceGate")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 8)

                // "App Name is Locked".
                Text(isAppLocking ? "\(appName) is Locked" : appName)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 6)

                // Subtitle message / Timeout.
                if isTimedOut {
                    Text("Face Recognition Timed Out")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.bottom, 10)
                } else {
                    Text(subtitleMessage ?? (isAppLocking ? "Authenticate to unlock this app" : "Authenticate to proceed"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.bottom, 10)
                }

                // Warning message (above the video screen)
                Text(faceAuthManager.warningMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(height: 20)
                    .padding(.bottom, 8)

                // Face Unlock camera preview (if available and enabled).
                if authManager.isFaceUnlockAvailable && !showFallbacks && !showPasswordField && !isTimedOut {
                    faceUnlockView
                        .padding(.bottom, 12)
                    
                    // Dynamic Liveness Instruction text below the video box
                    Text(faceAuthManager.statusMessage)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white.opacity(0.12)))
                        .padding(.bottom, 16)
                } else {
                    // App icon (shown when face unlock is not active).
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
                        .padding(.bottom, 16)
                }

                // Auth state feedback.
                authFeedbackView
                    .frame(height: isLockedOut ? 64 : 24)
                    .padding(.bottom, 16)

                // Auth methods.
                if showPasswordField {
                    passwordAuthView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else if showFallbacks || isTimedOut || !authManager.isFaceUnlockAvailable {
                    authButtonsView
                        .transition(.opacity)
                } else {
                    // Face unlock active — show "use other method" link.
                    Button(action: {
                        withAnimation {
                            showFallbacks = true
                            authManager.stopFaceAuth()
                        }
                    }) {
                        Text("— or authenticate with —")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .padding(.top, 8)

                    // Show fallback buttons below face unlock.
                    HStack(spacing: 16) {
                        if TouchIDAuth.shared.canUse {
                            smallFallbackButton(icon: "touchid", label: "Touch ID") {
                                authenticateWithTouchID()
                            }
                        }
                        smallFallbackButton(icon: "key.fill", label: "Password") {
                            showPasswordAuth()
                        }
                    }
                    .padding(.top, 8)
                }

                Spacer()

                // Cancel button at bottom.
                Button(action: {
                    authManager.stopFaceAuth()
                    onCancel()
                }) {
                    Text(cancelButtonTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .focusable(false)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: 360)
            .animation(.easeInOut(duration: 0.25), value: showPasswordField)
            .animation(.easeInOut(duration: 0.25), value: showFallbacks)
            .animation(.easeInOut(duration: 0.2), value: authManager.authState)
        }
        .onAppear {
            // Auto-start face unlock if available.
            if authManager.isFaceUnlockAvailable && !faceAuthStarted {
                faceAuthStarted = true
                authManager.authenticateWithFace { success in
                    if success {
                        // Small delay for visual feedback before dismissing.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            onAuthenticated()
                            authManager.resetAttempts()
                        }
                    }
                }
            } else if !authManager.isFaceUnlockAvailable {
                if TouchIDAuth.shared.canUse {
                    authenticateWithTouchID()
                } else {
                    showPasswordAuth()
                }
            }
        }
        .onChangeCompat(of: authManager.authState) { newState in
            if case .success = newState {
                // Small delay for visual feedback before dismissing.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onAuthenticated()
                    authManager.resetAttempts()
                }
            }
        }
        .onChangeCompat(of: faceAuthManager.state) { newState in
            if newState == .timeout {
                withAnimation {
                    isTimedOut = true
                    authManager.stopFaceAuth()
                }
            }
        }
        .onDisappear {
            authManager.stopFaceAuth()
        }
        .onChangeCompat(of: showPasswordField) { newValue in
            if newValue {
                NSApp.activate(ignoringOtherApps: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isPasswordFocused = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if !isPasswordFocused {
                        isPasswordFocused = true
                    }
                }
            }
        }
    }

    private var isLockedOut: Bool {
        if case .lockedOut = authManager.authState {
            return true
        }
        return false
    }

    // MARK: - Face Unlock View

    @ViewBuilder
    private var faceUnlockView: some View {
        ZStack {
            // Camera preview.
            CameraPreviewView(captureSession: faceAuthManager.cameraManager.captureSession)
                .frame(width: 200, height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            // Scanning animation overlay.
            ScanningAnimation(
                isScanning: faceAuthManager.state == .scanning,
                isMatched: faceAuthManager.state == .matched
            )

            // Liveness direction indicator overlay.
            if let challenge = faceAuthManager.activeChallenge {
                directionIndicator(for: challenge)
            }
        }
        .frame(width: 200, height: 200)
    }

    // MARK: - Small Fallback Buttons

    private func smallFallbackButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(width: 80, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
            .foregroundColor(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
        .focusable(false)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var authFeedbackView: some View {
        switch authManager.authState {
        case .idle:
            Color.clear
        case .authenticating(let method):
            if method != .faceUnlock {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .colorScheme(.dark)
                    Text("Authenticating with \(method.displayName)…")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        case .success:
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Authenticated!")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.green)
            }
        case .failed(let message):
            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.8))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.8))
            }
        case .lockedOut(let duration):
            VStack(spacing: 4) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                Text("Too many failed attempts")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.orange)
                Text("Try again in \(Int(duration)) seconds")
                    .font(.system(size: 11))
                    .foregroundColor(.orange.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private var authButtonsView: some View {
        VStack(spacing: 12) {
            // Face Unlock button (if available but user navigated to fallbacks).
            if authManager.isFaceUnlockAvailable {
                Button(action: {
                    withAnimation {
                        showFallbacks = false
                        isTimedOut = false
                        faceAuthStarted = true
                        authManager.authenticateWithFace { success in
                            if success {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    onAuthenticated()
                                    authManager.resetAttempts()
                                }
                            }
                        }
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 18))
                        Text("Try Face Unlock Again")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hue: 0.58, saturation: 0.5, brightness: 0.8).opacity(0.3),
                                        Color(hue: 0.61, saturation: 0.6, brightness: 0.75).opacity(0.3),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            // Touch ID button (if available).
            if TouchIDAuth.shared.canUse {
                Button(action: authenticateWithTouchID) {
                    HStack(spacing: 10) {
                        Image(systemName: "touchid")
                            .font(.system(size: 18))
                        Text("Unlock with Touch ID")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .focusable(false)
            }

            // Password button.
            Button(action: showPasswordAuth) {
                HStack(spacing: 10) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 16))
                    Text("Use Password")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                )
                .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .focusable(false)
        }
        .frame(maxWidth: 280)
    }

    @ViewBuilder
    private var passwordAuthView: some View {
        VStack(spacing: 16) {
            // Password input field.
            SecureField("Enter password", text: $passwordInput)
                .focused($isPasswordFocused)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
                .offset(x: shakePassword ? -8 : 0)
                .animation(
                    shakePassword
                        ? Animation.default.repeatCount(4, autoreverses: true).speed(6)
                        : .default,
                    value: shakePassword
                )
                .onSubmit {
                    submitPassword()
                }

            HStack(spacing: 12) {
                // Back button.
                Button(action: {
                    withAnimation {
                        showFallbacks = true
                        showPasswordField = false
                        passwordInput = ""
                    }
                }) {
                    Text("Back")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 80, height: 36)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                        )
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .focusable(false)

                // Unlock button.
                Button(action: submitPassword) {
                    Text("Unlock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                        )
                }
                .buttonStyle(.plain)
                .focusable(false)
                .disabled(passwordInput.isEmpty)
            }
        }
        .frame(maxWidth: 280)
    }

    // MARK: - Actions

    private func authenticateWithTouchID() {
        authManager.stopFaceAuth()
        authManager.authenticateWithTouchID(appName: appName) { success in
            if !success {
                withAnimation {
                    showFallbacks = true
                }
            }
        }
    }

    private func showPasswordAuth() {
        authManager.stopFaceAuth()
        NSApp.activate(ignoringOtherApps: true)
        withAnimation {
            showPasswordField = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isPasswordFocused = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if !isPasswordFocused {
                isPasswordFocused = true
            }
        }
    }

    private func submitPassword() {
        guard !passwordInput.isEmpty else { return }

        let success = authManager.authenticateWithPassword(passwordInput)
        if !success {
            // Shake animation on failure.
            shakePassword = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                shakePassword = false
            }
            passwordInput = ""
        }
    }

    @ViewBuilder
    private func directionIndicator(for challenge: FaceAuthManager.LivenessChallenge) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                AnimatedDirectionIndicator(
                    icon: indicatorIcon(for: challenge),
                    direction: challenge == .turnLeft ? .left : (challenge == .turnRight ? .right : .tilt)
                )
                .padding(8)
            }
        }
    }

    private func indicatorIcon(for challenge: FaceAuthManager.LivenessChallenge) -> String {
        switch challenge {
        case .turnLeft: return "arrow.left.circle.fill"
        case .turnRight: return "arrow.right.circle.fill"
        case .tiltHead: return "arrowshape.turn.up.right.fill"
        }
    }
}

// MARK: - Visual Effect (NSVisualEffectView wrapper)

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
