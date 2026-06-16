import SwiftUI

/// An animated icon showing head turn/tilt cues with bouncing or rocking rotation animations.
struct AnimatedDirectionIndicator: View {
    let icon: String
    let direction: IndicatorDirection
    
    enum IndicatorDirection {
        case left
        case right
        case tilt
    }
    
    @State private var offset: CGFloat = 0
    @State private var rotation: Double = -90
    
    var body: some View {
        if direction == .tilt {
            CurvedArrowShape()
                .fill(Color.blue)
                .frame(width: 24, height: 24)
                .padding(12)
                .background(Circle().fill(Color.black.opacity(0.65)))
                .rotationEffect(.degrees(rotation))
                .animation(
                    .easeInOut(duration: 1.2).repeatForever(autoreverses: false),
                    value: rotation
                )
                .onAppear {
                    rotation = 0
                }
        } else if !icon.isEmpty {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.blue)
                .padding(12)
                .background(Circle().fill(Color.black.opacity(0.65)))
                .offset(x: direction == .left ? -offset : (direction == .right ? offset : 0))
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

struct CurvedArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        let center = CGPoint(x: w * 0.70, y: h * 0.70)
        let outerRadius = w * 0.60
        let innerRadius = w * 0.38
        
        // Outer arc starting from 180 degrees (left) to 270 degrees (up)
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        // Arrowhead pointing right at the end of the arc
        let arrowTipY = center.y - (outerRadius + innerRadius) / 2
        let arrowTipX = center.x + w * 0.24
        
        let barbYTop = center.y - outerRadius - w * 0.09
        let barbYBottom = center.y - innerRadius + w * 0.09
        
        path.addLine(to: CGPoint(x: center.x, y: barbYTop))
        path.addLine(to: CGPoint(x: arrowTipX, y: arrowTipY))
        path.addLine(to: CGPoint(x: center.x, y: barbYBottom))
        path.addLine(to: CGPoint(x: center.x, y: center.y - innerRadius))
        
        // Inner arc back from 270 degrees (up) to 180 degrees (left)
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(180),
            clockwise: true
        )
        
        path.closeSubpath()
        return path
    }
}
