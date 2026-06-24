import AVFoundation
import SwiftUI

/// Face enrollment UI view with camera preview, face guide, and progress tracking.
/// Used during initial setup and when re-enrolling from settings.
struct FaceEnrollmentView: View {
    @StateObject private var enrollmentManager = FaceEnrollmentManager()

    /// Called when enrollment completes (success or skip).
    var onComplete: () -> Void

    /// Whether this is shown in settings (allows cancel) vs onboarding (allows skip).
    var isInSettings: Bool = false

    @State private var cameraAuthorization: AVAuthorizationStatus = .notDetermined

    private var staticStatusMessage: String {
        switch enrollmentManager.state {
        case .idle:
            return "Position your face in the frame"
        case .capturing:
            return "Follow the prompts on the camera screen"
        case .processing:
            return "Processing face data…"
        case .success:
            return "Face enrolled successfully!"
        case .failed(let message):
            return "Enrollment failed: \(message)"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header.
            VStack(spacing: 8) {
                Image(systemName: "faceid")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hue: 0.58, saturation: 0.7, brightness: 0.95),
                                     Color(hue: 0.61, saturation: 0.75, brightness: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text("Face Enrollment")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text(staticStatusMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
            .padding(.top, 12)
            .padding(.bottom, 4)

            // Warning message (above the video screen)
            VStack(spacing: 2) {
                Text(enrollmentManager.warningMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(height: 20)

            }
            .animation(.easeInOut(duration: 0.25), value: enrollmentManager.warningMessage)
            .padding(.bottom, 6)

            // Camera preview or permission-denied state.
            ZStack {
                if cameraAuthorization == .denied || cameraAuthorization == .restricted {
                    cameraDeniedView
                } else if enrollmentManager.state == .capturing || enrollmentManager.state == .idle {
                    CameraPreviewView(captureSession: enrollmentManager.camera.captureSession)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    FaceGuideOverlay(
                        faceDetected: enrollmentManager.capturedCount > 0,
                        quality: enrollmentManager.currentQuality
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if enrollmentManager.state == .capturing {
                        directionIndicator(for: enrollmentManager.currentStep)
                    }

                } else if enrollmentManager.state == .processing {
                    processingView
                } else if enrollmentManager.state == .success {
                    successView
                } else if case .failed(let message) = enrollmentManager.state {
                    failedView(message: message)
                }
            }
            .frame(width: 320, height: 240)
            .background(Color.black.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )

            // Progress bar.
            if enrollmentManager.state == .capturing {
                VStack(spacing: 6) {
                    ProgressView(
                        value: Double(enrollmentManager.capturedCount),
                        total: Double(enrollmentManager.targetFrameCount)
                    )
                    .progressViewStyle(.linear)
                    .tint(Color(hue: 0.58, saturation: 0.6, brightness: 0.85))

                    Text("\(enrollmentManager.capturedCount) of \(enrollmentManager.targetFrameCount) captures")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }

            Spacer()

            // Action buttons.
            actionButtons
                .padding(.bottom, 16)
        }
        .frame(width: 420, height: isInSettings ? 530 : 490)
        .onAppear {
            checkCameraAndStart()
        }
        .onDisappear {
            // If the window is closed before enrollment finishes (e.g. user clicks
            // the close button mid-capture), cancel enrollment so the camera stops
            // and display brightness is restored to its original value.
            if enrollmentManager.state == .capturing || enrollmentManager.state == .processing {
                enrollmentManager.cancelEnrollment()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard enrollmentManager.state == .idle else { return }
            checkCameraAndStart()
        }
    }

    // MARK: - Camera Permission

    private func checkCameraAndStart() {
        cameraAuthorization = AVCaptureDevice.authorizationStatus(for: .video)
        switch cameraAuthorization {
        case .authorized:
            enrollmentManager.camera.permissionGranted = true
            enrollmentManager.camera.error = nil
            enrollmentManager.startEnrollment()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak enrollmentManager] granted in
                DispatchQueue.main.async {
                    guard granted, let manager = enrollmentManager else { return }
                    manager.camera.permissionGranted = true
                    manager.startEnrollment()
                }
            }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Camera Denied View

    private var cameraDeniedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill.badge.exclamationmark")
                .font(.system(size: 36))
                .foregroundColor(.red.opacity(0.8))

            Text("Camera Access Denied")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Text("FaceGate needs camera access to enroll your face. Please enable it in System Settings.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                CameraManager.openSystemSettings()
            } label: {
                Text("Open System Settings")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.blue))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - State Views

    private var processingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Processing face data…")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var successView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("Face Enrolled!")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text("\(enrollmentManager.capturedCount) reference captures saved")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    private func failedView(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            Text("Enrollment Failed")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        if cameraAuthorization == .denied || cameraAuthorization == .restricted {
            secondaryButton(isInSettings ? "Cancel" : "Skip") {
                onComplete()
            }
        } else {
            switch enrollmentManager.state {
            case .idle:
                secondaryButton(isInSettings ? "Cancel" : "Skip for Now") {
                    onComplete()
                }

            case .capturing:
                VStack(spacing: 8) {
                    primaryButton("Recapture") {
                        enrollmentManager.startEnrollment()
                    }
                    secondaryButton(isInSettings ? "Cancel" : "Skip for Now") {
                        enrollmentManager.cancelEnrollment()
                        onComplete()
                    }
                }

            case .processing:
                EmptyView()

            case .success:
                primaryButton("Continue") {
                    onComplete()
                }

            case .failed:
                VStack(spacing: 10) {
                    primaryButton("Try Again") {
                        enrollmentManager.startEnrollment()
                    }
                    secondaryButton(isInSettings ? "Cancel" : "Skip") {
                        onComplete()
                    }
                }
            }
        }
    }

    // MARK: - Button Styles

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
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

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func directionIndicator(for step: FaceEnrollmentManager.EnrollmentStep) -> some View {
        if step != .straight {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    AnimatedDirectionIndicator(
                        icon: indicatorIcon(for: step),
                        direction: step == .left ? .left : (step == .right ? .right : .tilt)
                    )
                    .padding(8)
                }
            }
        }
    }

    private func indicatorIcon(for step: FaceEnrollmentManager.EnrollmentStep) -> String {
        switch step {
        case .straight: return ""
        case .left: return "arrow.left.circle.fill"
        case .right: return "arrow.right.circle.fill"
        case .tilt: return "arrowshape.turn.up.right.fill"
        }
    }
}
