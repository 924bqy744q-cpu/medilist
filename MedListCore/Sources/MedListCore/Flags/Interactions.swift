import Foundation

/// A known interaction between two ingredients, with a short neutral description per language.
public struct InteractionRecord: Codable, Equatable, Sendable {
    public let ingredientA: String
    public let ingredientB: String
    public let descriptions: [String: String]
    public let source: String

    public init(ingredientA: String, ingredientB: String, descriptions: [String: String], source: String) {
        self.ingredientA = IngredientKey.ingredient(ingredientA)
        self.ingredientB = IngredientKey.ingredient(ingredientB)
        self.descriptions = descriptions
        self.source = source
    }

    public func description(language: String) -> String? { descriptions[language] ?? descriptions["en"] }
}

/// Source of interaction knowledge.
///
/// TODO(licensed-data): the free RxNav interaction API was discontinued in January 2024. Before a pilot,
/// implement this protocol against a licensed source (e.g. G-Standaard/Z-Index for NL, or a commercial
/// API such as First Databank, Medi-Span, DrugBank) and swap it in at `AppEnvironment`. See TODO.md.
public protocol InteractionProvider: Sendable {
    /// Human-readable name shown next to every interaction flag.
    var sourceName: String { get }
    func interactions(among ingredients: Set<String>) async throws -> [InteractionRecord]
}

/// Tiny bundled dataset (`Resources/sample_interactions.json`). For development and demos only.
public struct SampleInteractionProvider: InteractionProvider {
    public let sourceName: String
    let records: [InteractionRecord]

    public init(records: [InteractionRecord], sourceName: String = "Sample data") {
        self.records = records
        self.sourceName = sourceName
    }

    public static func bundled() -> SampleInteractionProvider {
        struct File: Decodable {
            struct Pair: Decodable { let a: String; let b: String; let en: String; let nl: String }
            let source: String
            let pairs: [Pair]
        }
        guard let url = Bundle.module.url(forResource: "sample_interactions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            return SampleInteractionProvider(records: [])
        }
        let records = file.pairs.map {
            InteractionRecord(ingredientA: $0.a, ingredientB: $0.b, descriptions: ["en": $0.en, "nl": $0.nl], source: file.source)
        }
        return SampleInteractionProvider(records: records, sourceName: file.source)
    }

    public func interactions(among ingredients: Set<String>) async throws -> [InteractionRecord] {
        records.filter { ingredients.contains($0.ingredientA) && ingredients.contains($0.ingredientB) }
    }
}
