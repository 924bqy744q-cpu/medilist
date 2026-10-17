import Foundation

/// Offline brand → ingredient table bundled with the app (see `Resources/ingredient_aliases.json`).
public struct LocalAliasTable: Sendable {
    let aliases: [String: [String]]

    public init(aliases: [String: [String]]) {
        self.aliases = Dictionary(
            aliases.map { (IngredientKey.basic($0.key), $0.value.map(IngredientKey.ingredient)) },
            uniquingKeysWith: { first, _ in first })
    }

    public static func bundled() -> LocalAliasTable {
        struct File: Decodable { let aliases: [String: [String]] }
        guard let url = Bundle.module.url(forResource: "ingredient_aliases", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else {
            return LocalAliasTable(aliases: [:])
        }
        return LocalAliasTable(aliases: file.aliases)
    }

    public func ingredients(for drugName: String) -> [String]? {
        let query = IngredientKey.queryName(from: drugName)
        if let hit = aliases[query] { return hit }
        // "Selokeen ZOC" → try without trailing qualifiers too.
        let words = query.split(separator: " ")
        if words.count > 1, let hit = aliases[String(words[0])] { return hit }
        return nil
    }
}

/// Maps a drug name to its active ingredients: local table first (offline, covers NL brands), then RxNorm,
/// then falls back to the cleaned name itself so identical generics still match each other.
public actor IngredientNormalizer {
    let aliases: LocalAliasTable
    let rxNorm: RxNormLookup?
    private var cache: [String: IngredientResolution] = [:]

    public init(aliases: LocalAliasTable = .bundled(), rxNorm: RxNormLookup? = RxNormClient()) {
        self.aliases = aliases
        self.rxNorm = rxNorm
    }

    public func resolve(_ drugName: String) async -> IngredientResolution {
        let cacheKey = IngredientKey.queryName(from: drugName)
        if let cached = cache[cacheKey] { return cached }

        let resolution: IngredientResolution
        if let local = aliases.ingredients(for: drugName) {
            resolution = IngredientResolution(ingredients: local.sorted(), source: .localAlias)
        } else if let rxNorm, let remote = try? await rxNorm.resolveIngredients(for: drugName) {
            resolution = remote
        } else {
            // Network errors land here too; they are not cached so a later refresh can succeed.
            let fallback = IngredientResolution(ingredients: [IngredientKey.ingredient(drugName)], source: .unresolved)
            return fallback
        }
        cache[cacheKey] = resolution
        return resolution
    }
}
