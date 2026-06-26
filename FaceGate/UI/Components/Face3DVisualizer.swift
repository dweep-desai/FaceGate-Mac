import SwiftUI
import SceneKit

/// Represents the extracted facial landmarks and head orientation angles.
/// Used to animate the 3D visualizer.
public struct FaceWireframeData: Equatable {
    public var yaw: Double = 0.0
    public var pitch: Double = 0.0
    public var roll: Double = 0.0
    
    // Normalized 2D coordinates for facial landmarks
    public var outlinePoints: [CGPoint] = []
    public var leftEyePoints: [CGPoint] = []
    public var rightEyePoints: [CGPoint] = []
    public var nosePoints: [CGPoint] = []
    public var lipsPoints: [CGPoint] = []
    
    public init() {}
}

/// A futuristic holographic grid pattern view shown behind the 3D face.
struct HolographicGridPattern: View {
    var body: some View {
        Canvas { context, size in
            let cols = 16
            let rows = 16
            let colWidth = size.width / CGFloat(cols)
            let rowHeight = size.height / CGFloat(rows)
            
            context.stroke(
                Path { path in
                    // Vertical lines
                    for i in 0...cols {
                        let x = CGFloat(i) * colWidth
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                    }
                    
                    // Horizontal lines
                    for i in 0...rows {
                        let y = CGFloat(i) * rowHeight
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                },
                with: .color(Color.cyan.opacity(0.1)),
                lineWidth: 1
            )
        }
    }
}

/// A stub holographic 3D wireframe head view that will mirror the user's head rotations.
/// Fully customizable with future landmark bindings.
public struct HolographicFaceView: View {
    public let faceData: FaceWireframeData
    
    public init(faceData: FaceWireframeData) {
        self.faceData = faceData
    }
    
    public var body: some View {
        ZStack {
            // Neon matrix-like grid background
            HolographicGridPattern()
                .opacity(0.2)
            
            // Stylized 3D-oriented face visualization using native Canvas
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.35
                
                // Draw base head oval
                var baseCircle = Path()
                baseCircle.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius * 1.2, width: radius * 2, height: radius * 2.4))
                context.stroke(baseCircle, with: .color(Color.cyan.opacity(0.4)), lineWidth: 1.5)
                
                // Draw grid lines on the sphere to simulate a 3D grid sphere
                for i in 1...3 {
                    let offset = CGFloat(i) * 0.25 * radius
                    
                    // Horizontal latitude lines
                    var latPath = Path()
                    latPath.move(to: CGPoint(x: center.x - sqrt(radius*radius - offset*offset), y: center.y - offset))
                    latPath.addLine(to: CGPoint(x: center.x + sqrt(radius*radius - offset*offset), y: center.y - offset))
                    latPath.move(to: CGPoint(x: center.x - sqrt(radius*radius - offset*offset), y: center.y + offset))
                    latPath.addLine(to: CGPoint(x: center.x + sqrt(radius*radius - offset*offset), y: center.y + offset))
                    context.stroke(latPath, with: .color(Color.cyan.opacity(0.15)), lineWidth: 1)
                    
                    // Vertical longitude lines (arcs)
                    var lonPath = Path()
                    lonPath.addEllipse(in: CGRect(x: center.x - offset, y: center.y - radius * 1.2, width: offset * 2, height: radius * 2.4))
                    context.stroke(lonPath, with: .color(Color.cyan.opacity(0.15)), lineWidth: 1)
                }
                
                // Draw face nose bridge indicator
                var nosePath = Path()
                nosePath.move(to: CGPoint(x: center.x, y: center.y - radius * 0.3))
                nosePath.addLine(to: CGPoint(x: center.x, y: center.y + radius * 0.2))
                nosePath.addLine(to: CGPoint(x: center.x - radius * 0.1, y: center.y + radius * 0.2))
                context.stroke(nosePath, with: .color(Color.cyan.opacity(0.7)), lineWidth: 2)
                
                // Draw eyes indicators
                let eyeOffset = radius * 0.35
                let eyeY = center.y - radius * 0.25
                var leftEye = Path()
                leftEye.addEllipse(in: CGRect(x: center.x - eyeOffset - 6, y: eyeY - 4, width: 12, height: 8))
                context.stroke(leftEye, with: .color(Color.cyan.opacity(0.7)), lineWidth: 1.5)
                
                var rightEye = Path()
                rightEye.addEllipse(in: CGRect(x: center.x + eyeOffset - 6, y: eyeY - 4, width: 12, height: 8))
                context.stroke(rightEye, with: .color(Color.cyan.opacity(0.7)), lineWidth: 1.5)
            }
            .stroke(Color.cyan, lineWidth: 1)
            .shadow(color: .cyan.opacity(0.5), radius: 6)
            // Apply 3D perspective to simulate physical head orientation
            .rotation3DEffect(.radians(-faceData.yaw), axis: (x: 0.0, y: 1.0, z: 0.0))
            .rotation3DEffect(.radians(faceData.pitch), axis: (x: 1.0, y: 0.0, z: 0.0))
            .rotation3DEffect(.radians(-faceData.roll), axis: (x: 0.0, y: 0.0, z: 1.0))
        }
        .frame(width: 200, height: 200)
    }
}
