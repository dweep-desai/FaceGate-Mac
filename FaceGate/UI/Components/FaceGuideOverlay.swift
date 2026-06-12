import SwiftUI

/// An animated oval guide overlay displayed on top of the camera preview.
/// Helps the user position their face correctly during enrollment and authentication.
struct FaceGuideOverlay: View {
    /// Whether a face is currently detected within the guide area.
    var faceDetected: Bool = false

    /// Quality of the current detection (0.0–1.0), affects border color intensity.
    var quality: Float = 0

    @State private var pulseScale: CGFloat = 1.0
    @State private var borderOpacity: Double = 0.6

    var body: some View {
        ZStack {
            // Outer dimming mask with oval cutout.
            GeometryReader { geometry in
                let ovalWidth = geometry.size.width * 0.55
                let ovalHeight = geometry.size.height * 0.7
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Semi-transparent overlay with oval hole.
                Canvas { context, size in
                    // Full rectangle.
                    var fullPath = Path()
                    fullPath.addRect(CGRect(origin: .zero, size: size))

                    // Oval cutout.
                    var ovalPath = Path()
                    ovalPath.addEllipse(in: CGRect(
                        x: center.x - ovalWidth / 2,
                        y: center.y - ovalHeight / 2,
                        width: ovalWidth,
                        height: ovalHeight
                    ))

                    context.fill(fullPath, with: .color(.black.opacity(0.4)))
                    context.blendMode = .clear
                    context.fill(ovalPath, with: .color(.white))
                }

                // Oval border.
                Ellipse()
                    .stroke(
                        faceDetected
                            ? Color.green.opacity(borderOpacity)
                            : Color.white.opacity(borderOpacity * 0.6),
                        lineWidth: faceDetected ? 3 : 2
                    )
                    .frame(width: ovalWidth, height: ovalHeight)
                    .position(center)
                    .scaleEffect(pulseScale)
            }
        }
        .allowsHitTesting(false)  // Don't intercept touches.
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = faceDetected ? 1.0 : 1.02
                borderOpacity = faceDetected ? 0.9 : 0.4
            }
        }
        .onChangeCompat(of: faceDetected) { detected in
            withAnimation(.easeInOut(duration: 0.3)) {
                pulseScale = detected ? 1.0 : 1.02
                borderOpacity = detected ? 0.9 : 0.4
            }
        }
    }
}
