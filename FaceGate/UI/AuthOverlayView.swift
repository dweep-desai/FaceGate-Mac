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
    @State private var didAuthenticate: Bool = false
    @State private var lastFallbackMethod: AuthMethod? = nil

    private var isAuthenticatingWithTouchID: Bool {
        if case .authenticating(let method) = authManager.authState, method == .touchID {
            return true
        }
        return false
    }

    private var isFaceUnlockBroken: Bool {
        if case .error(_) = faceAuthManager.state { return true }
        return false
    }

    private var isCompactMode: Bool {
        if authManager.authState == .success { return true }
        if authManager.isFaceUnlockAvailable && !showFallbacks && !showPasswordField && !isTimedOut && !isAuthenticatingWithTouchID {
            return false
        }
        return true
    }

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
                // Top Padding
                Spacer().frame(height: isCompactMode ? 24 : 32)

                // --- HEADER SECTION ---
                Image(nsImage: NSApplication.shared.applicationIconImage ?? NSWorkspace.shared.icon(for: .applicationBundle))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .padding(.bottom, 12)

                Text("FaceGate")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 8)

                Text(isAppLocking ? "\(appName) is Locked" : appName)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 6)

                if isTimedOut {
                    Text("Face Recognition Timed Out")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.red.opacity(0.8))
                } else {
                    Text(subtitleMessage ?? (isAppLocking ? "Authenticate to unlock this app" : "Authenticate to proceed"))
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                }

                // Gap
                Spacer().frame(height: isCompactMode ? 16 : 24)

                // --- CENTER ICON SECTION ---
                if authManager.authState == .success {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.green)
                        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
                } else if authManager.isFaceUnlockAvailable && !showFallbacks && !showPasswordField && !isTimedOut && !isAuthenticatingWithTouchID {
                    faceUnlockView
                } else {
                    Group {
                        if showPasswordField {
                            Image(systemName: "lock.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .foregroundColor(.orange.opacity(0.8))
                        } else if isAuthenticatingWithTouchID {
                            Image(systemName: "touchid")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .foregroundColor(.blue.opacity(0.8))
                        } else {
                            if isAppLocking {
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 90, height: 90)
                            } else {
                                Image(systemName: "lock.rectangle.on.rectangle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 64, height: 64)
                                    .foregroundColor(.orange.opacity(0.8))
                            }
                        }
                    }
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
                }

                // Gap
                Spacer().frame(height: isCompactMode ? 12 : 16)

                // --- FEEDBACK SECTION ---
                VStack(spacing: 0) {
                    if authManager.authState != .success && !faceAuthManager.warningMessage.isEmpty && authManager.isFaceUnlockAvailable && !showFallbacks && !showPasswordField && !isTimedOut && !isAuthenticatingWithTouchID {
                        Text(faceAuthManager.warningMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                    } else if authManager.authState != .success && !faceAuthManager.statusMessage.isEmpty && authManager.isFaceUnlockAvailable && !showFallbacks && !showPasswordField && !isTimedOut && !isAuthenticatingWithTouchID {
                        Text(faceAuthManager.statusMessage)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.white.opacity(0.12)))
                    } else if authManager.authState != .idle {
                        authFeedbackView
                    } else {
                        Spacer().frame(height: isCompactMode ? 16 : 24)
                    }
                }

                // Gap
                Spacer().frame(height: isCompactMode ? 12 : 16)

                // --- CONTROLS SECTION ---
                VStack(spacing: 0) {
                    if showPasswordField {
                        passwordAuthView
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if showFallbacks || isTimedOut || !authManager.isFaceUnlockAvailable {
                        authButtonsView
                            .transition(.opacity)
                    } else {
                        VStack(spacing: 12) {
                            Text("— or authenticate with —")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                            
                            HStack(spacing: 16) {
                                if isAuthenticatingWithTouchID {
                                    if authManager.isFaceUnlockAvailable {
                                        smallFallbackButton(icon: "faceid", label: "Face ID") {
                                            authManager.stopTouchIDAuth()
                                            showFallbacks = false
                                            startFaceUnlockProcess()
                                        }
                                    }
                                } else {
                                    if TouchIDAuth.shared.canUse {
                                        smallFallbackButton(icon: "touchid", label: "Touch ID") {
                                            authenticateWithTouchID()
                                        }
                                    }
                                }
                                smallFallbackButton(icon: "key.fill", label: "Password") {
                                    showPasswordAuth()
                                }
                            }
                        }
                    }
                }

                // Gap
                Spacer().frame(height: isCompactMode ? 24 : 32)

                // --- FOOTER SECTION ---
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

                // Bottom Padding
                Spacer().frame(height: isCompactMode ? 16 : 24)
            }
            .frame(maxWidth: 360, maxHeight: .infinity)
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
                                guard !didAuthenticate else { return }
                                didAuthenticate = true
                                onAuthenticated()
                                authManager.resetAttempts()
                            }
                    } else {
                        withAnimation {
                            showFallbacks = true
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
                    guard !didAuthenticate else { return }
                    didAuthenticate = true
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
            } else if case .error(_) = newState {
                withAnimation {
                    showFallbacks = true
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
                .frame(width: 160, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))

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
        .frame(width: 160, height: 160)
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
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
                    Text("Authenticating with \(method.displayName)")
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
            if authManager.isFaceUnlockAvailable, !isFaceUnlockBroken {
                Button(action: {
                    withAnimation {
                        showFallbacks = false
                        isTimedOut = false
                        faceAuthStarted = true
                        authManager.authenticateWithFace { success in
                            if success {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    guard !didAuthenticate else { return }
                                    didAuthenticate = true
                                    onAuthenticated()
                                    authManager.resetAttempts()
                                }
                            } else {
                                withAnimation {
                                    showFallbacks = true
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
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    )
            }
            .buttonStyle(.plain)
            .focusable(false)
            .padding(.top, 4)
            .disabled(passwordInput.isEmpty)

            // Dynamic fallback links
            VStack(spacing: 12) {
                Text("— or authenticate with —")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.top, 8)
                
                HStack(spacing: 16) {
                    if authManager.isFaceUnlockAvailable {
                        smallFallbackButton(icon: "faceid", label: "Face ID") {
                            withAnimation {
                                showPasswordField = false
                                showFallbacks = false
                            }
                            startFaceUnlockProcess()
                        }
                    }
                    if TouchIDAuth.shared.canUse {
                        smallFallbackButton(icon: "touchid", label: "Touch ID") {
                            withAnimation {
                                showPasswordField = false
                            }
                            authenticateWithTouchID()
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 280)
    }

    // MARK: - Actions

    private func authenticateWithTouchID() {
        authManager.stopFaceAuth()
        withAnimation {
            showFallbacks = false
        }
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
        authManager.stopTouchIDAuth()
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
    
    private func startFaceUnlockProcess() {
        withAnimation {
            showFallbacks = false
            showPasswordField = false
            isTimedOut = false
            faceAuthStarted = true
            authManager.authenticateWithFace { success in
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        guard !didAuthenticate else { return }
                        didAuthenticate = true
                        onAuthenticated()
                        authManager.resetAttempts()
                    }
                } else {
                    withAnimation {
                        showFallbacks = true
                    }
                }
            }
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
