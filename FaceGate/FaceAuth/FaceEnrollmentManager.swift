import Combine
import Foundation
import CoreVideo
import Vision


/// Manages the face enrollment workflow: capturing multiple reference frames,
/// validating quality, generating embeddings, and storing them encrypted.
final class FaceEnrollmentManager: ObservableObject {
    /// Enrollment progress state.
    @Published var state: EnrollmentState = .idle
    @Published var capturedCount: Int = 0
    @Published var currentQuality: Float = 0
    @Published var statusMessage: String = "Position your face in the frame"
    @Published var warningMessage: String = ""
    @Published var visualizerData = FaceWireframeData()

    /// Target number of frames to capture.
    let targetFrameCount = FGConstants.enrollmentFrameCount

    private let cameraManager = CameraManager()
    private let faceDetector = FaceDetector()
    private let faceEmbedder = FaceEmbedder.shared
    private let dataStore = FaceDataStore.shared
    
    /// The name of the profile being enrolled.
    private var profileName: String = "Primary Face"

    /// Collected embeddings during enrollment.
    private var collectedEmbeddings: [[Float]] = []
    private var totalQuality: Float = 0
    private var framesSinceLastCapture: Int = 0

    /// Minimum frames to skip between captures (gives user time to shift expression).
    private let captureInterval = 15

    /// Camera manager for preview layer binding.
    var camera: CameraManager { cameraManager }

    enum EnrollmentStep: CaseIterable {
        case straight
        case left
        case right
        case tilt

        var prompt: String {
            switch self {
            case .straight: return "Look straight at the camera"
            case .left: return "Turn your head slightly to the LEFT"
            case .right: return "Turn your head slightly to the RIGHT"
            case .tilt: return "Tilt your head slightly to the side"
            }
        }
    }

    var currentStep: EnrollmentStep {
        let count = collectedEmbeddings.count
        if count < 2 {
            return .straight
        } else if count < 4 {
            return .left
        } else if count < 6 {
            return .right
        } else {
            return .tilt
        }
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
        collectedEmbeddings = []
        totalQuality = 0
        capturedCount = 0
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
        cameraManager.stopCapture()
        cameraManager.onFrameCaptured = nil
        collectedEmbeddings = []
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

            // Must detect exactly one face.
            guard results.count == 1 else {
                DispatchQueue.main.async {
                    if results.isEmpty {
                        self.warningMessage = "No face detected — look at the camera"
                    } else {
                        self.warningMessage = "Multiple faces detected — only one face allowed"
                    }
                }
                return
            }

            let (face, quality) = results[0]

            self.updateVisualizerData(from: face)

            DispatchQueue.main.async {
                self.currentQuality = quality
                self.warningMessage = ""
            }

            // Reject low-quality captures.
            guard quality >= FGConstants.minimumCaptureQuality else {
                DispatchQueue.main.async {
                    self.warningMessage = "Poor lighting or angle — adjust position"
                }
                return
            }

            // Read yaw and roll angles for liveness and multi-angle verification.
            let yaw = face.yaw.map { Float(truncating: $0) } ?? 0.0
            let roll = face.roll.map { Float(truncating: $0) } ?? 0.0

            let step = self.currentStep
            var isPositionValid = false

            switch step {
            case .straight:
                isPositionValid = abs(yaw) < 0.15 && abs(roll) < 0.12
            case .left:
                isPositionValid = yaw < -0.12
            case .right:
                isPositionValid = yaw > 0.12
            case .tilt:
                isPositionValid = abs(roll) > 0.12
            }

            if !isPositionValid {
                DispatchQueue.main.async {
                    self.statusMessage = step.prompt
                }
                return
            }

            // Crop the face and generate an embedding.
            guard let croppedFace = self.faceDetector.cropFace(from: pixelBuffer, observation: face),
                  let embedding = self.faceEmbedder.generateEmbedding(from: croppedFace) else {
                return
            }

            self.framesSinceLastCapture = 0
            self.collectedEmbeddings.append(embedding)
            self.totalQuality += quality

            DispatchQueue.main.async {
                self.capturedCount = self.collectedEmbeddings.count

                if self.capturedCount >= self.targetFrameCount {
                    self.finishEnrollment()
                } else {
                    let nextStep = self.currentStep
                    self.statusMessage = nextStep.prompt
                }
            }
        }
    }

    // MARK: - Finish Enrollment

    private func finishEnrollment() {
        state = .processing
        statusMessage = "Processing face data…"
        cameraManager.stopCapture()
        cameraManager.onFrameCaptured = nil

        let newProfile = FaceProfile(
            id: UUID(),
            name: profileName,
            enrolledDate: Date(),
            embeddings: collectedEmbeddings,
            averageQuality: totalQuality / Float(collectedEmbeddings.count)
        )

        do {
            try dataStore.addProfile(newProfile)

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
        
        let newProfile = FaceProfile(
            id: UUID(),
            name: name,
            enrolledDate: Date(),
            embeddings: mockEmbeddings,
            averageQuality: 0.95
        )
        
        try dataStore.addProfile(newProfile)
        
        // Update UserDefaults metadata
        UserDefaults.standard.set(true, forKey: FGConstants.faceEnrolledKey)
        UserDefaults.standard.set(true, forKey: FGConstants.faceUnlockEnabledKey)
    }
    #endif

    private func updateVisualizerData(from face: VNFaceObservation) {
        var data = FaceWireframeData()
        data.yaw = face.yaw.map { Double(truncating: $0) } ?? 0.0
        data.roll = face.roll.map { Double(truncating: $0) } ?? 0.0
        if #available(macOS 14.0, *) {
            data.pitch = face.pitch.map { Double(truncating: $0) } ?? 0.0
        }
        
        if let landmarks = face.landmarks {
            if let contour = landmarks.faceContour {
                data.outlinePoints = contour.normalizedPoints.map { CGPoint(x: $0.x, y: 1 - $0.y) }
            }
            if let nose = landmarks.nose {
                data.nosePoints = nose.normalizedPoints.map { CGPoint(x: $0.x, y: 1 - $0.y) }
            }
            if let leftEye = landmarks.leftEye {
                data.leftEyePoints = leftEye.normalizedPoints.map { CGPoint(x: $0.x, y: 1 - $0.y) }
            }
            if let rightEye = landmarks.rightEye {
                data.rightEyePoints = rightEye.normalizedPoints.map { CGPoint(x: $0.x, y: 1 - $0.y) }
            }
            if let outerLips = landmarks.outerLips {
                data.lipsPoints = outerLips.normalizedPoints.map { CGPoint(x: $0.x, y: 1 - $0.y) }
            }
        }
        
        DispatchQueue.main.async {
            self.visualizerData = data
        }
    }
}
