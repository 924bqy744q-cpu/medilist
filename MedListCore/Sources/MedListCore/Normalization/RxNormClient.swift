import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum IngredientSource: String, Codable, Sendable {
    case localAlias
    case rxNormExact
    case rxNormApproximate
    /// Not found anywhere; the drug's own name is used as its ingredient key.
    case unresolved
}

public struct IngredientResolution: Codable, Equatable, Sendable {
    public var ingredients: [String]
    public var source: IngredientSource
    public var rxcui: String?

    public init(ingredients: [String], source: IngredientSource, rxcui: String? = nil) {
        self.ingredients = ingredients
        self.source = source
        self.rxcui = rxcui
    }
}

public protocol RxNormLookup: Sendable {
    /// Returns ingredient names for a drug name, or nil if RxNorm does not know it.
    func resolveIngredients(for name: String) async throws -> IngredientResolution?
}

/// Client for the free NLM RxNorm REST API (https://lhncbc.nlm.nih.gov/RxNav/APIs/RxNormAPIs.html).
/// Only the drug name is sent: no patient data.
public struct RxNormClient: RxNormLookup {
    public static let defaultBaseURL = URL(string: "https://rxnav.nlm.nih.gov/REST")!

    let baseURL: URL
    let transport: HTTPTransport

    public init(baseURL: URL = RxNormClient.defaultBaseURL, transport: HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public func resolveIngredients(for name: String) async throws -> IngredientResolution? {
        let query = IngredientKey.queryName(from: name)
        guard !query.isEmpty else { return nil }

        var source = IngredientSource.rxNormExact
        var rxcui = try await exactRxcui(for: query)
        if rxcui == nil {
            rxcui = try await approximateRxcui(for: query)
            source = .rxNormApproximate
        }
        guard let rxcui else { return nil }

        var ingredients = try await relatedIngredients(of: rxcui)
        if ingredients.isEmpty, let props = try await properties(of: rxcui), ["IN", "PIN"].contains(props.tty ?? "") {
            ingredients = [props.name ?? query]
        }
        guard !ingredients.isEmpty else { return nil }
        let keys = Array(Set(ingredients.map(IngredientKey.ingredient))).sorted()
        return IngredientResolution(ingredients: keys, source: source, rxcui: rxcui)
    }

    // MARK: - Endpoints

    struct IDGroupResponse: Decodable {
        struct IDGroup: Decodable { let rxnormId: [String]? }
        let idGroup: IDGroup?
    }

    struct ApproximateResponse: Decodable {
        struct Group: Decodable { let candidate: [Candidate]? }
        struct Candidate: Decodable { let rxcui: String?; let score: String? }
        let approximateGroup: Group?
    }

    struct RelatedResponse: Decodable {
        struct Group: Decodable { let conceptGroup: [ConceptGroup]? }
        struct ConceptGroup: Decodable { let tty: String?; let conceptProperties: [Concept]? }
        struct Concept: Decodable { let rxcui: String?; let name: String?; let tty: String? }
        let relatedGroup: Group?
    }

    struct PropertiesResponse: Decodable {
        struct Properties: Decodable { let rxcui: String?; let name: String?; let tty: String? }
        let properties: Properties?
    }

    func exactRxcui(for name: String) async throws -> String? {
        let response: IDGroupResponse = try await get("rxcui.json", query: [("name", name), ("search", "2")])
        return response.idGroup?.rxnormId?.first
    }

    func approximateRxcui(for name: String) async throws -> String? {
        let response: ApproximateResponse = try await get(
            "approximateTerm.json", query: [("term", name), ("maxEntries", "1"), ("option", "1")])
        return response.approximateGroup?.candidate?.first?.rxcui
    }

    func relatedIngredients(of rxcui: String) async throws -> [String] {
        let response: RelatedResponse = try await get("rxcui/\(rxcui)/related.json", query: [("tty", "IN")])
        return (response.relatedGroup?.conceptGroup ?? [])
            .filter { $0.tty == "IN" }
            .flatMap { $0.conceptProperties ?? [] }
            .compactMap(\.name)
    }

    func properties(of rxcui: String) async throws -> PropertiesResponse.Properties? {
        let response: PropertiesResponse = try await get("rxcui/\(rxcui)/properties.json", query: [])
        return response.properties
    }

    private func get<T: Decodable>(_ path: String, query: [(String, String)]) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) } }
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 15
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else { throw ExtractionError.server(status: response.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
