import Foundation

/// Value-type view of a confirmed medication, used by flag checks and the PDF report.
/// The app maps its SwiftData model into this so the logic stays testable without SwiftData.
public struct MedicationSnapshot: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var strength: String?
    public var form: String?
    public var dose: String?
    public var frequency: String?
    public var prescriber: String?
    public var purpose: String?
    public var ingredients: [String]
    public var ingredientSource: IngredientSource

    public init(
        id: UUID = UUID(), name: String, strength: String? = nil, form: String? = nil, dose: String? = nil,
        frequency: String? = nil, prescriber: String? = nil, purpose: String? = nil,
        ingredients: [String] = [], ingredientSource: IngredientSource = .unresolved
    ) {
        self.id = id
        self.name = name
        self.strength = strength
        self.form = form
        self.dose = dose
        self.frequency = frequency
        self.prescriber = prescriber
        self.purpose = purpose
        self.ingredients = ingredients.isEmpty ? [IngredientKey.ingredient(name)] : ingredients
        self.ingredientSource = ingredientSource
    }
}
