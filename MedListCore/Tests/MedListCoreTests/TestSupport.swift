import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import MedListCore

/// Serves recorded RxNorm responses from `Fixtures/rxnorm` and records every request it receives.
final class FixtureTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { _requests } }
    let failAll: Bool

    init(failAll: Bool = false) { self.failAll = failAll }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { _requests.append(request) }
        if failAll { throw URLError(.notConnectedToInternet) }
        let url = request.url!
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func q(_ name: String) -> String { (items.first { $0.name == name }?.value ?? "").lowercased() }

        let file: String
        let parts = url.pathComponents
        switch parts.last {
        case "rxcui.json": file = "rxcui_\(q("name"))"
        case "approximateTerm.json": file = "approximate_\(q("term"))"
        case "related.json": file = "related_\(parts[parts.count - 2])"
        case "properties.json": file = "properties_\(parts[parts.count - 2])"
        default: file = "missing"
        }
        guard let fixture = Bundle.module.url(forResource: file, withExtension: "json", subdirectory: "Fixtures/rxnorm"),
              let data = try? Data(contentsOf: fixture) else {
            return (Data(), HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!)
        }
        return (data, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

/// Returns one canned response for the extraction proxy.
final class CannedTransport: HTTPTransport, @unchecked Sendable {
    let status: Int
    let body: String
    private(set) var lastRequest: URLRequest?

    init(status: Int = 200, body: String) {
        self.status = status
        self.body = body
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

struct FailingInteractions: InteractionProvider {
    let sourceName = "failing"
    func interactions(among ingredients: Set<String>) async throws -> [InteractionRecord] { throw URLError(.timedOut) }
}

enum Samples {
    static let usBottle = """
    CVS pharmacy #1234
    123 Main St (555) 123-4567
    RX# 4567890   DATE: 03/14/2026
    JANE DOE
    ATORVASTATIN CALCIUM 20 MG TABLET
    TAKE 1 TABLET BY MOUTH ONCE DAILY AT BEDTIME FOR CHOLESTEROL
    QTY: 30   REFILLS: 2
    DR. ROBERT SMITH
    """

    static let dutchBox = """
    Apotheek De Linde
    Tel 020-1234567
    Dhr. J. de Vries   geb. 12-03-1941
    Metoprolol succinaat 50 mg tablet met verlengde afgifte
    1 x per dag 1 tablet
    Voorschrijver: Dr. A. Jansen
    Voor hoge bloeddruk
    """

    static let discharge = """
    DISCHARGE MEDICATIONS
    1. Lisinopril 10 mg tablet - take 1 tablet by mouth once daily (blood pressure)
    2. Metformin 500 mg tablet, 1 tablet twice daily with meals
    3. Albuterol 90 mcg/actuation inhaler 2 puffs every 4-6 hours as needed for shortness of breath
    Attending physician: Maria Lopez, MD
    """

    static let liquid = """
    Amoxicillin 250 mg/5 ml oral suspension
    Take 5 ml three times daily for 10 days
    """
}
