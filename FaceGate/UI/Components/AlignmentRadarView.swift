import SwiftUI

/// An interactive sphere-radar view matching the Android Photo Sphere concept.
/// Displays target dots for all 7 face angles and a user indicator dot that moves
/// in real-time as the user rotates their head (using yaw for horizontal, pitch for vertical).
struct AlignmentRadarView: View {
    let currentStep: FaceEnrollmentManager.EnrollmentStep
    let completedSteps: Set<FaceEnrollmentManager.EnrollmentStep>
    let yaw: Float
    let pitch: Float
    let isTargetPoseAligned: Bool

    // Grid properties.
    private let radarSize: CGFloat = 160
    private let targetDotRadius: CGFloat = 10
    private let indicatorDotRadius: CGFloat = 11

    // Coordinate mapping helper.
    private func position(for step: FaceEnrollmentManager.EnrollmentStep) -> CGPoint {
        let center = radarSize / 2
        
        switch step {
        case .straight:
            return CGPoint(x: center, y: center)
        case .leftSlight:
            return CGPoint(x: center - 26, y: center)
        case .leftFar:
            return CGPoint(x: center - 52, y: center)
        case .rightSlight:
            return CGPoint(x: center + 26, y: center)
        case .rightFar:
            return CGPoint(x: center + 52, y: center)
        case .up:
            return CGPoint(x: center, y: center - 20)
        case .down:
            return CGPoint(x: center, y: center + 20)
        }
    }

    var body: some View {
        ZStack {
            // Radar Background Circle
            Circle()
                .fill(Color.black.opacity(0.6))
                .frame(width: radarSize, height: radarSize)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                )

            // Outer dashed boundary ring
            Circle()
                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 4]))
                .frame(width: radarSize - 16, height: radarSize - 16)

            // Faint Crosshair Lines
            Path { path in
                let center = radarSize / 2
                // Horizontal line
                path.move(to: CGPoint(x: 12, y: center))
                path.addLine(to: CGPoint(x: radarSize - 12, y: center))
                // Vertical line
                path.move(to: CGPoint(x: center, y: 12))
                path.addLine(to: CGPoint(x: center, y: radarSize - 12))
            }
            .stroke(Color.white.opacity(0.08), lineWidth: 1)

            // 1. Draw Target Dots for each step
            ForEach(FaceEnrollmentManager.EnrollmentStep.allCases, id: \.self) { step in
                let pos = position(for: step)
                let isCompleted = completedSteps.contains(step)
                let isActive = currentStep == step

                ZStack {
                    if isCompleted {
                        // Completed state: Green filled dot with checkmark
                        Circle()
                            .fill(Color.green)
                            .frame(width: targetDotRadius * 2, height: targetDotRadius * 2)
                            .shadow(color: Color.green.opacity(0.4), radius: 3)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    } else if isActive {
                        // Active target: pulsing target ring
                        Circle()
                            .strokeBorder(Color.blue, lineWidth: 2)
                            .background(Circle().fill(Color.blue.opacity(0.2)))
                            .frame(width: targetDotRadius * 2.2, height: targetDotRadius * 2.2)
                            .overlay(
                                Circle()
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    .scaleEffect(isTargetPoseAligned ? 1.0 : 1.3)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isTargetPoseAligned)
                            )
                    } else {
                        // Uncaptured standard target: simple faint ring
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                            .frame(width: targetDotRadius * 1.6, height: targetDotRadius * 1.6)
                    }
                }
                .position(pos)
            }

            // 2. Draw User Indicator Dot (derived from yaw/pitch)
            let indicatorPos: CGPoint = {
                let center = radarSize / 2
                // Cap the inputs to prevent the dot from flying out of the radar box bounds
                let cappedYaw = max(-1.0, min(1.0, yaw))
                let cappedPitch = max(-0.6, min(0.6, pitch))
                
                // Map yaw and pitch to X/Y offset coordinates
                // Yaw maps directly to X (left/right). Pitch maps directly to Y (up/down).
                let dx = CGFloat(cappedYaw) * 65
                let dy = CGFloat(cappedPitch) * 65
                return CGPoint(x: center + dx, y: center + dy)
            }()

            ZStack {
                // Outer glow
                Circle()
                    .fill(isTargetPoseAligned ? Color.green.opacity(0.35) : Color.orange.opacity(0.3))
                    .frame(width: indicatorDotRadius * 2.6, height: indicatorDotRadius * 2.6)
                
                // Inner solid dot
                Circle()
                    .fill(isTargetPoseAligned ? Color.green : Color.orange)
                    .frame(width: indicatorDotRadius * 1.5, height: indicatorDotRadius * 1.5)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1.2)
                    )
                    .shadow(color: (isTargetPoseAligned ? Color.green : Color.orange).opacity(0.5), radius: 4)
            }
            .position(indicatorPos)
            .animation(.interactiveSpring(response: 0.25, dampingFraction: 0.75, blendDuration: 0), value: indicatorPos)
        }
        .frame(width: radarSize, height: radarSize)
    }
}
