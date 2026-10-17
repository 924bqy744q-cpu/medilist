import Foundation

/// Every user-facing sentence about flags, in one reviewable place (English and Dutch).
///
/// Rules (enforced by `WordingSafetyTests`): describe, never instruct. No "stop", "take", "should",
/// "dose should be" or their Dutch equivalents. Every flag ends with the pharmacist line.
/// Legal/medical wording review is a pilot blocker (TODO.md).
public struct FlagCopy: Sendable {
    public let language: String

    public init(language: String) {
        self.language = language.hasPrefix("nl") ? "nl" : "en"
    }

    private var nl: Bool { language == "nl" }

    public var verifyWithPharmacist: String {
        nl ? "Controleer dit met uw apotheker." : "Verify with your pharmacist."
    }

    public var flagsSectionTitle: String { nl ? "Aandachtspunten" : "Flags" }

    public func title(for flag: MedicationFlag) -> String {
        switch flag.kind {
        case .duplicateIngredient: nl ? "Zelfde werkzame stof" : "Same active ingredient"
        case .interaction: nl ? "Mogelijke wisselwerking" : "Possible interaction"
        }
    }

    public func body(for flag: MedicationFlag) -> String {
        let names = list(flag.medicationNames)
        switch flag.kind {
        case .duplicateIngredient:
            let ingredients = list(flag.ingredients)
            let pair = flag.medicationNames.count == 2
            return nl
                ? "\(names) bevatten \(pair ? "allebei" : "allemaal") \(ingredients)."
                : "\(names) \(pair ? "both" : "all") contain \(ingredients)."
        case .interaction:
            let detail = flag.interaction?.description(language: language) ?? ""
            let lead = nl
                ? "\(names) staan samen in de wisselwerkingsgegevens."
                : "\(names) appear together in the interaction data."
            return detail.isEmpty ? lead : "\(lead) \(detail)"
        }
    }

    public func source(for flag: MedicationFlag) -> String? {
        guard let source = flag.interaction?.source else { return nil }
        return nl ? "Bron: \(source)" : "Source: \(source)"
    }

    /// Full text for one flag, as used in VoiceOver labels and the PDF.
    public func fullText(for flag: MedicationFlag) -> String {
        [title(for: flag) + ":", body(for: flag), verifyWithPharmacist].joined(separator: " ")
    }

    public var noFlagsIsNotAClearance: String {
        nl
            ? "Geen melding betekent niet dat er geen probleem is. MedList controleert alleen een beperkte set gegevens."
            : "No flag does not mean there is no problem. MedList only checks a limited set of data."
    }

    public var interactionCheckUnavailable: String {
        nl
            ? "De controle op wisselwerkingen was niet beschikbaar. Controleer de lijst met uw apotheker."
            : "The interaction check was unavailable. Verify the list with your pharmacist."
    }

    public var unresolvedName: String {
        nl
            ? "Deze naam is niet herkend als bekende werkzame stof, dus de controles zijn hiervoor beperkt."
            : "This name was not matched to a known active ingredient, so checks for it are limited."
    }

    public var disclaimer: String {
        nl
            ? "MedList ordent informatie die u zelf invoert. Het geeft geen medisch advies. Bespreek vragen of wijzigingen altijd met de arts of apotheker."
            : "MedList organizes information you enter. It does not give medical advice. Discuss any questions or changes with the doctor or pharmacist."
    }

    /// All static sentences, for wording tests.
    public var allStaticStrings: [String] {
        [verifyWithPharmacist, flagsSectionTitle, noFlagsIsNotAClearance, interactionCheckUnavailable, unresolvedName, disclaimer]
    }

    func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        default:
            let and = nl ? "en" : "and"
            return items.dropLast().joined(separator: ", ") + " \(and) " + items.last!
        }
    }
}
