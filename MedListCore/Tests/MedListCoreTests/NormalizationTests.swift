import XCTest
@testable import MedListCore

final class IngredientKeyTests: XCTestCase {
    func testCanonicalKeys() {
        XCTAssertEqual(IngredientKey.ingredient("ATORVASTATIN CALCIUM 20 MG TABLET"), "atorvastatin")
        XCTAssertEqual(IngredientKey.ingredient("Atorvastatine 40 mg"), "atorvastatin")
        XCTAssertEqual(IngredientKey.ingredient("Metoprolol succinaat"), "metoprolol")
        XCTAssertEqual(IngredientKey.ingredient("metoprolol tartrate"), "metoprolol")
        XCTAssertEqual(IngredientKey.ingredient("Paracetamol 500 mg"), "acetaminophen")
        XCTAssertEqual(IngredientKey.ingredient("Carbasalaatcalcium"), "aspirin")
        XCTAssertEqual(IngredientKey.ingredient("Calcium"), "calcium", "a lone salt word is the ingredient")
        XCTAssertEqual(IngredientKey.ingredient("calcium carbonate"), "calcium carbonate", "only trailing qualifiers are stripped")
    }

    func testQueryNameStripsStrengthAndForm() {
        XCTAssertEqual(IngredientKey.queryName(from: "Lipitor 20 mg tablets"), "lipitor")
        XCTAssertEqual(IngredientKey.queryName(from: "Selokeen ZOC 50mg"), "selokeen zoc")
    }
}

final class IngredientNormalizerTests: XCTestCase {
    func testLocalAliasWinsAndSkipsNetwork() async {
        let transport = FixtureTransport()
        let normalizer = IngredientNormalizer(aliases: .bundled(), rxNorm: RxNormClient(transport: transport))
        let result = await normalizer.resolve("Selokeen ZOC 50 mg")
        XCTAssertEqual(result, IngredientResolution(ingredients: ["metoprolol"], source: .localAlias))
        XCTAssertTrue(transport.requests.isEmpty, "no network call for a local hit")
    }

    func testBrandResolvesViaRxNorm() async {
        let normalizer = IngredientNormalizer(aliases: LocalAliasTable(aliases: [:]), rxNorm: RxNormClient(transport: FixtureTransport()))
        let result = await normalizer.resolve("Lipitor 20 mg")
        XCTAssertEqual(result, IngredientResolution(ingredients: ["atorvastatin"], source: .rxNormExact, rxcui: "153165"))
    }

    func testIngredientConceptResolvesToItself() async {
        let normalizer = IngredientNormalizer(aliases: LocalAliasTable(aliases: [:]), rxNorm: RxNormClient(transport: FixtureTransport()))
        let result = await normalizer.resolve("atorvastatin")
        XCTAssertEqual(result.ingredients, ["atorvastatin"])
        XCTAssertEqual(result.source, .rxNormExact)
    }

    func testMisspellingUsesApproximateMatchAndCombinationIngredients() async {
        let normalizer = IngredientNormalizer(aliases: LocalAliasTable(aliases: [:]), rxNorm: RxNormClient(transport: FixtureTransport()))
        let result = await normalizer.resolve("Zestoretik")
        XCTAssertEqual(result.ingredients, ["hydrochlorothiazide", "lisinopril"])
        XCTAssertEqual(result.source, .rxNormApproximate)
    }

    func testUnknownNameFallsBackToItsOwnKey() async {
        let normalizer = IngredientNormalizer(aliases: LocalAliasTable(aliases: [:]), rxNorm: RxNormClient(transport: FixtureTransport()))
        let result = await normalizer.resolve("Qwertyx 5 mg")
        XCTAssertEqual(result, IngredientResolution(ingredients: ["qwertyx"], source: .unresolved))
    }

    func testNetworkFailureIsNotCached() async {
        let offline = FixtureTransport(failAll: true)
        let normalizer = IngredientNormalizer(aliases: LocalAliasTable(aliases: [:]), rxNorm: RxNormClient(transport: offline))
        _ = await normalizer.resolve("Lipitor")
        _ = await normalizer.resolve("Lipitor")
        XCTAssertEqual(offline.requests.count, 2, "a failed lookup is retried next time")
    }

    func testRxNormRequestContainsOnlyTheDrugName() async {
        let transport = FixtureTransport()
        _ = try? await RxNormClient(transport: transport).resolveIngredients(for: "Lipitor 20 mg tablet")
        let first = transport.requests.first?.url?.absoluteString ?? ""
        XCTAssertTrue(first.hasPrefix("https://rxnav.nlm.nih.gov/REST/rxcui.json?"))
        XCTAssertTrue(first.contains("name=lipitor"))
    }
}
