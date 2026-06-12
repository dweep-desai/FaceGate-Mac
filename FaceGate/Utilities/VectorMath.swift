import Accelerate
import Foundation

/// High-performance vector math operations using the Accelerate framework (vDSP).
/// Used for cosine similarity and L2 distance comparisons between face embeddings.
enum VectorMath {
    /// Compute the cosine similarity between two vectors.
    /// Returns a value between -1.0 (opposite) and 1.0 (identical).
    /// - Parameters:
    ///   - a: First embedding vector.
    ///   - b: Second embedding vector.
    /// - Returns: Cosine similarity score.
    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return -1.0 }

        var dotProduct: Float = 0
        var magnitudeASquared: Float = 0
        var magnitudeBSquared: Float = 0

        // vDSP dot product: a · b
        vDSP_dotpr(a, 1, b, 1, &dotProduct, vDSP_Length(a.count))

        // vDSP sum of squares for magnitudes
        vDSP_svesq(a, 1, &magnitudeASquared, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &magnitudeBSquared, vDSP_Length(b.count))

        let magnitudeA = sqrt(magnitudeASquared)
        let magnitudeB = sqrt(magnitudeBSquared)

        guard magnitudeA > 0, magnitudeB > 0 else { return -1.0 }
        return dotProduct / (magnitudeA * magnitudeB)
    }

    /// Compute the L2 (Euclidean) distance between two vectors.
    /// Lower values indicate more similar vectors.
    /// - Parameters:
    ///   - a: First embedding vector.
    ///   - b: Second embedding vector.
    /// - Returns: Euclidean distance.
    static func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return Float.infinity }

        // Compute difference vector: diff = a - b
        var diff = [Float](repeating: 0, count: a.count)
        vDSP_vsub(b, 1, a, 1, &diff, 1, vDSP_Length(a.count))

        // Sum of squares of the differences
        var sumOfSquares: Float = 0
        vDSP_svesq(diff, 1, &sumOfSquares, vDSP_Length(diff.count))

        return sqrt(sumOfSquares)
    }

    /// Normalize a vector to unit length (L2 normalization).
    /// - Parameter vector: The vector to normalize.
    /// - Returns: The normalized vector, or the original if magnitude is zero.
    static func normalize(_ vector: [Float]) -> [Float] {
        var magnitudeSquared: Float = 0
        vDSP_svesq(vector, 1, &magnitudeSquared, vDSP_Length(vector.count))

        let magnitude = sqrt(magnitudeSquared)
        guard magnitude > 0 else { return vector }

        var result = [Float](repeating: 0, count: vector.count)
        var divisor = magnitude
        vDSP_vsdiv(vector, 1, &divisor, &result, 1, vDSP_Length(vector.count))
        return result
    }
}
