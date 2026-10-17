import Foundation

/// Turns OCR text into structured medication candidates.
///
/// Implementations only ever receive text, never images. Callers should pass the text through
/// `OCRRedactor` first so identifiers that extraction does not need are removed.
public protocol ExtractionService: Sendable {
    func extract(from ocrText: String, languageCode: String) async throws -> [ExtractedMedication]
}

public enum ExtractionError: Error, Equatable, Sendable {
    case emptyInput
    case server(status: Int)
    case invalidResponse
    case transport
}

/// On-device extractor backed by `LabelTextParser`. Used as the default and as the offline fallback.
public struct MockExtractionService: ExtractionService {
    public init() {}

    public func extract(from ocrText: String, languageCode: String) async throws -> [ExtractedMedication] {
        guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExtractionError.emptyInput
        }
        return LabelTextParser().parse(ocrText)
    }
}
