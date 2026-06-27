import CoreImage
import Foundation
import Vision

/// Detects faces in video frames using Apple's Vision framework.
/// Provides bounding boxes, quality assessment, and face cropping for the embedding pipeline.
final class FaceDetector {
    /// Detect face rectangles in a pixel buffer.
    /// - Parameters:
    ///   - pixelBuffer: The video frame to analyze.
    ///   - completion: Returns an array of face observations found in the frame.
    func detectFaces(in pixelBuffer: CVPixelBuffer, completion: @escaping ([VNFaceObservation]) -> Void) {
        let request = VNDetectFaceRectanglesRequest { request, error in
            guard error == nil,
                  let results = request.results as? [VNFaceObservation] else {
                completion([])
                return
            }
            completion(results)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            completion([])
        }
    }

    /// Detect face landmarks in a pixel buffer.
    /// - Parameters:
    ///   - pixelBuffer: The video frame to analyze.
    ///   - completion: Returns an array of face observations with landmarks.
    func detectFaceLandmarks(in pixelBuffer: CVPixelBuffer, completion: @escaping ([VNFaceObservation]) -> Void) {
        let request = VNDetectFaceLandmarksRequest { request, error in
            guard error == nil,
                  let results = request.results as? [VNFaceObservation] else {
                completion([])
                return
            }
            completion(results)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            completion([])
        }
    }

    /// Detect faces with quality scores — used during enrollment to filter poor frames.
    /// - Parameters:
    ///   - pixelBuffer: The video frame to analyze.
    ///   - completion: Returns face observations paired with quality scores (0.0–1.0).
    func detectFacesWithQuality(in pixelBuffer: CVPixelBuffer, completion: @escaping ([(face: VNFaceObservation, quality: Float)]) -> Void) {
        let faceRequest = VNDetectFaceLandmarksRequest()
        let qualityRequest = VNDetectFaceCaptureQualityRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([faceRequest, qualityRequest])
        } catch {
            completion([])
            return
        }

        guard let faceResults = faceRequest.results else {
            completion([])
            return
        }

        // Quality results correspond to the same faces.
        let qualityResults = qualityRequest.results ?? []

        var combined: [(face: VNFaceObservation, quality: Float)] = []
        for (index, face) in faceResults.enumerated() {
            let quality: Float
            if index < qualityResults.count, let q = qualityResults[index].faceCaptureQuality {
                quality = Float(q)
            } else {
                quality = 0.5  // Default if quality unavailable
            }
            combined.append((face: face, quality: quality))
        }

        completion(combined)
    }

    /// Crop the detected face region from a pixel buffer, with padding for better embedding quality.
    /// - Parameters:
    ///   - pixelBuffer: The source video frame.
    ///   - observation: The face observation with the bounding box.
    ///   - padding: Fraction of face size to add as padding (default 20%).
    /// - Returns: A cropped CGImage of the face, or nil if cropping fails.
    func cropFace(from pixelBuffer: CVPixelBuffer, observation: VNFaceObservation, padding: CGFloat = 0.2) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let imageSize = ciImage.extent.size

        // Convert normalized Vision coordinates (0–1, origin at bottom-left) to pixel coordinates.
        let boundingBox = observation.boundingBox
        var faceRect = CGRect(
            x: boundingBox.origin.x * imageSize.width,
            y: boundingBox.origin.y * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )

        // Add padding around the face.
        let padX = faceRect.width * padding
        let padY = faceRect.height * padding
        faceRect = faceRect.insetBy(dx: -padX, dy: -padY)

        // Clamp to image bounds.
        faceRect = faceRect.intersection(ciImage.extent)
        guard !faceRect.isEmpty else { return nil }

        let croppedCI = ciImage.cropped(to: faceRect)
        let context = CIContext()
        return context.createCGImage(croppedCI, from: croppedCI.extent)
    }
}
