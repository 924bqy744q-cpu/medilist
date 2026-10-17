import XCTest
import PDFKit
import SwiftData
import MedListCore
@testable import MedList

@MainActor
final class MedListTests: XCTestCase {
    private func makeReport(medCount: Int, flagCount: Int = 0) -> ReportData {
        let meds = (0..<medCount).map {
            MedicationSnapshot(name: "Medication \($0) with a fairly long name", strength: "10 mg", form: "tablet",
                               dose: "1 tablet", frequency: "twice daily with meals", prescriber: "Dr. Jansen", purpose: "blood pressure")
        }
        let flags = (0..<flagCount).map { _ in
            MedicationFlag(kind: .duplicateIngredient, medicationIDs: [meds[0].id, meds[1].id],
                           medicationNames: [meds[0].name, meds[1].name], ingredients: ["x"], interaction: nil)
        }
        return ReportData(
            recipientName: "Anna de Vries", dateOfBirth: .now, generatedAt: .now, medications: meds, flags: flags,
            interactionCheckFailed: false, interactionSource: "Sample", copy: FlagCopy(language: "en"), locale: Locale(identifier: "en_US"))
    }

    func testPDFIsExactlyOneA4Page() throws {
        for (meds, flags) in [(3, 0), (12, 2), (60, 10)] {
            let url = try PDFExporter.render(makeReport(medCount: meds, flagCount: flags))
            defer { try? FileManager.default.removeItem(at: url) }
            let document = try XCTUnwrap(PDFDocument(url: url))
            XCTAssertEqual(document.pageCount, 1, "\(meds) meds")
            let bounds = try XCTUnwrap(document.page(at: 0)).bounds(for: .mediaBox)
            XCTAssertEqual(bounds.width, 595, accuracy: 1)
            XCTAssertEqual(bounds.height, 842, accuracy: 1)
            let text = document.string ?? ""
            XCTAssertTrue(text.contains("Anna de Vries"))
            XCTAssertTrue(text.contains("Medication 0"))
            if flags > 0 { XCTAssertTrue(text.contains("Verify with your pharmacist")) }
        }
    }

    func testExportFileIsProtectedAndRemovable() throws {
        let url = try PDFExporter.render(makeReport(medCount: 2))
        #if !targetEnvironment(simulator)
        // The simulator does not implement Data Protection, so this is only checkable on a device.
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .complete)
        #endif
        PDFExporter.removeTemporaryExports()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testScannedDraftHighlightsUncertainFieldsUntilEdited() {
        var draft = MedicationDraft(extracted: LabelTextParser().parse("Lisinopril 10 mg")[0])
        XCTAssertFalse(draft.needsAttention(.strength))
        XCTAssertTrue(draft.needsAttention(.prescriber), "missing value")
        draft.set(.prescriber, "Dr. Jansen")
        XCTAssertFalse(draft.needsAttention(.prescriber), "user typed it")
        XCTAssertFalse(MedicationDraft().needsAttention(.prescriber), "manual entry is never highlighted")
    }

    func testDraftNeedsAName() {
        var draft = MedicationDraft()
        XCTAssertFalse(draft.isSavable)
        draft.set(.drugName, "   ")
        XCTAssertFalse(draft.isSavable)
        draft.set(.drugName, "Metformin")
        XCTAssertTrue(draft.isSavable)
    }

    func testDeleteAllDataRemovesEverything() throws {
        let container = DataStore.makeContainer(inMemory: true)
        let context = container.mainContext
        context.insert(CareRecipient(name: "Anna", dateOfBirth: .now))
        var draft = MedicationDraft()
        draft.set(.drugName, "Metformin")
        context.insert(Medication(draft: draft, resolution: IngredientResolution(ingredients: ["metformin"], source: .unresolved)))
        try context.save()

        try DataStore.deleteAllData(context: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<CareRecipient>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Medication>()), 0)
    }

    func testSnapshotMapping() {
        var draft = MedicationDraft()
        draft.set(.drugName, "Lipitor")
        draft.set(.strength, "20 mg")
        let med = Medication(draft: draft, resolution: IngredientResolution(ingredients: ["atorvastatin"], source: .localAlias))
        XCTAssertEqual(med.snapshot.ingredients, ["atorvastatin"])
        XCTAssertEqual(med.snapshot.ingredientSource, .localAlias)
        XCTAssertEqual(med.snapshot.strength, "20 mg")
        XCTAssertNil(med.snapshot.purpose)
    }
}
