import SwiftUI

/// An animated icon showing head turn cues with bouncing animations.
struct AnimatedDirectionIndicator: View {
    let icon: String
    let direction: IndicatorDirection
    
    enum IndicatorDirection {
        case left
        case right
        case up
        case down
    }
    
    @State private var offset: CGFloat = 0
    
    var body: some View {
        if !icon.isEmpty {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.blue)
                .padding(12)
                .background(Circle().fill(Color.black.opacity(0.65)))
                .offset(
                    x: direction == .left ? -offset : (direction == .right ? offset : 0),
                    y: direction == .up ? -offset : (direction == .down ? offset : 0)
                )
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: offset
                )
                .onAppear {
                    offset = 6
                }
        }
    }
}
