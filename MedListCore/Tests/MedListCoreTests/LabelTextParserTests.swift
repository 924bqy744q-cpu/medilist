import XCTest
@testable import MedListCore

final class LabelTextParserTests: XCTestCase {
    let parser = LabelTextParser()

    func testUSBottleLabel() throws {
        let meds = parser.parse(Samples.usBottle)
        XCTAssertEqual(meds.count, 1)
        let med = try XCTUnwrap(meds.first)
        XCTAssertEqual(med.drugName.value, "Atorvastatin Calcium")
        XCTAssertEqual(med.strength.value, "20 mg")
        XCTAssertEqual(med.form.value, "tablet")
        XCTAssertEqual(med.dose.value, "1 tablet")
        XCTAssertEqual(med.frequency.value, "once daily at bedtime")
        XCTAssertEqual(med.prescriber.value, "Dr. Robert Smith")
        XCTAssertEqual(med.purpose.value, "cholesterol")
    }

    func testDutchLabel() throws {
        let med = try XCTUnwrap(parser.parse(Samples.dutchBox).first)
        XCTAssertEqual(med.drugName.value, "Metoprolol succinaat")
        XCTAssertEqual(med.strength.value, "50 mg")
        XCTAssertEqual(med.form.value, "tablet")
        XCTAssertEqual(med.dose.value, "1 tablet")
        XCTAssertEqual(med.frequency.value, "1 x per dag")
        XCTAssertEqual(med.prescriber.value, "Dr. A. Jansen")
        XCTAssertEqual(med.purpose.value, "hoge bloeddruk")
    }

    func testDischargeListYieldsOneMedicationPerLine() {
        let meds = parser.parse(Samples.discharge)
        XCTAssertEqual(meds.map(\.drugName.value), ["Lisinopril", "Metformin", "Albuterol"])
        XCTAssertEqual(meds.map(\.strength.value), ["10 mg", "500 mg", "90 mcg"])
        XCTAssertEqual(meds.map(\.dose.value), ["1 tablet", "1 tablet", "2 puffs"])
        XCTAssertEqual(meds.map(\.frequency.value), ["once daily", "twice daily with meals", "every 4-6 hours as needed"])
        XCTAssertEqual(meds.map(\.purpose.value), ["blood pressure", nil, "shortness of breath"])
        XCTAssertEqual(meds[2].form.value, "inhaler")
        // Prescriber on the page applies to all, but with low confidence where it is not on the med's own block.
        XCTAssertEqual(meds.map(\.prescriber.value), Array(repeating: "Maria Lopez", count: 3))
        XCTAssertTrue(ConfidencePolicy.needsAttention(meds[0].prescriber))
        XCTAssertFalse(ConfidencePolicy.needsAttention(meds[2].prescriber))
    }

    func testLiquidStrengthIsNotMistakenForDose() throws {
        let med = try XCTUnwrap(parser.parse(Samples.liquid).first)
        XCTAssertEqual(med.strength.value, "250 mg/5ml")
        XCTAssertEqual(med.dose.value, "5 ml")
        XCTAssertEqual(med.form.value, "liquid")
        XCTAssertEqual(med.frequency.value, "three times daily")
        XCTAssertNil(med.purpose.value, "'for 10 days' is a duration, not a purpose")
    }

    func testTimingPhraseIsNotAPurpose() throws {
        let med = try XCTUnwrap(parser.parse("Temazepam 10 mg capsule\n1 capsule voor het slapen").first)
        XCTAssertEqual(med.frequency.value, "voor het slapen")
        XCTAssertNil(med.purpose.value)
    }

    func testWarningLineIsNotAPrescriber() throws {
        let med = try XCTUnwrap(parser.parse("Sertraline 50 mg tablet\nMAY CAUSE DROWSINESS. DO NOT DRINK ALCOHOL").first)
        XCTAssertNil(med.prescriber.value)
    }

    func testAbbreviatedFrequencyIsLowConfidence() throws {
        let med = try XCTUnwrap(parser.parse("Furosemide 40 mg tab\n1 tab PO BID").first)
        XCTAssertEqual(med.frequency.value, "bid")
        XCTAssertTrue(ConfidencePolicy.needsAttention(med.frequency))
    }

    func testNameOnLineAboveStrength() throws {
        let med = try XCTUnwrap(parser.parse("Pantozol\n40 mg maagsapresistente tablet").first)
        XCTAssertEqual(med.drugName.value, "Pantozol")
        XCTAssertTrue(ConfidencePolicy.needsAttention(med.drugName))
    }

    func testOCRDigitInNameIsLowConfidence() throws {
        let med = try XCTUnwrap(parser.parse("ALBUTER0L HFA 90 MCG/ACT INHALER\nINHALE 2 PUFFS EVERY 4 TO 6 HOURS").first)
        XCTAssertEqual(med.drugName.value, "Albuter0L Hfa")
        XCTAssertTrue(ConfidencePolicy.needsAttention(med.drugName))
        XCTAssertEqual(med.frequency.value, "every 4 to 6 hours")
    }

    func testDoseRange() throws {
        let med = try XCTUnwrap(parser.parse("Paracetamol 500 mg tablet\nzo nodig 1-2 tabletten").first)
        XCTAssertEqual(med.dose.value, "1-2 tabletten")
    }

    func testEmptyAndJunkInput() {
        XCTAssertTrue(parser.parse("").isEmpty)
        XCTAssertTrue(parser.parse("   \n \n").isEmpty)
        XCTAssertTrue(parser.parse("1234 5678").isEmpty)
    }

    func testEveryMissingFieldNeedsAttention() throws {
        let med = try XCTUnwrap(parser.parse("Lisinopril 10 mg").first)
        XCTAssertTrue(ConfidencePolicy.needsAttention(med.prescriber))
        XCTAssertTrue(ConfidencePolicy.needsAttention(med.purpose))
        XCTAssertFalse(ConfidencePolicy.needsAttention(med.strength))
    }

    func testMockServiceRejectsEmptyText() async {
        do {
            _ = try await MockExtractionService().extract(from: "  ", languageCode: "en")
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? ExtractionError, .emptyInput)
        }
    }
}
