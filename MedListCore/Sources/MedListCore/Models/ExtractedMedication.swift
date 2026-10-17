import Foundation

/// The fields MedList extracts from a label or discharge paper. Every field is optional.
public enum MedField: String, CaseIterable, Codable, Sendable {
    case drugName = "drug_name"
    case strength
    case form
    case dose
    case frequency
    case prescriber
    case purpose
}

/// One extracted value plus how sure the extractor is about it (0...1).
public struct ExtractedField: Codable, Equatable, Sendable {
    public var value: String?
    public var confidence: Double

    public init(value: String?, confidence: Double) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.value = (trimmed?.isEmpty ?? true) ? nil : trimmed
        self.confidence = self.value == nil ? 0 : min(max(confidence, 0), 1)
    }

    public static let empty = ExtractedField(value: nil, confidence: 0)

    enum CodingKeys: String, CodingKey { case value, confidence }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let value = try c.decodeIfPresent(String.self, forKey: .value)
        let confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        self.init(value: value, confidence: confidence)
    }
}

/// Decides when the Confirm screen highlights a field for attention.
public enum ConfidencePolicy {
    /// Below this, a field is highlighted as "please check".
    public static let lowThreshold = 0.7

    public static func needsAttention(_ field: ExtractedField) -> Bool {
        field.value == nil || field.confidence < lowThreshold
    }
}

/// A single medication as returned by an `ExtractionService`. Nothing here is saved until the user confirms.
public struct ExtractedMedication: Codable, Equatable, Sendable {
    public var drugName: ExtractedField
    public var strength: ExtractedField
    public var form: ExtractedField
    public var dose: ExtractedField
    public var frequency: ExtractedField
    public var prescriber: ExtractedField
    public var purpose: ExtractedField

    public init(
        drugName: ExtractedField = .empty,
        strength: ExtractedField = .empty,
        form: ExtractedField = .empty,
        dose: ExtractedField = .empty,
        frequency: ExtractedField = .empty,
        prescriber: ExtractedField = .empty,
        purpose: ExtractedField = .empty
    ) {
        self.drugName = drugName
        self.strength = strength
        self.form = form
        self.dose = dose
        self.frequency = frequency
        self.prescriber = prescriber
        self.purpose = purpose
    }

    enum CodingKeys: String, CodingKey {
        case drugName = "drug_name", strength, form, dose, frequency, prescriber, purpose
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func field(_ key: CodingKeys) throws -> ExtractedField {
            try c.decodeIfPresent(ExtractedField.self, forKey: key) ?? .empty
        }
        self.init(
            drugName: try field(.drugName), strength: try field(.strength), form: try field(.form),
            dose: try field(.dose), frequency: try field(.frequency),
            prescriber: try field(.prescriber), purpose: try field(.purpose)
        )
    }

    public subscript(field: MedField) -> ExtractedField {
        get {
            switch field {
            case .drugName: drugName
            case .strength: strength
            case .form: form
            case .dose: dose
            case .frequency: frequency
            case .prescriber: prescriber
            case .purpose: purpose
            }
        }
        set {
            switch field {
            case .drugName: drugName = newValue
            case .strength: strength = newValue
            case .form: form = newValue
            case .dose: dose = newValue
            case .frequency: frequency = newValue
            case .prescriber: prescriber = newValue
            case .purpose: purpose = newValue
            }
        }
    }

    /// True when the extractor found nothing usable at all.
    public var isEmpty: Bool { MedField.allCases.allSatisfy { self[$0].value == nil } }
}

/// The wire format returned by the extraction proxy (and produced by the mock).
public struct ExtractionResponse: Codable, Equatable, Sendable {
    public var medications: [ExtractedMedication]
    public init(medications: [ExtractedMedication]) { self.medications = medications }
}
