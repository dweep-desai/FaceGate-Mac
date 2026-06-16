import Combine
import Foundation
import CoreVideo

/// The main face authentication orchestrator.
/// Ties together camera capture → face detection → embedding → matching
/// to perform real-time face unlock when the auth overlay is shown.
final class FaceAuthManager: ObservableObject {
    /// Current authentication state.
    @Published var state: FaceAuthState = .idle
    @Published var statusMessage: String = ""
    @Published var warningMessage: String = ""

    /// The camera manager — exposed for binding the preview layer.
    let cameraManager = CameraManager()

    private let faceDetector = FaceDetector()
    private let faceEmbedder = FaceEmbedder.shared
    private let faceMatcher: FaceMatcher
    private let dataStore = FaceDataStore.shared

    /// Enrolled embeddings loaded from disk.
    private var enrolledEmbeddings: [[Float]] = []

    /// Frame counter for performance — only run full pipeline every Nth frame.
    private var frameCount: Int = 0
    private let processEveryNFrames = 5

    /// Timeout tracking.
    private var authStartTime: Date?
    private let authTimeout: TimeInterval = 15  // seconds before showing fallback hint
    private var timeoutWorkItem: DispatchWorkItem?

    enum LivenessChallenge: CaseIterable {
        case turnLeft
        case turnRight
        case tiltHead

        var prompt: String {
            switch self {
            case .turnLeft: return "Liveness Check: Turn head left"
            case .turnRight: return "Liveness Check: Turn head right"
            case .tiltHead: return "Liveness Check: Tilt your head"
            }
        }
    }

    @Published var activeChallenge: LivenessChallenge? = nil

    /// Completion callback.
    private var onResult: ((Bool) -> Void)?

    enum FaceAuthState: Equatable {
        case idle
        case scanning
        case matched
        case noMatch
        case timeout
        case error(String)
    }

    init() {
        let threshold = UserDefaults.standard.float(forKey: FGConstants.faceUnlockThresholdKey)
        self.faceMatcher = FaceMatcher(
            threshold: threshold > 0 ? threshold : FGConstants.defaultFaceUnlockThreshold
        )
    }

    // MARK: - Public API

    /// Whether face unlock is enabled and enrolled.
    var isAvailable: Bool {
        UserDefaults.standard.bool(forKey: FGConstants.faceUnlockEnabledKey) &&
        UserDefaults.standard.bool(forKey: FGConstants.faceEnrolledKey) &&
        dataStore.hasEnrollment &&
        !isFaceUnlockTemporarilyDisabledByHours()
    }

    /// Checks if face unlock is temporarily disabled based on the current hour/minute settings.
    func isFaceUnlockTemporarilyDisabledByHours() -> Bool {
        guard UserDefaults.standard.bool(forKey: FGConstants.disableFaceUnlockHoursKey) else { return false }
        
        let calendar = Calendar.current
        let now = Date()
        let currentComponents = calendar.dateComponents([.hour, .minute], from: now)
        guard let currentHour = currentComponents.hour, let currentMinute = currentComponents.minute else { return false }
        
        let startHour = UserDefaults.standard.integer(forKey: FGConstants.faceUnlockDisabledStartHourKey)
        let startMinute = UserDefaults.standard.integer(forKey: FGConstants.faceUnlockDisabledStartMinuteKey)
        let endHour = UserDefaults.standard.integer(forKey: FGConstants.faceUnlockDisabledEndHourKey)
        let endMinute = UserDefaults.standard.integer(forKey: FGConstants.faceUnlockDisabledEndMinuteKey)
        
        let currentTotalMinutes = currentHour * 60 + currentMinute
        let startTotalMinutes = startHour * 60 + startMinute
        let endTotalMinutes = endHour * 60 + endMinute
        
        if startTotalMinutes <= endTotalMinutes {
            // Range does NOT cross midnight (e.g. 9:00 AM to 5:00 PM)
            return currentTotalMinutes >= startTotalMinutes && currentTotalMinutes < endTotalMinutes
        } else {
            // Range crosses midnight (e.g. 10:00 PM to 7:00 AM)
            return currentTotalMinutes >= startTotalMinutes || currentTotalMinutes < endTotalMinutes
        }
    }

    /// Begin face authentication. Activates the camera and starts scanning.
    /// - Parameter completion: Called with `true` if face matches, `false` otherwise.
    func startAuthentication(completion: @escaping (Bool) -> Void) {
        guard isAvailable else {
            completion(false)
            return
        }

        // Load enrolled embeddings.
        guard let enrollment = dataStore.load(), enrollment.isValid else {
            state = .error("No valid face enrollment found")
            completion(false)
            return
        }

        enrolledEmbeddings = enrollment.embeddings
        onResult = completion
        frameCount = 0
        authStartTime = Date()
        state = .scanning
        statusMessage = "Looking for your face…"
        warningMessage = ""
        activeChallenge = nil

        cameraManager.onFrameCaptured = { [weak self] pixelBuffer in
            self?.processAuthFrame(pixelBuffer)
        }

        cameraManager.startCapture()

        // Cancel any existing timeout before scheduling a new one.
        timeoutWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, self.state == .scanning else { return }
            self.state = .timeout
            self.statusMessage = "Face not recognized"
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + authTimeout, execute: workItem)
    }

    /// Stop face authentication and release the camera.
    func stopAuthentication() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        cameraManager.stopCapture()
        cameraManager.onFrameCaptured = nil
        state = .idle
        statusMessage = ""
        warningMessage = ""
        enrolledEmbeddings = []
        onResult = nil
    }

    /// Update the matching threshold from user settings.
    func updateThreshold(_ newThreshold: Float) {
        faceMatcher.setThreshold(newThreshold)
        UserDefaults.standard.set(newThreshold, forKey: FGConstants.faceUnlockThresholdKey)
    }

    // MARK: - Frame Processing

    private func processAuthFrame(_ pixelBuffer: CVPixelBuffer) {
        frameCount += 1

        // Only run the full pipeline every Nth frame for performance.
        guard frameCount % processEveryNFrames == 0 else { return }
        guard state == .scanning else { return }

        faceDetector.detectFaces(in: pixelBuffer) { [weak self] observations in
            guard let self = self else { return }

            // We need exactly one face for security.
            guard observations.count == 1, let face = observations.first else {
                DispatchQueue.main.async {
                    if observations.isEmpty {
                        self.statusMessage = "Looking for your face…"
                        self.warningMessage = ""
                    } else {
                        self.warningMessage = "Only one face allowed"
                    }
                }
                return
            }

            DispatchQueue.main.async {
                self.warningMessage = ""
            }

            // Crop the face.
            guard let croppedFace = self.faceDetector.cropFace(from: pixelBuffer, observation: face) else {
                return
            }

            // Generate embedding.
            guard let liveEmbedding = self.faceEmbedder.generateEmbedding(from: croppedFace) else {
                return
            }

            // Compare against enrolled embeddings.
            let result = self.faceMatcher.match(
                liveEmbedding: liveEmbedding,
                against: self.enrolledEmbeddings
            )

            guard result.isMatch else {
                DispatchQueue.main.async {
                    self.statusMessage = "Looking for your face…"
                }
                return
            }

            // Select a challenge if none has been chosen yet.
            if self.activeChallenge == nil {
                let challenge = LivenessChallenge.allCases.randomElement() ?? .turnLeft
                DispatchQueue.main.async {
                    self.activeChallenge = challenge
                    self.statusMessage = challenge.prompt
                }
                return
            }

            guard let challenge = self.activeChallenge else { return }

            let yaw = face.yaw.map { Float(truncating: $0) } ?? 0.0
            let roll = face.roll.map { Float(truncating: $0) } ?? 0.0

            var isChallengeSatisfied = false
            switch challenge {
            case .turnLeft:
                isChallengeSatisfied = yaw < -0.12
            case .turnRight:
                isChallengeSatisfied = yaw > 0.12
            case .tiltHead:
                isChallengeSatisfied = abs(roll) > 0.12
            }

            if isChallengeSatisfied {
                DispatchQueue.main.async {
                    self.timeoutWorkItem?.cancel()
                    self.timeoutWorkItem = nil
                    self.state = .matched
                    self.statusMessage = "Liveness verified!"
                    self.cameraManager.stopCapture()
                    self.cameraManager.onFrameCaptured = nil
                    self.onResult?(true)
                    self.onResult = nil
                }
            } else {
                DispatchQueue.main.async {
                    self.statusMessage = challenge.prompt
                }
            }
        }
    }
}
