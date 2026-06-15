import SwiftUI

/// An animated direction guide shown between capture phases during face enrollment.
/// Displays a face icon with a pulsing arrow indicating which way to turn,
/// along with the direction instruction text.
struct DirectionGuideView: View {
    let direction: CaptureDirection

    @State private var animating = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)

            VStack(spacing: 8) {
                Spacer()

                ZStack {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 52))
                        .foregroundColor(.white)

                    if direction != .forward {
                        Image(systemName: "\(arrowSymbol).circle.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.blue)
                            .offset(arrowOffset)
                    }
                }
                .scaleEffect(animating ? 1.05 : 0.95)

                Text(direction.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Text("Get ready…")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                animating = true
            }
        }
    }

    private var arrowSymbol: String {
        switch direction {
        case .left: return "arrow.left"
        case .right: return "arrow.right"
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .forward: return ""
        }
    }

    private var arrowOffset: CGSize {
        switch direction {
        case .left: return CGSize(width: -45, height: 0)
        case .right: return CGSize(width: 45, height: 0)
        case .up: return CGSize(width: 0, height: -45)
        case .down: return CGSize(width: 0, height: 45)
        case .forward: return .zero
        }
    }
}

enum CaptureDirection: String {
    case forward = "Look straight ahead"
    case left = "Turn your head to the left"
    case right = "Turn your head to the right"
    case up = "Tilt your head up"
    case down = "Tilt your head down"
}
