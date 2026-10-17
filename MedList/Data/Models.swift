import Foundation
import SwiftData
import MedListCore

/// The one person whose medications are tracked (v1 supports exactly one).
@Model
final class CareRecipient {
    var name: String
    var dateOfBirth: Date
    var consentGivenAt: Date
    /// Bumped when the consent text changes, so the app can ask again.
    var consentVersion: Int

    init(name: String, dateOfBirth: Date, consentGivenAt: Date = .now, consentVersion: Int = CareRecipient.currentConsentVersion) {
        self.name = name
        self.dateOfBirth = dateOfBirth
        self.consentGivenAt = consentGivenAt
        self.consentVersion = consentVersion
    }

    static let currentConsentVersion = 1
}

/// A confirmed medication on the master list. Only confirmed values are stored: no photos, no OCR text.
@Model
final class Medication {
    @Attribute(.unique) var id: UUID
    var name: String
    var strength: String?
    var form: String?
    var dose: String?
    var frequency: String?
    var prescriber: String?
    var purpose: String?
    var ingredients: [String]
    var ingredientSourceRaw: String
    var addedViaScan: Bool
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), draft: MedicationDraft, resolution: IngredientResolution) {
        self.id = id
        self.name = draft.value(.drugName) ?? ""
        self.ingredients = resolution.ingredients
        self.ingredientSourceRaw = resolution.source.rawValue
        self.addedViaScan = draft.isFromScan
        self.createdAt = .now
        self.updatedAt = .now
        apply(draft)
    }

    func apply(_ draft: MedicationDraft) {
        name = draft.value(.drugName) ?? name
        strength = draft.value(.strength)
        form = draft.value(.form)
        dose = draft.value(.dose)
        frequency = draft.value(.frequency)
        prescriber = draft.value(.prescriber)
        purpose = draft.value(.purpose)
        updatedAt = .now
    }

    var ingredientSource: IngredientSource { IngredientSource(rawValue: ingredientSourceRaw) ?? .unresolved }

    var snapshot: MedicationSnapshot {
        MedicationSnapshot(
            id: id, name: name, strength: strength, form: form, dose: dose, frequency: frequency,
            prescriber: prescriber, purpose: purpose, ingredients: ingredients, ingredientSource: ingredientSource)
    }

    subscript(field: MedField) -> String? {
        switch field {
        case .drugName: name
        case .strength: strength
        case .form: form
        case .dose: dose
        case .frequency: frequency
        case .prescriber: prescriber
        case .purpose: purpose
        }
    }
}
