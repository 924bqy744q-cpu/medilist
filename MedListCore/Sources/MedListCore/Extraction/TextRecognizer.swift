#if canImport(Vision)
import CoreGraphics
import ImageIO
import Vision

/// On-device OCR with Vision. Images never leave the device; only the returned text is used afterwards.
public enum TextRecognizer {
    public static let defaultLanguages = ["nl-NL", "en-US"]

    public static func recognizeText(
        in image: CGImage,
        orientation: CGImagePropertyOrientation = .up,
        languages: [String] = defaultLanguages
    ) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            // Language correction "fixes" drug names into dictionary words, so it stays off.
            request.usesLanguageCorrection = false
            request.recognitionLanguages = languages

            let handler = VNImageRequestHandler(cgImage: image, orientation: orientation)
            try handler.perform([request])

            // Vision's origin is bottom-left: read top-to-bottom, then left-to-right within a row.
            let observations = (request.results ?? []).sorted { a, b in
                abs(a.boundingBox.midY - b.boundingBox.midY) > 0.012
                    ? a.boundingBox.midY > b.boundingBox.midY
                    : a.boundingBox.minX < b.boundingBox.minX
            }
            return observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        }.value
    }

    /// Convenience for files (used by the eval tool on macOS).
    public static func recognizeText(contentsOf url: URL, languages: [String] = defaultLanguages) async throws -> String {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ExtractionError.emptyInput
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let raw = (properties?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        return try await recognizeText(in: image, orientation: CGImagePropertyOrientation(rawValue: raw) ?? .up, languages: languages)
    }
}
#endif
