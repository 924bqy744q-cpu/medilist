import XCTest
@testable import MedListCore

/// MedList is an organizer, not medical advice. App-generated text must describe, never instruct.
final class WordingSafetyTests: XCTestCase {
    /// Whole-word (or phrase) patterns that read as instructions. English and Dutch.
    static let banned = [
        "stop", "stopping", "stopped", "take", "taking", "should", "dose should be", "must",
        "stoppen", "stop met", "neem", "nemen", "innemen", "inneemt", "moet", "moeten", "dosis moet",
    ]

    static func violations(in text: String) -> [String] {
        let lower = text.lowercased()
        return banned.filter { word in
            lower.range(of: #"(?<![\p{L}])"# + NSRegularExpression.escapedPattern(for: word) + #"(?![\p{L}])"#,
                        options: .regularExpression) != nil
        }
    }

    func testBannedWordMatcherWorks() {
        XCTAssertEqual(Self.violations(in: "Please stop this"), ["stop"])
        XCTAssertEqual(Self.violations(in: "Stopwatch, retake"), [], "whole words only")
        XCTAssertEqual(Set(Self.violations(in: "U moet dit innemen")), ["moet", "innemen"])
    }

    func testAllFlagCopyIsDescriptive() async {
        let ascal = MedicationSnapshot(name: "Ascal", ingredients: ["aspirin"])
        let meds = [
            MedicationSnapshot(name: "Warfarin"), ascal,
            MedicationSnapshot(name: "Aspirin 80 mg"), MedicationSnapshot(name: "Aspirine"),
        ]
        let result = await FlagEngine(interactions: SampleInteractionProvider.bundled()).evaluate(meds)
        XCTAssertEqual(Set(result.flags.map(\.kind)), [.duplicateIngredient, .interaction])

        for language in ["en", "nl"] {
            let copy = FlagCopy(language: language)
            var texts = copy.allStaticStrings
            for flag in result.flags {
                texts += [copy.title(for: flag), copy.body(for: flag), copy.fullText(for: flag), copy.source(for: flag) ?? ""]
                XCTAssertTrue(copy.fullText(for: flag).hasSuffix(copy.verifyWithPharmacist), "every flag ends with the pharmacist line")
            }
            for text in texts {
                XCTAssertEqual(Self.violations(in: text), [], "[\(language)] \(text)")
            }
        }
        XCTAssertEqual(FlagCopy(language: "en").verifyWithPharmacist, "Verify with your pharmacist.")
    }

    func testSampleInteractionDescriptionsAreDescriptive() {
        for record in SampleInteractionProvider.bundled().records {
            for (language, text) in record.descriptions {
                XCTAssertEqual(Self.violations(in: text), [], "[\(language)] \(text)")
            }
        }
    }

    /// Scans the app's String Catalog (every key and every translation) for the same words.
    func testAppStringCatalogIsDescriptive() throws {
        let catalog = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("MedList/Resources/Localizable.xcstrings")
        guard FileManager.default.fileExists(atPath: catalog.path) else {
            throw XCTSkip("String Catalog not present at \(catalog.path)")
        }
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: Any])
        XCTAssertFalse(strings.isEmpty)

        for (key, entry) in strings {
            var texts = [key]
            let localizations = (entry as? [String: Any])?["localizations"] as? [String: Any] ?? [:]
            for (_, loc) in localizations {
                if let value = ((loc as? [String: Any])?["stringUnit"] as? [String: Any])?["value"] as? String {
                    texts.append(value)
                }
            }
            for text in texts {
                XCTAssertEqual(Self.violations(in: text), [], text)
            }
            XCTAssertNotNil(localizations["nl"], "missing Dutch translation for: \(key)")
        }
    }
}
