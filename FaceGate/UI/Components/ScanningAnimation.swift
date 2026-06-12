import SwiftUI

/// An animated scanning effect displayed during face authentication.
/// Shows a pulsing ring and scanning line animation to indicate active processing.
struct ScanningAnimation: View {
    /// Whether the scanning animation is active.
    var isScanning: Bool = true

    /// Whether a face match was found (triggers success animation).
    var isMatched: Bool = false

    @State private var rotation: Double = 0
    @State private var lineOffset: CGFloat = -1
    @State private var ringScale: CGFloat = 0.95
    @State private var glowOpacity: Double = 0.3

    var body: some View {
        ZStack {
            if isMatched {
                // Success state: green checkmark with expanding ring.
                successView
            } else if isScanning {
                // Scanning state: rotating arc + sweeping line.
                scanningView
            }
        }
        .frame(width: 200, height: 200)
    }

    // MARK: - Scanning State

    private var scanningView: some View {
        ZStack {
            // Outer pulsing ring.
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.58, saturation: 0.7, brightness: 0.95).opacity(0.4),
                            Color(hue: 0.58, saturation: 0.7, brightness: 0.95).opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .scaleEffect(ringScale)

            // Rotating arc segment.
            Circle()
                .trim(from: 0, to: 0.25)
                .stroke(
                    Color(hue: 0.58, saturation: 0.7, brightness: 0.95),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(rotation))

            // Subtle glow behind the ring.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hue: 0.58, saturation: 0.5, brightness: 0.9).opacity(glowOpacity),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 100
                    )
                )
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                ringScale = 1.05
                glowOpacity = 0.15
            }
        }
    }

    // MARK: - Success State

    private var successView: some View {
        ZStack {
            // Expanding green ring.
            Circle()
                .stroke(Color.green.opacity(0.6), lineWidth: 3)
                .scaleEffect(ringScale)

            // Green glow.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.green.opacity(0.2),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 100
                    )
                )

            // Checkmark.
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
                .scaleEffect(ringScale)
        }
        .onAppear {
            ringScale = 0.8
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                ringScale = 1.0
            }
        }
    }
}
