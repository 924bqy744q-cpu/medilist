import Foundation
import SwiftData
import MedListCore

/// Fictional data for UI tests, CI screenshots and the "Use sample label" button. Not real patients.
enum SampleData {
    /// What OCR typically returns for a US pharmacy label (fictional).
    static let scanText = """
    CITY PHARMACY
    RX# 4567890   DATE: 03/14/2026
    ATORVASTATIN CALCIUM 20 MG TABLET
    TAKE 1 TABLET BY MOUTH ONCE DAILY AT BEDTIME FOR CHOLESTEROL
    QTY: 30   REFILLS: 2
    DR. ROBERT SMITH
    """

    #if DEBUG
    @MainActor
    static func seed(into context: ModelContext) {
        guard (try? context.fetchCount(FetchDescriptor<CareRecipient>())) == 0 else { return }
        context.insert(CareRecipient(
            name: "Anna de Vries",
            dateOfBirth: Calendar.current.date(from: DateComponents(year: 1941, month: 3, day: 12)) ?? .now))

        let aliases = LocalAliasTable.bundled()
        func add(_ name: String, _ strength: String, _ form: String, _ dose: String, _ frequency: String, _ prescriber: String, _ purpose: String?) {
            var draft = MedicationDraft()
            draft.values = [.drugName: name, .strength: strength, .form: form, .dose: dose,
                            .frequency: frequency, .prescriber: prescriber, .purpose: purpose ?? ""]
            let ingredients = aliases.ingredients(for: name) ?? [IngredientKey.ingredient(name)]
            let source: IngredientSource = aliases.ingredients(for: name) == nil ? .rxNormExact : .localAlias
            context.insert(Medication(draft: draft, resolution: IngredientResolution(ingredients: ingredients, source: source)))
        }
        add("Lipitor", "20 mg", "tablet", "1 tablet", "once daily", "Dr. Jansen", "cholesterol")
        add("Metoprolol", "50 mg", "tablet", "1 tablet", "twice daily", "Dr. Jansen", "blood pressure")
        add("Warfarin", "5 mg", "tablet", "1 tablet", "once daily", "Dr. Bakker", nil)
        add("Ascal", "80 mg", "tablet", "1 tablet", "once daily", "Dr. Jansen", "heart")
        try? context.save()
    }
    #endif
}
