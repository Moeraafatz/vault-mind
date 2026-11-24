import Accelerate
import Foundation

/// Ultra-fast 128-dim L2-normalized semantic feature embedder accelerated by Apple `vDSP`.
/// Captures word unigrams, bigrams, and character trigrams so financial clauses, SKUs, code symbols,
/// and natural phrases match offline in sub-millisecond time without external models.
public enum VectorIndex {
    public static let dimensions = 128

    public static func embed(_ text: String) -> [Float] {
        var vec = [Float](repeating: 0, count: dimensions)
        let lower = text.lowercased()
        let tokens = lower.split { !$0.isLetter && !$0.isNumber && $0 != "_" && $0 != "$" }
        guard !tokens.isEmpty else { return vec }

        for tokenSub in tokens {
            let token = String(tokenSub)
            guard token.count >= 2 else { continue }
            addFeature(token, weight: 1.6, to: &vec)

            let chars = Array(token)
            if chars.count >= 4 {
                let maxTri = min(chars.count - 2, 10)
                for i in 0..<maxTri {
                    addFeature("#" + String(chars[i..<(i + 3)]), weight: 0.45, to: &vec)
                }
            }
        }

        if tokens.count >= 2 {
            let maxBi = min(tokens.count - 1, 48)
            for i in 0..<maxBi {
                addFeature("\(tokens[i])_\(tokens[i + 1])", weight: 1.1, to: &vec)
            }
        }

        normalizeInPlace(&vec)
        return vec
    }

    public static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        return max(0, min(1, dot))
    }

    public static func encode(_ vec: [Float]) -> Data {
        vec.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    public static func decode(_ data: Data) -> [Float] {
        let count = data.count / MemoryLayout<Float>.stride
        guard count == dimensions else { return [Float](repeating: 0, count: dimensions) }
        var out = [Float](repeating: 0, count: count)
        _ = out.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        return out
    }

    private static func addFeature(_ feature: String, weight: Float, to vec: inout [Float]) {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for b in feature.utf8 {
            hash ^= UInt64(b)
            hash &*= 1_099_511_628_211
        }
        let idx = Int(hash % UInt64(dimensions))
        let sign: Float = ((hash >> 63) == 0) ? 1.0 : -1.0
        vec[idx] += sign * weight
    }

    private static func normalizeInPlace(_ vec: inout [Float]) {
        var sumSq: Float = 0
        vDSP_svesq(vec, 1, &sumSq, vDSP_Length(vec.count))
        let norm = sqrt(sumSq)
        guard norm > 1e-6 else { return }
        var inv = 1.0 / norm
        vDSP_vsmul(vec, 1, &inv, &vec, 1, vDSP_Length(vec.count))
    }
}
