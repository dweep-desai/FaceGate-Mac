import CoreGraphics
import CoreImage
import CoreML
import Foundation

/// Generates face embedding vectors from cropped face images.
/// Uses a Core ML model (MobileFaceNet/InsightFace w600k) to produce a 512-dimensional embedding.
/// Falls back to a software-based embedder during development when the ML model is not bundled.
final class FaceEmbedder {
    /// The dimension of the output embedding vector.
    /// MobileFaceNet (InsightFace w600k_mbf) outputs 512-dimensional embeddings.
    static let embeddingDimension = 512

    /// The expected input image size for the model.
    static let inputSize = CGSize(width: 112, height: 112)

    /// The loaded Core ML model, if available.
    private var mlModel: MLModel?

    /// Whether the real ML model is loaded and available.
    var isModelLoaded: Bool { mlModel != nil }

    /// Shared singleton.
    static let shared = FaceEmbedder()

    private init() {}

    // MARK: - Model Loading

    /// Attempt to load the Core ML model from the app bundle.
    /// Call this at app startup to pre-warm the model on the Neural Engine.
    func loadModel() {
        let config = MLModelConfiguration()
        // Prefer Apple Neural Engine; falls back to GPU/CPU automatically.
        config.computeUnits = .all

        // Try compiled model first (.mlmodelc — Xcode compiles .mlpackage at build time).
        if let modelURL = Bundle.main.url(forResource: "FaceEmbedding", withExtension: "mlmodelc") {
            do {
                mlModel = try MLModel(contentsOf: modelURL, configuration: config)
                print("[FaceEmbedder] Core ML model loaded from compiled .mlmodelc (ANE preferred).")
                return
            } catch {
                print("[FaceEmbedder] Failed to load compiled model: \(error)")
            }
        }

        // Fallback: try to compile .mlpackage at runtime (when bundled as a raw resource).
        if let packageURL = Bundle.main.url(forResource: "FaceEmbedding", withExtension: "mlpackage") {
            do {
                let compiledURL = try MLModel.compileModel(at: packageURL)
                mlModel = try MLModel(contentsOf: compiledURL, configuration: config)
                print("[FaceEmbedder] Core ML model compiled from .mlpackage and loaded (ANE preferred).")
                return
            } catch {
                print("[FaceEmbedder] Failed to compile/load .mlpackage: \(error)")
            }
        }

        print("[FaceEmbedder] No ML model found in bundle - using software-based fallback embedder.")
    }

    // MARK: - Embedding Generation

    /// Generate a face embedding vector from a cropped face image.
    /// - Parameter faceImage: A cropped CGImage of the detected face.
    /// - Returns: A 512-dimensional Float array representing the face, or nil on failure.
    func generateEmbedding(from faceImage: CGImage) -> [Float]? {
        if let model = mlModel {
            return generateWithModel(model, from: faceImage)
        } else {
            return generateFallbackEmbedding(from: faceImage)
        }
    }

    // MARK: - Real Model Inference

    private func generateWithModel(_ model: MLModel, from faceImage: CGImage) -> [Float]? {
        // Resize image to model's expected input size (112×112).
        guard let resized = resizeImage(faceImage, to: Self.inputSize) else { return nil }

        // Convert image to MLMultiArray tensor [1, 3, 112, 112].
        // MobileFaceNet expects RGB normalized to [-1, 1] (subtract 127.5, divide by 127.5).
        guard let inputArray = imageToMultiArray(resized) else { return nil }

        // Create the model input.
        guard let inputFeatureProvider = try? MLDictionaryFeatureProvider(dictionary: [
            "face_image": MLFeatureValue(multiArray: inputArray)
        ]) else { return nil }

        // Run inference.
        guard let prediction = try? model.prediction(from: inputFeatureProvider) else { return nil }

        // Extract embedding from the output.
        // Try "embedding" first, then fall back to the first output feature.
        let embeddingMultiArray: MLMultiArray?
        if let feat = prediction.featureValue(for: "embedding")?.multiArrayValue {
            embeddingMultiArray = feat
        } else {
            // Fallback: use the first available output.
            let outputName = model.modelDescription.outputDescriptionsByName.keys.first ?? "embedding"
            embeddingMultiArray = prediction.featureValue(for: outputName)?.multiArrayValue
        }

        guard let multiArray = embeddingMultiArray else { return nil }

        // Convert MLMultiArray to [Float].
        let count = multiArray.count
        var embedding = [Float](repeating: 0, count: count)
        for i in 0..<count {
            embedding[i] = Float(truncating: multiArray[i])
        }

        // L2 normalize the embedding for cosine similarity.
        return VectorMath.normalize(embedding)
    }

    /// Convert a CGImage to an MLMultiArray in NCHW format [1, 3, 112, 112].
    /// Normalizes pixel values from [0, 255] to [-1, 1] (InsightFace convention).
    private func imageToMultiArray(_ image: CGImage) -> MLMultiArray? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Create MLMultiArray with shape [1, 3, 112, 112].
        guard let array = try? MLMultiArray(shape: [1, 3, NSNumber(value: height), NSNumber(value: width)], dataType: .float32) else {
            return nil
        }

        // Fill in NCHW order, normalizing to [-1, 1].
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x * bytesPerPixel
                let r = (Float(pixelData[pixelIndex]) - 127.5) / 127.5
                let g = (Float(pixelData[pixelIndex + 1]) - 127.5) / 127.5
                let b = (Float(pixelData[pixelIndex + 2]) - 127.5) / 127.5

                let spatial = y * width + x
                array[spatial] = NSNumber(value: r)                          // Channel 0: R
                array[width * height + spatial] = NSNumber(value: g)         // Channel 1: G
                array[2 * width * height + spatial] = NSNumber(value: b)     // Channel 2: B
            }
        }

        return array
    }

    // MARK: - Fallback Embedder (used during development when ML model is not bundled)

    /// Generates a deterministic embedding from image pixel data as a development fallback.
    /// This allows the full app flow to be tested without the Core ML model.
    /// The fallback produces consistent embeddings by sampling pixel intensity values.
    private func generateFallbackEmbedding(from faceImage: CGImage) -> [Float]? {
        guard let resized = resizeImage(faceImage, to: Self.inputSize) else { return nil }

        // Sample pixel data to create a deterministic pseudo-embedding.
        let width = resized.width
        let height = resized.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(resized, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Sample pixels at regular intervals to build the embedding.
        var embedding = [Float](repeating: 0, count: Self.embeddingDimension)
        let totalPixels = width * height
        let step = max(1, totalPixels / Self.embeddingDimension)

        for i in 0..<Self.embeddingDimension {
            let pixelIndex = (i * step) % totalPixels
            let byteIndex = pixelIndex * bytesPerPixel
            let r = Float(pixelData[byteIndex]) / 255.0
            let g = Float(pixelData[byteIndex + 1]) / 255.0
            let b = Float(pixelData[byteIndex + 2]) / 255.0
            embedding[i] = (r + g + b) / 3.0
        }

        return VectorMath.normalize(embedding)
    }

    // MARK: - Image Utilities

    private func resizeImage(_ image: CGImage, to targetSize: CGSize) -> CGImage? {
        let context = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(origin: .zero, size: targetSize))
        return context?.makeImage()
    }
}
