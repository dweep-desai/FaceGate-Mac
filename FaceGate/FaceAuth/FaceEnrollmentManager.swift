import Combine
import Foundation
import CoreVideo
import Vision
import AppKit


/// Manages the face enrollment workflow: capturing multiple reference frames,
/// validating quality, generating embeddings, and storing them encrypted.
final class FaceEnrollmentManager: ObservableObject {
    /// Enrollment progress state.
    @Published var state: EnrollmentState = .idle
    @Published var capturedCount: Int = 0
    @Published var currentQuality: Float = 0
    @Published var statusMessage: String = "Position your face in the frame"
    @Published var warningMessage: String = ""
    @Published var yaw: Double = 0.0
    @Published var pitch: Double = 0.0
    @Published var roll: Double = 0.0
    @Published var isTargetPoseAligned: Bool = false
    @Published var faceCenter = CGPoint(x: 0.5, y: 0.5)
    var isAddingFace: Bool = false

    /// Target number of frames to capture.
    let targetFrameCount = FGConstants.enrollmentFrameCount

    private let cameraManager = CameraManager()
    private let faceDetector = FaceDetector()
    private let faceEmbedder = FaceEmbedder.shared
    private let dataStore = FaceDataStore.shared
    
    /// The name of the profile being enrolled.
    private var profileName: String = "Primary Face"

    /// Collected embeddings during enrollment, keyed by their target angle bucket.
    private var completedBuckets: Set<EnrollmentStep> = []
    private var bucketEmbeddings: [EnrollmentStep: [Float]] = [:]
    private var totalQuality: Float = 0
    private var framesSinceLastCapture: Int = 0

    /// Count of consecutive frames where the face pose matched the target step.
    private var consecutiveFramesInPose: Int = 0
    private let requiredStableFrames: Int = 10 // ~0.7s of stability
    
    private var smoothedYaw: Double = 0.0
    private var smoothedPitch: Double = 0.0
    private var smoothedRoll: Double = 0.0
    
    /// Minimum frames to skip between captures.
    private let captureInterval = 5

    /// Camera manager for preview layer binding.
    var camera: CameraManager { cameraManager }

    enum EnrollmentStep: CaseIterable {
        case straight
        case leftSlight
        case leftFar
        case rightSlight
        case rightFar
        case up
        case down

        var prompt: String {
            switch self {
            case .straight: return "Look straight at the camera"
            case .leftSlight: return "Turn head slightly LEFT"
            case .leftFar: return "Turn head further LEFT"
            case .rightSlight: return "Turn head slightly RIGHT"
            case .rightFar: return "Turn head further RIGHT"
            case .up: return "Look UP slightly"
            case .down: return "Look DOWN slightly"
            }
        }

        var targetYaw: Float {
            switch self {
            case .straight: return 0.0
            case .leftSlight: return -0.35
            case .leftFar: return -0.75
            case .rightSlight: return 0.35
            case .rightFar: return 0.75
            case .up: return 0.0
            case .down: return 0.0
            }
        }

        var targetPitch: Float {
            switch self {
            case .straight, .leftSlight, .leftFar, .rightSlight, .rightFar: return 0.0
            case .up: return -0.18
            case .down: return 0.18
            }
        }
    }

    var currentStep: EnrollmentStep {
        for step in EnrollmentStep.allCases {
            if !completedBuckets.contains(step) {
                return step
            }
        }
        return .straight
    }

    var completedSteps: Set<EnrollmentStep> {
        completedBuckets
    }

    enum EnrollmentState: Equatable {
        case idle
        case capturing
        case processing
        case success
        case failed(String)
    }

    // MARK: - Enrollment Flow

    /// Start the enrollment process: activate camera and begin capturing face frames.
    /// - Parameter name: The name of the face profile being registered.
    func startEnrollment(name: String = "Primary Face") {
        guard state != .success else { return }
        self.profileName = name
        completedBuckets = []
        bucketEmbeddings = [:]
        totalQuality = 0
        capturedCount = 0
        consecutiveFramesInPose = 0
        isTargetPoseAligned = false
        framesSinceLastCapture = captureInterval  // Allow immediate first capture
        state = .capturing
        statusMessage = "Look straight at the camera"
        warningMessage = ""
 
        cameraManager.onFrameCaptured = { [weak self] pixelBuffer in
            self?.processEnrollmentFrame(pixelBuffer)
        }
 
        cameraManager.startCapture()
    }

    /// Cancel the enrollment process and clean up.
    func cancelEnrollment() {
        cameraManager.onFrameCaptured = nil
        cameraManager.stopCapture()
        completedBuckets = []
        bucketEmbeddings = [:]
        consecutiveFramesInPose = 0
        isTargetPoseAligned = false
        state = .idle
        capturedCount = 0
        statusMessage = "Enrollment cancelled"
        warningMessage = ""
    }

    /// Re-enroll: delete existing data and start fresh.
    func reEnroll() {
        try? dataStore.delete()
        startEnrollment(name: "Primary Face")
    }

    // MARK: - Frame Processing

    private func processEnrollmentFrame(_ pixelBuffer: CVPixelBuffer) {
        // Skip frames between captures to let user change expression.
        framesSinceLastCapture += 1
        guard framesSinceLastCapture >= captureInterval else { return }
        guard state == .capturing else { return }

        faceDetector.detectFacesWithQuality(in: pixelBuffer) { [weak self] results in
            guard let self = self else { return }
            guard self.state == .capturing else { return }

            // Must detect exactly one face.
            guard results.count == 1 else {
                DispatchQueue.main.async {
                    if results.isEmpty {
                        self.warningMessage = "No face detected — look at the camera"
                    } else {
                        self.warningMessage = "Multiple faces detected — only one face allowed"
                    }
                    self.isTargetPoseAligned = false
                    self.consecutiveFramesInPose = 0
                }
                return
            }

            let (face, quality) = results[0]

            self.updateAngles(from: face)

            // Track and smooth the face center bounding box coordinates
            let box = face.boundingBox
            let fX = box.origin.x + box.width / 2.0
            let fY = 1.0 - (box.origin.y + box.height / 2.0)
            
            let cur = self.faceCenter
            let smoothedX = cur.x + 0.22 * (fX - cur.x)
            let smoothedY = cur.y + 0.22 * (fY - cur.y)
            
            DispatchQueue.main.async {
                self.faceCenter = CGPoint(x: smoothedX, y: smoothedY)
            }

            // Validate quality.
            guard quality >= FGConstants.minimumCaptureQuality else {
                DispatchQueue.main.async {
                    self.warningMessage = "Poor lighting or quality — adjust position"
                    self.isTargetPoseAligned = false
                    self.consecutiveFramesInPose = 0
                }
                return
            }

            // Read smoothed yaw and pitch angles in radians
            let yaw = Float(self.yaw)
            let pitch = Float(self.pitch)

            let targetStep = self.currentStep
            let dy = yaw - targetStep.targetYaw
            let dp = pitch - targetStep.targetPitch
            let distance = sqrt(dy * dy + dp * dp)

            // Dynamic distance checking with relaxed tolerance circle (0.28) for comfortable alignment
            if distance <= 0.28 {
                self.consecutiveFramesInPose += 1
                
                DispatchQueue.main.async {
                    self.warningMessage = ""
                    self.isTargetPoseAligned = true
                    self.statusMessage = "\(targetStep.prompt)\n(Hold still...)"
                }

                if self.consecutiveFramesInPose >= self.requiredStableFrames {
                    self.consecutiveFramesInPose = 0
                    self.capturePose(pixelBuffer: pixelBuffer, face: face, quality: quality, step: targetStep)
                }
            } else {
                self.consecutiveFramesInPose = 0
                DispatchQueue.main.async {
                    self.isTargetPoseAligned = false
                    self.warningMessage = ""
                    self.statusMessage = targetStep.prompt
                }
            }
        }
    }

    /// Automatically triggers a capture of the current step's target angle.
    private func capturePose(pixelBuffer: CVPixelBuffer, face: VNFaceObservation, quality: Float, step: EnrollmentStep) {
        // Crop the face and generate embedding
        guard let croppedFace = self.faceDetector.cropFace(from: pixelBuffer, observation: face),
              let embedding = self.faceEmbedder.generateEmbedding(from: croppedFace) else {
            DispatchQueue.main.async {
                self.warningMessage = "Failed to extract face features. Try again."
            }
            return
        }

        // Play premium system sound on successful capture
        DispatchQueue.main.async {
            NSSound(named: "Glass")?.play()
        }

        self.bucketEmbeddings[step] = embedding
        self.completedBuckets.insert(step)
        self.totalQuality += quality
        self.framesSinceLastCapture = 0 // Reset skip frame counter

        DispatchQueue.main.async {
            self.capturedCount = self.completedBuckets.count
            self.warningMessage = ""
            self.isTargetPoseAligned = false

            if self.capturedCount >= self.targetFrameCount {
                self.finishEnrollment()
            } else {
                let nextStep = self.currentStep
                self.statusMessage = nextStep.prompt
            }
        }
    }



    // MARK: - Finish Enrollment

    private func finishEnrollment() {
        state = .processing
        statusMessage = "Processing face data…"
        cameraManager.onFrameCaptured = nil
        cameraManager.stopCapture()

        let collectedEmbeddings = EnrollmentStep.allCases.compactMap { bucketEmbeddings[$0] }
        let averageQuality = totalQuality / Float(collectedEmbeddings.count)

        let newFace = FaceEnrollment.EnrolledFace(
            id: UUID(),
            name: profileName,
            embeddings: collectedEmbeddings,
            enrolledDate: Date(),
            averageQuality: averageQuality
        )

        do {
            try dataStore.addProfile(newFace)

            // Enable face unlock by default after successful enrollment.
            UserDefaults.standard.set(true, forKey: FGConstants.faceUnlockEnabledKey)
            UserDefaults.standard.set(true, forKey: FGConstants.faceEnrolledKey)

            state = .success
            statusMessage = "Face enrolled successfully!"
        } catch {
            state = .failed("Failed to save: \(error.localizedDescription)")
            statusMessage = "Enrollment failed"
        }
    }

    #if DEBUG
    /// Simulates a mock face enrollment for local testing when a camera is not available.
    /// Generates randomized embeddings that are distinct from each other.
    func simulateMockEnrollment(name: String) throws {
        var mockEmbeddings: [[Float]] = []
        for _ in 0..<FGConstants.enrollmentFrameCount {
            var vector = [Float](repeating: 0, count: 512)
            for i in 0..<512 {
                vector[i] = Float.random(in: -1.0...1.0)
            }
            vector = VectorMath.normalize(vector)
            mockEmbeddings.append(vector)
        }
        let newProfile = FaceEnrollment.EnrolledFace(
            id: UUID(),
            name: name,
            embeddings: mockEmbeddings,
            enrolledDate: Date(),
            averageQuality: 0.85
        )
        
        try dataStore.addProfile(newProfile)
        UserDefaults.standard.set(true, forKey: FGConstants.faceUnlockEnabledKey)
        UserDefaults.standard.set(true, forKey: FGConstants.faceEnrolledKey)
        
        state = .success
        statusMessage = "Mock face enrolled successfully!"
    }
    #endif

    private func updateAngles(from face: VNFaceObservation) {
        var rawYaw = 0.0
        var rawPitch = 0.0
        var rawRoll = 0.0
        
        if let landmarks = face.landmarks {
            var rawOutline: [CGPoint] = []
            var rawNose: [CGPoint] = []
            var rawLeftEye: [CGPoint] = []
            var rawRightEye: [CGPoint] = []
            var rawLips: [CGPoint] = []
            
            if let contour = landmarks.faceContour {
                rawOutline = contour.normalizedPoints.map { CGPoint(x: $0.x, y: 1 - $0.y) }
            }
            if let nose = landmarks.nose {
                rawNose = nose.normalizedPoints.map { CGPoint(x: $0.x, y: 1 - $0.y) }
            }
            if let leftEye = landmarks.leftEye {
                rawLeftEye = leftEye.normalizedPoints.map { CGPoint(x: $0.x, y: 1 - $0.y) }
            }
            if let rightEye = landmarks.rightEye {
                rawRightEye = rightEye.normalizedPoints.map { CGPoint(x: $0.x, y: 1 - $0.y) }
            }
            if let outerLips = landmarks.outerLips {
                rawLips = outerLips.normalizedPoints.map { CGPoint(x: $0.x, y: 1 - $0.y) }
            }
            
            // Estimate smooth continuous yaw/pitch/roll from landmarks in radians
            let estimatedYaw = self.estimateYaw(leftEye: rawLeftEye, rightEye: rawRightEye, nose: rawNose)
            let estimatedPitch = self.estimatePitch(leftEye: rawLeftEye, rightEye: rawRightEye, nose: rawNose, lips: rawLips, outline: rawOutline)
            let estimatedRoll = self.estimateRoll(leftEye: rawLeftEye, rightEye: rawRightEye)
            
            let degreesToRadians = Double.pi / 180.0
            rawYaw = estimatedYaw ?? ((face.yaw.map { Double(truncating: $0) } ?? 0.0) * degreesToRadians)
            rawPitch = estimatedPitch ?? ((face.pitch.map { Double(truncating: $0) } ?? 0.0) * degreesToRadians)
            rawRoll = estimatedRoll ?? ((face.roll.map { Double(truncating: $0) } ?? 0.0) * degreesToRadians)
        } else {
            let degreesToRadians = Double.pi / 180.0
            rawYaw = (face.yaw.map { Double(truncating: $0) } ?? 0.0) * degreesToRadians
            rawPitch = (face.pitch.map { Double(truncating: $0) } ?? 0.0) * degreesToRadians
            rawRoll = (face.roll.map { Double(truncating: $0) } ?? 0.0) * degreesToRadians
        }
        
        // Smooth yaw, pitch, and roll using Exponential Moving Average (alpha = 0.22)
        // to prevent the orange user indicator dot from jerking or jumping around
        let alpha = 0.22
        self.smoothedYaw = self.smoothedYaw + alpha * (rawYaw - self.smoothedYaw)
        self.smoothedPitch = self.smoothedPitch + alpha * (rawPitch - self.smoothedPitch)
        self.smoothedRoll = self.smoothedRoll + alpha * (rawRoll - self.smoothedRoll)
        
        DispatchQueue.main.async {
            self.yaw = self.smoothedYaw
            self.pitch = self.smoothedPitch
            self.roll = self.smoothedRoll
        }
    }

    private func estimateYaw(leftEye: [CGPoint], rightEye: [CGPoint], nose: [CGPoint]) -> Double? {
        guard !leftEye.isEmpty, !rightEye.isEmpty, !nose.isEmpty else { return nil }
        
        let leftCenter = CGPoint(
            x: leftEye.map { $0.x }.reduce(0, +) / CGFloat(leftEye.count),
            y: leftEye.map { $0.y }.reduce(0, +) / CGFloat(leftEye.count)
        )
        
        let rightCenter = CGPoint(
            x: rightEye.map { $0.x }.reduce(0, +) / CGFloat(rightEye.count),
            y: rightEye.map { $0.y }.reduce(0, +) / CGFloat(rightEye.count)
        )
        
        let noseCenter = CGPoint(
            x: nose.map { $0.x }.reduce(0, +) / CGFloat(nose.count),
            y: nose.map { $0.y }.reduce(0, +) / CGFloat(nose.count)
        )
        
        let x1 = min(leftCenter.x, rightCenter.x)
        let x2 = max(leftCenter.x, rightCenter.x)
        let dx = x2 - x1
        guard dx > 0.01 else { return nil }
        
        let ratio = (noseCenter.x - x1) / dx
        let diff = ratio - 0.5
        
        let isLeftEyeOnRight = leftCenter.x > rightCenter.x
        let factor: Double = isLeftEyeOnRight ? -1.8 : 1.8
        
        let estimated = Double(diff) * factor
        return max(-0.6, min(0.6, estimated))
    }
    
    private func estimatePitch(leftEye: [CGPoint], rightEye: [CGPoint], nose: [CGPoint], lips: [CGPoint], outline: [CGPoint]) -> Double? {
        guard !leftEye.isEmpty, !rightEye.isEmpty, !nose.isEmpty else { return nil }
        
        let leftCenter = CGPoint(
            x: leftEye.map { $0.x }.reduce(0, +) / CGFloat(leftEye.count),
            y: leftEye.map { $0.y }.reduce(0, +) / CGFloat(leftEye.count)
        )
        
        let rightCenter = CGPoint(
            x: rightEye.map { $0.x }.reduce(0, +) / CGFloat(rightEye.count),
            y: rightEye.map { $0.y }.reduce(0, +) / CGFloat(rightEye.count)
        )
        
        let eyesY = (leftCenter.y + rightCenter.y) / 2.0
        
        let noseCenter = CGPoint(
            x: nose.map { $0.x }.reduce(0, +) / CGFloat(nose.count),
            y: nose.map { $0.y }.reduce(0, +) / CGFloat(nose.count)
        )
        
        let bottomY: CGFloat
        if !lips.isEmpty {
            bottomY = lips.map { $0.y }.reduce(0, +) / CGFloat(lips.count)
        } else if !outline.isEmpty {
            bottomY = outline[outline.count / 2].y
        } else {
            return nil
        }
        
        let totalDist = bottomY - eyesY
        guard totalDist > 0.01 else { return nil }
        
        let noseDist = noseCenter.y - eyesY
        let ratio = noseDist / totalDist
        
        let baseline = !lips.isEmpty ? 0.45 : 0.40
        let diff = ratio - baseline
        let factor = -1.5
        let estimated = Double(diff) * factor
        return max(-0.4, min(0.4, estimated))
    }
    
    private func estimateRoll(leftEye: [CGPoint], rightEye: [CGPoint]) -> Double? {
        guard !leftEye.isEmpty, !rightEye.isEmpty else { return nil }
        
        let leftCenter = CGPoint(
            x: leftEye.map { $0.x }.reduce(0, +) / CGFloat(leftEye.count),
            y: leftEye.map { $0.y }.reduce(0, +) / CGFloat(leftEye.count)
        )
        
        let rightCenter = CGPoint(
            x: rightEye.map { $0.x }.reduce(0, +) / CGFloat(rightEye.count),
            y: rightEye.map { $0.y }.reduce(0, +) / CGFloat(rightEye.count)
        )
        
        let dy = leftCenter.y - rightCenter.y
        let dx = leftCenter.x - rightCenter.x
        guard abs(dx) > 0.01 else { return nil }
        
        let angle = atan2(dy, dx)
        return max(-0.4, min(0.4, Double(angle)))
    }
}
