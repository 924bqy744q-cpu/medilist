import XCTest
@testable import MedListCore

final class EvalScoringTests: XCTestCase {
    func testNormalizationIsLenientOnFormattingOnly() {
        XCTAssertEqual(EvalScoring.outcome(expected: "20 mg", predicted: "20MG"), .correct)
        XCTAssertEqual(EvalScoring.outcome(expected: "Dr. P. de Boer", predicted: "dr p de boer"), .correct)
        XCTAssertEqual(EvalScoring.outcome(expected: "250 mg / 5 ml", predicted: "250 mg/5ml"), .correct)
        XCTAssertEqual(EvalScoring.outcome(expected: "20 mg", predicted: "40 mg"), .wrong)
        XCTAssertEqual(EvalScoring.outcome(expected: nil, predicted: ""), .correct)
        XCTAssertEqual(EvalScoring.outcome(expected: "x", predicted: nil), .missed)
        XCTAssertEqual(EvalScoring.outcome(expected: nil, predicted: "cholesterol"), .hallucinated)
    }

    func testScoringPairsByNameAndTracksHighlighting() {
        let expected: [[String: String?]] = [
            ["drug_name": "Lisinopril", "strength": "10 mg", "purpose": nil],
            ["drug_name": "Metformin", "strength": "500 mg"],
        ]
        let predicted = [
            ExtractedMedication(drugName: .init(value: "Metformine", confidence: 0.9), strength: .init(value: "500 mg", confidence: 0.9)),
            ExtractedMedication(drugName: .init(value: "Lisinopril", confidence: 0.9), strength: .init(value: "20 mg", confidence: 0.4),
                                purpose: .init(value: "blood pressure", confidence: 0.95)),
            ExtractedMedication(drugName: .init(value: "Zzzz", confidence: 0.3)),
        ]
        var report = EvalScoring.Report()
        EvalScoring.score(expected: expected, predicted: predicted, into: &report)

        XCTAssertEqual(report.matchedMedications, 2)
        XCTAssertEqual(report.spuriousMedications, 1)
        let strength = report.fields[.strength]!
        XCTAssertEqual(strength.counts[.correct], 1)
        XCTAssertEqual(strength.counts[.wrong], 1)
        XCTAssertEqual(strength.errorCatchRate, 1, "the wrong strength had low confidence")
        let purpose = report.fields[.purpose]!
        XCTAssertEqual(purpose.counts[.hallucinated], 1)
        XCTAssertEqual(purpose.errorCatchRate, 0, "a confident hallucination is not caught")
        XCTAssertEqual(report.fields[.drugName]!.counts[.wrong], 1, "Metformine vs Metformin is paired but scored wrong")
    }

    func testReportEncodesFieldsAsObject() throws {
        var report = EvalScoring.Report()
        EvalScoring.score(expected: [["drug_name": "A"]], predicted: [], into: &report)
        let json = String(decoding: try JSONEncoder().encode(report), as: UTF8.self)
        XCTAssertTrue(json.contains(#""drug_name":{"#), json)
    }
}
