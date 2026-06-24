import AppKit
import AVFoundation
import CoreGraphics
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

    /// All available video cameras.
    @Published private(set) var availableCameras: [AVCaptureDevice] = []

    /// Callback invoked on each captured video frame.
    var onFrameCaptured: ((CVPixelBuffer) -> Void)?

    private let videoOutput = AVCaptureVideoDataOutput()
    private let processingQueue = DispatchQueue(label: "com.facegate.camera", qos: .userInitiated)

    /// Unique ID of the user's preferred camera, persisted across launches.
    var selectedCameraID: String? {
        get { UserDefaults.standard.string(forKey: "selectedCameraID") }
        set { UserDefaults.standard.set(newValue, forKey: "selectedCameraID") }
    }

    /// Brightness level captured just before the camera turns on, restored when it stops.
    private var savedBrightness: Float? = nil

    override init() {
        super.init()
    }

    // MARK: - Permission

    func checkPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            permissionGranted = true
            error = nil
        case .notDetermined:
            error = nil
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

    /// Returns the current camera authorization status without side effects.
    var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// Opens System Settings → Privacy & Security → Camera.
    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Camera Discovery

    /// Refreshes the list of available video cameras.
    func refreshAvailableCameras() {
        var cameras = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices

        // Sort: external first, then built-in.
        cameras.sort { $0.deviceType == .external && $1.deviceType != .external }
        availableCameras = cameras
    }

    /// Returns the camera that should be used, respecting the user's preference.
    private func resolveCamera() -> AVCaptureDevice? {
        refreshAvailableCameras()
        if let preferredID = selectedCameraID,
           let match = availableCameras.first(where: { $0.uniqueID == preferredID }) {
            return match
        }
        // Fall back to external, then built-in.
        return availableCameras.first(where: { $0.deviceType == .external })
            ?? availableCameras.first
    }

    // MARK: - Session Setup

    func configureSession() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        guard status == .authorized else {
            permissionGranted = false
            error = .permissionDenied
            return
        }
        permissionGranted = true

        captureSession.beginConfiguration()
        if captureSession.canSetSessionPreset(.hd1920x1080) {
            captureSession.sessionPreset = .hd1920x1080
        } else if captureSession.canSetSessionPreset(.high) {
            captureSession.sessionPreset = .high
        } else {
            captureSession.sessionPreset = .medium
        }

        guard let camera = resolveCamera() else {
            error = .cameraUnavailable
            captureSession.commitConfiguration()
            return
        }

        if camera.position == .front {
            enableVideoEffects()
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

        // Mirror the camera so it looks natural (like a mirror selfie).
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

        DispatchQueue.main.async { [weak self] in
            self?.saveBrightnessAndMaximize()
        }
        processingQueue.async { [weak self] in
            self?.captureSession.startRunning()
            DispatchQueue.main.async {
                self?.isRunning = true
            }
        }
    }

    func stopCapture() {
        guard captureSession.isRunning else { return }

        // Capture brightness value before the async block so it survives even if
        // `self` is deallocated before the block executes (the previous [weak self]
        // pattern silently dropped the restore when the object was released).
        let brightnessToRestore = savedBrightness
        savedBrightness = nil

        processingQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isRunning = false
                if let brightness = brightnessToRestore {
                    CameraManager.setBrightness(brightness)
                }
            }
        }
    }

    // MARK: - Video Effects

    private func enableVideoEffects() {
        if AVCaptureDevice.centerStageControlMode == .user {
            AVCaptureDevice.centerStageControlMode = .cooperative
        }
        AVCaptureDevice.isCenterStageEnabled = true
    }

    // MARK: - Brightness Management (via DisplayServices private framework)

    /// Typealias for DisplayServicesGetBrightness(displayID, &brightness) -> Int32
    private typealias DSGetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    /// Typealias for DisplayServicesSetBrightness(displayID, brightness) -> Int32
    private typealias DSSetBrightness = @convention(c) (UInt32, Float) -> Int32

    /// Saves the current display brightness and sets it to 1.0 (maximum).
    /// Uses the DisplayServices private framework which works on Apple Silicon.
    private func saveBrightnessAndMaximize() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) else { return }
        defer { dlclose(handle) }

        guard let getSym = dlsym(handle, "DisplayServicesGetBrightness"),
              let setSym = dlsym(handle, "DisplayServicesSetBrightness") else { return }

        let getBrightness = unsafeBitCast(getSym, to: DSGetBrightness.self)
        let setBrightness = unsafeBitCast(setSym, to: DSSetBrightness.self)

        let displayID = CGMainDisplayID()
        var current: Float = 0
        guard getBrightness(displayID, &current) == 0 else { return }

        savedBrightness = current
        _ = setBrightness(displayID, 1.0)
    }

    /// Restores the brightness that was saved in `saveBrightnessAndMaximize()`.
    private func restoreBrightness() {
        guard let saved = savedBrightness else { return }
        savedBrightness = nil
        CameraManager.setBrightness(saved)
    }

    /// Sets display brightness to the given value. Static so it can be called from
    /// contexts where the CameraManager instance may already be deallocated.
    fileprivate static func setBrightness(_ value: Float) {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) else { return }
        defer { dlclose(handle) }

        guard let setSym = dlsym(handle, "DisplayServicesSetBrightness") else { return }
        let setBrightness = unsafeBitCast(setSym, to: DSSetBrightness.self)

        _ = setBrightness(CGMainDisplayID(), value)
    }

    deinit {
        // Safety net: if the camera manager is deallocated without stopCapture() being
        // called (e.g. window closed mid-enrollment), restore the original brightness.
        if let saved = savedBrightness {
            let brightness = saved
            DispatchQueue.main.async {
                CameraManager.setBrightness(brightness)
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
                return "No camera was found on this Mac. Connect an external webcam."
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
