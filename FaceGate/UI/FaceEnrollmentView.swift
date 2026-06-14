import SwiftUI

/// Face enrollment UI view with camera preview, face guide, and progress tracking.
/// Used during initial setup and when re-enrolling from settings.
struct FaceEnrollmentView: View {
    @StateObject private var enrollmentManager = FaceEnrollmentManager()

    /// Called when enrollment completes (success or skip).
    var onComplete: () -> Void

    /// Whether this is shown in settings (allows cancel) vs onboarding (allows skip).
    var isInSettings: Bool = false

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

                Text(enrollmentManager.statusMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .animation(.easeInOut(duration: 0.2), value: enrollmentManager.statusMessage)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Camera preview with face guide.
            ZStack {
                if enrollmentManager.state == .capturing || enrollmentManager.state == .idle {
                    CameraPreviewView(captureSession: enrollmentManager.camera.captureSession)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    FaceGuideOverlay(
                        faceDetected: enrollmentManager.capturedCount > 0,
                        quality: enrollmentManager.currentQuality
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
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
                .padding(.top, 12)
            }

            Spacer()

            // Action buttons.
            actionButtons
                .padding(.bottom, 20)
        }
        .frame(width: 420, height: isInSettings ? 460 : 420)
        .onAppear {
            enrollmentManager.startEnrollment()
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
        switch enrollmentManager.state {
        case .idle:
            secondaryButton(isInSettings ? "Cancel" : "Skip for Now") {
                onComplete()
            }

        case .capturing:
            secondaryButton(isInSettings ? "Cancel" : "Skip for Now") {
                enrollmentManager.cancelEnrollment()
                onComplete()
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
}
