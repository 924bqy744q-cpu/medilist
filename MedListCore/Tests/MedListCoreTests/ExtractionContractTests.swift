import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import MedListCore

final class ExtractionContractTests: XCTestCase {
    let endpoint = URL(string: "https://proxy.example/extract")!

    func testDecodesProxyResponseAndSanitisesFields() async throws {
        let body = """
        {"medications":[
          {"drug_name":{"value":"  Lipitor ","confidence":0.97},
           "strength":{"value":"20 mg","confidence":1.4},
           "form":{"value":"","confidence":0.9},
           "frequency":{"value":null,"confidence":0.8}},
          {"purpose":{"value":null,"confidence":0.1}}
        ]}
        """
        let transport = CannedTransport(body: body)
        let service = RemoteExtractionService(endpoint: endpoint, clientToken: "t", transport: transport)
        let meds = try await service.extract(from: "LIPITOR 20 MG", languageCode: "nl")

        XCTAssertEqual(meds.count, 1, "an all-empty medication is dropped")
        XCTAssertEqual(meds[0].drugName, ExtractedField(value: "Lipitor", confidence: 0.97))
        XCTAssertEqual(meds[0].strength.confidence, 1, "confidence is clamped to 0...1")
        XCTAssertNil(meds[0].form.value, "empty strings become nil")
        XCTAssertEqual(meds[0].form.confidence, 0)
        XCTAssertEqual(meds[0].frequency, .empty)
        XCTAssertEqual(meds[0].prescriber, .empty, "missing keys decode as empty")
    }

    func testRequestCarriesOnlyTextAndLanguage() async throws {
        let transport = CannedTransport(body: #"{"medications":[]}"#)
        let service = RemoteExtractionService(endpoint: endpoint, clientToken: "client-123", transport: transport)
        _ = try await service.extract(from: String(repeating: "a", count: 10_000), languageCode: "en")

        let request = try XCTUnwrap(transport.lastRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-MedList-Client"), "client-123")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"), "no API key in the app")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: String])
        XCTAssertEqual(Set(json.keys), ["text", "language"])
        XCTAssertEqual(json["text"]?.count, RemoteExtractionService.maxInputCharacters)
    }

    func testServerErrorAndGarbage() async {
        for (status, body, expected) in [
            (502, "{}", ExtractionError.server(status: 502)),
            (200, "<html>", ExtractionError.invalidResponse),
        ] {
            let service = RemoteExtractionService(endpoint: endpoint, transport: CannedTransport(status: status, body: body))
            do {
                _ = try await service.extract(from: "x", languageCode: "en")
                XCTFail("expected \(expected)")
            } catch {
                XCTAssertEqual(error as? ExtractionError, expected)
            }
        }
    }

    func testMockOutputRoundTripsThroughWireFormat() throws {
        let meds = LabelTextParser().parse(Samples.discharge)
        let data = try JSONEncoder().encode(ExtractionResponse(medications: meds))
        XCTAssertEqual(try JSONDecoder().decode(ExtractionResponse.self, from: data).medications, meds)
    }
}

final class OCRRedactorTests: XCTestCase {
    func testRemovesIdentifiersButKeepsMedicationText() {
        var dob = DateComponents()
        dob.year = 1941; dob.month = 3; dob.day = 12
        let date = Calendar(identifier: .gregorian).date(from: dob)!
        let redactor = OCRRedactor(recipientName: "Jan de Vries", dateOfBirth: date)

        let out = redactor.redact(Samples.dutchBox + "\nRX# 4567890\nBSN 123456782\nj.devries@example.nl\n1234 AB Amsterdam")

        XCTAssertFalse(out.contains("Vries"))
        XCTAssertFalse(out.contains("12-03-1941"))
        XCTAssertFalse(out.contains("1234567"), "phone number")
        XCTAssertFalse(out.contains("4567890"))
        XCTAssertFalse(out.contains("123456782"))
        XCTAssertFalse(out.contains("example.nl"))
        XCTAssertFalse(out.contains("1234 AB"))
        XCTAssertTrue(out.contains("Metoprolol succinaat 50 mg tablet"))
        XCTAssertTrue(out.contains("1 x per dag 1 tablet"))
        XCTAssertTrue(out.contains("Dr. A. Jansen"), "prescriber is needed for extraction")
    }

    func testDoesNotEatStrengths() {
        let text = "Paracetamol 1000 MG tablet\nCalcium 2500 IE\nRx: Lisinopril 10 mg"
        XCTAssertEqual(OCRRedactor(recipientName: nil, dateOfBirth: nil).redact(text), text)
    }

    func testShortNamePartsAreKept() {
        // "Li" must not remove "Lisinopril"; particles are not used as tokens.
        let out = OCRRedactor(recipientName: "Li van Dam", dateOfBirth: nil).redact("Lisinopril 10 mg\nvan Dam")
        XCTAssertTrue(out.contains("Lisinopril"))
        XCTAssertFalse(out.contains("Dam"))
    }
}
