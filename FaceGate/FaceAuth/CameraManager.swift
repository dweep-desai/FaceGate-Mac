import AVFoundation
import Foundation

/// Manages the camera capture session for face authentication and enrollment.
/// Provides live video frames via a delegate callback for processing by the face detection pipeline.
final class CameraManager: NSObject, ObservableObject {
    /// The capture session — exposed so CameraPreviewView can attach a preview layer.
    let captureSession = AVCaptureSession()

    /// Published state for UI binding.
    @Published var isRunning: Bool = false
    @Published var permissionGranted: Bool = false
    @Published var error: CameraError?

    /// Callback invoked on each captured video frame.
    var onFrameCaptured: ((CVPixelBuffer) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.facegate.camera", qos: .userInitiated)

    override init() {
        super.init()
        checkPermission()
    }

    // MARK: - Permission

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.error = nil
                        self?.startCapture()
                    } else {
                        self?.error = .permissionDenied
                    }
                }
            }
        case .denied, .restricted:
            permissionGranted = false
            error = .permissionDenied
        @unknown default:
            permissionGranted = false
        }
    }

    // MARK: - Session Setup

    func configureSession() {
        guard permissionGranted else {
            error = .permissionDenied
            return
        }

        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.hd1920x1080) {
            captureSession.sessionPreset = .hd1920x1080
        } else if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        } else {
            captureSession.sessionPreset = .medium
        }

        // Input: front-facing camera.
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            error = .cameraUnavailable
            captureSession.commitConfiguration()
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            guard captureSession.canAddInput(input) else {
                error = .configurationFailed
                captureSession.commitConfiguration()
                return
            }
            captureSession.addInput(input)
        } catch {
            self.error = .configurationFailed
            captureSession.commitConfiguration()
            return
        }

        // Output: video frames.
        videoOutput.setSampleBufferDelegate(self, queue: processingQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        guard captureSession.canAddOutput(videoOutput) else {
            error = .configurationFailed
            captureSession.commitConfiguration()
            return
        }
        captureSession.addOutput(videoOutput)

        // Mirror the front camera so it looks natural.
        if let connection = videoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
        }

        captureSession.commitConfiguration()
    }

    // MARK: - Start / Stop

    func startCapture() {
        guard !captureSession.isRunning else { return }

        if captureSession.inputs.isEmpty {
            configureSession()
        }

        guard !captureSession.inputs.isEmpty else { return }

        processingQueue.async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = true
            }
        }
    }

    func stopCapture() {
        guard captureSession.isRunning else { return }

        processingQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }
    }

    // MARK: - Errors

    enum CameraError: LocalizedError {
        case permissionDenied
        case cameraUnavailable
        case configurationFailed

        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Camera access was denied. Please grant camera permission in System Settings."
            case .cameraUnavailable:
                return "No front-facing camera was found on this Mac."
            case .configurationFailed:
                return "Failed to configure the camera capture session."
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrameCaptured?(pixelBuffer)
    }
}
