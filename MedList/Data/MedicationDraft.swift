import Foundation
import SwiftUI
import MedListCore

/// Editable, unsaved medication. Lives only in memory until the user taps Save.
struct MedicationDraft: Identifiable, Equatable {
    let id = UUID()
    var values: [MedField: String] = [:]
    var confidence: [MedField: Double] = [:]
    var include = true
    /// Fields the user has typed in; they no longer need the "please check" highlight.
    var edited: Set<MedField> = []
    let isFromScan: Bool

    init(extracted: ExtractedMedication) {
        isFromScan = true
        for field in MedField.allCases {
            values[field] = extracted[field].value ?? ""
            confidence[field] = extracted[field].confidence
        }
    }

    init(medication: Medication? = nil) {
        isFromScan = false
        for field in MedField.allCases {
            values[field] = medication?[field] ?? ""
            confidence[field] = 1
        }
    }

    func value(_ field: MedField) -> String? {
        let trimmed = values[field]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Scanned fields the extractor was unsure about (or did not find) are highlighted on the Confirm screen.
    func needsAttention(_ field: MedField) -> Bool {
        guard isFromScan, !edited.contains(field) else { return false }
        return ConfidencePolicy.needsAttention(ExtractedField(value: value(field), confidence: confidence[field] ?? 0))
    }

    var isSavable: Bool { value(.drugName) != nil }

    mutating func set(_ field: MedField, _ text: String) {
        if values[field] != text { edited.insert(field) }
        values[field] = text
    }
}

extension MedField: Identifiable {
    public var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .drugName: "Medication name"
        case .strength: "Strength"
        case .form: "Form"
        case .dose: "Amount each time"
        case .frequency: "How often"
        case .prescriber: "Prescriber"
        case .purpose: "Purpose"
        }
    }

    var placeholder: LocalizedStringKey {
        switch self {
        case .drugName: "e.g. Metoprolol"
        case .strength: "e.g. 50 mg"
        case .form: "e.g. tablet"
        case .dose: "e.g. 1 tablet"
        case .frequency: "e.g. once daily"
        case .prescriber: "e.g. Dr. Jansen"
        case .purpose: "e.g. blood pressure"
        }
    }
}
