import Foundation

/// Canonical spelling for ingredient and drug names so that "Atorvastatin Calcium", "ATORVASTATINE" and
/// "atorvastatin" compare equal.
public enum IngredientKey {
    /// Salt and release-form words that do not change the active ingredient. Only stripped when trailing.
    static let trailingQualifiers: Set<String> = [
        "calcium", "sodium", "potassium", "magnesium", "hydrochloride", "hcl", "hydrobromide", "succinate",
        "tartrate", "besylate", "besilate", "maleate", "mesylate", "mesilate", "fumarate", "citrate",
        "sulfate", "natrium", "sulphate", "phosphate", "acetate", "bromide", "dihydrate", "monohydrate", "trihydrate",
        // Dutch spellings
        "succinaat", "tartraat", "kalium", "besilaat", "maleaat", "fumaraat", "citraat", "sulfaat", "fosfaat",
        "acetaat", "mesilaat", "waterstofchloride",
        "er", "xr", "sr", "xl", "la", "cr", "dr", "retard", "zoc", "mga", "ec",
    ]

    /// Dutch/European spellings that map to the RxNorm (US) ingredient name. Applied after lowercasing.
    static let spellingVariants: [String: String] = [
        "paracetamol": "acetaminophen",
        "acetylsalicylzuur": "aspirin",
        "acetylsalicylic acid": "aspirin",
        "salbutamol": "albuterol",
        "levothyroxine natrium": "levothyroxine",
        "metamizol": "metamizole",
        "colecalciferol": "cholecalciferol",
        "glibenclamide": "glyburide",
        // Carbasalate calcium (e.g. Ascal) releases acetylsalicylic acid, so it should match aspirin for duplicate checks.
        "carbasalate": "aspirin",
        "carbasalaatcalcium": "aspirin",
    ]

    /// Lowercase, strip diacritics, collapse whitespace.
    public static func basic(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// The name to send to a lookup: drug name without strength, form or list markers.
    public static func queryName(from drugName: String) -> String {
        var name = basic(drugName)
        if let strength = LabelTextParser.strengthPattern.firstMatch(in: name) {
            name = String(name[..<strength.range.lowerBound])
        }
        let formWords: Set<String> = ["tablet", "tablets", "tab", "tabs", "capsule", "capsules", "cap", "caps",
                                      "tabletten", "filmomhulde", "omhulde", "oral", "solution", "drank"]
        let words = name.split(separator: " ").map(String.init).filter { !formWords.contains($0) }
        return words.joined(separator: " ").trimmingCharacters(in: CharacterSet(charactersIn: " -,.;:"))
    }

    /// Ingredient key: query name, spelling variants unified, trailing salts/release forms removed.
    public static func ingredient(_ name: String) -> String {
        var key = queryName(from: name)
        if let variant = spellingVariants[key] { return variant }
        var words = key.split(separator: " ").map(String.init)
        while words.count > 1, let last = words.last, trailingQualifiers.contains(last) {
            words.removeLast()
        }
        key = words.joined(separator: " ")
        // Dutch INN spellings often add a trailing "e" (atorvastatine, metoprolol stays): fold that one case.
        if key.hasSuffix("statine") { key.removeLast() }
        return spellingVariants[key] ?? key
    }
}
