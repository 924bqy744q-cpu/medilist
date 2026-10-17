import XCTest
@testable import MedListCore

final class DuplicateDetectorTests: XCTestCase {
    func testBrandAndGenericAreDuplicates() {
        let lipitor = MedicationSnapshot(name: "Lipitor", ingredients: ["atorvastatin"], ingredientSource: .rxNormExact)
        let generic = MedicationSnapshot(name: "Atorvastatine 20 mg")
        let other = MedicationSnapshot(name: "Lisinopril")

        let flags = DuplicateDetector.duplicates(in: [lipitor, generic, other])
        XCTAssertEqual(flags.count, 1)
        XCTAssertEqual(flags[0].ingredients, ["atorvastatin"])
        XCTAssertEqual(Set(flags[0].medicationIDs), [lipitor.id, generic.id])
    }

    func testDifferentSaltsOfSameDrugAreDuplicates() {
        let flags = DuplicateDetector.duplicates(in: [
            MedicationSnapshot(name: "Metoprolol succinate ER"),
            MedicationSnapshot(name: "Metoprolol tartraat"),
        ])
        XCTAssertEqual(flags.map(\.ingredients), [["metoprolol"]])
    }

    func testCombinationProductOverlapsWithSingleIngredient() {
        let combo = MedicationSnapshot(name: "Zestoretic", ingredients: ["hydrochlorothiazide", "lisinopril"])
        let single = MedicationSnapshot(name: "Lisinopril 10 mg")
        let flags = DuplicateDetector.duplicates(in: [combo, single])
        XCTAssertEqual(flags.map(\.ingredients), [["lisinopril"]])
    }

    func testTwoCombinationsSharingBothIngredientsGiveOneFlag() {
        let a = MedicationSnapshot(name: "A", ingredients: ["x", "y"])
        let b = MedicationSnapshot(name: "B", ingredients: ["y", "x"])
        XCTAssertEqual(DuplicateDetector.duplicates(in: [a, b]).map(\.ingredients), [["x", "y"]])
    }

    func testSingleMedicationNeverDuplicatesItself() {
        XCTAssertTrue(DuplicateDetector.duplicates(in: [MedicationSnapshot(name: "A", ingredients: ["x", "x"])]).isEmpty)
        XCTAssertTrue(DuplicateDetector.duplicates(in: []).isEmpty)
    }
}

final class FlagEngineTests: XCTestCase {
    func testSampleInteractionIsFlagged() async {
        let engine = FlagEngine(interactions: SampleInteractionProvider.bundled())
        let warfarin = MedicationSnapshot(name: "Warfarin 5 mg")
        let ascal = MedicationSnapshot(name: "Ascal", ingredients: ["aspirin"], ingredientSource: .localAlias)

        let result = await engine.evaluate([warfarin, ascal])
        XCTAssertEqual(result.flags.count, 1)
        XCTAssertEqual(result.flags[0].kind, .interaction)
        XCTAssertEqual(Set(result.flags[0].medicationIDs), [warfarin.id, ascal.id])
        XCTAssertFalse(result.interactionCheckFailed)
        XCTAssertEqual(result.unresolvedMedicationIDs, [warfarin.id])
    }

    func testCombinationProductIsNotFlaggedAgainstItself() async {
        let provider = SampleInteractionProvider(records: [
            InteractionRecord(ingredientA: "lisinopril", ingredientB: "ibuprofen", descriptions: [:], source: "t"),
        ])
        let combo = MedicationSnapshot(name: "Combo", ingredients: ["lisinopril", "ibuprofen"])
        let result = await FlagEngine(interactions: provider).evaluate([combo, MedicationSnapshot(name: "Metformin")])
        XCTAssertTrue(result.flags.isEmpty)
    }

    func testProviderFailureIsReportedNotHidden() async {
        let result = await FlagEngine(interactions: FailingInteractions()).evaluate([
            MedicationSnapshot(name: "Lipitor", ingredients: ["atorvastatin"]),
            MedicationSnapshot(name: "Atorvastatin"),
        ])
        XCTAssertTrue(result.interactionCheckFailed)
        XCTAssertEqual(result.flags.map(\.kind), [.duplicateIngredient], "duplicates still work offline")
    }

    func testBundledSampleDataLoads() {
        XCTAssertGreaterThanOrEqual(SampleInteractionProvider.bundled().records.count, 5)
        XCTAssertEqual(LocalAliasTable.bundled().ingredients(for: "Pantozol 40 mg"), ["pantoprazole"])
    }
}

final class ReportLayoutTests: XCTestCase {
    func testShortListUsesBaseFont() {
        let plan = ReportLayout.plan(rowCount: 6, flagCount: 2)
        XCTAssertEqual(plan.fontSize, ReportLayout.baseFontSize)
        XCTAssertEqual(plan.visibleRows, 6)
        XCTAssertEqual(plan.hiddenRows, 0)
        XCTAssertEqual(plan.visibleFlags, 2)
    }

    func testLongerListShrinksFontBeforeTruncating() {
        let plan = ReportLayout.plan(rowCount: 20, flagCount: 1)
        XCTAssertLessThan(plan.fontSize, ReportLayout.baseFontSize)
        XCTAssertGreaterThanOrEqual(plan.fontSize, ReportLayout.minimumFontSize)
        XCTAssertEqual(plan.hiddenRows, 0)
    }

    func testVeryLongListTruncatesAtMinimumFont() {
        let plan = ReportLayout.plan(rowCount: 80, flagCount: 30)
        XCTAssertEqual(plan.fontSize, ReportLayout.minimumFontSize)
        XCTAssertGreaterThan(plan.hiddenRows, 0)
        XCTAssertEqual(plan.visibleRows + plan.hiddenRows, 80)
        XCTAssertEqual(plan.visibleFlags + plan.hiddenFlags, 30)
        XCTAssertGreaterThan(plan.visibleFlags, 0, "flags are never all pushed off the page")
        XCTAssertGreaterThan(plan.visibleRows, 10)
    }

    func testEverythingFitsOnOnePage() {
        for rows in 0...60 {
            for flags in [0, 1, 5, 20] {
                let p = ReportLayout.plan(rowCount: rows, flagCount: flags)
                let line = p.fontSize * ReportLayout.lineSpacing
                let used = ReportLayout.headerHeight + ReportLayout.footerHeight + line + ReportLayout.rowPadding
                    + Double(p.visibleRows) * (2 * line + ReportLayout.rowPadding)
                    + (p.hiddenRows > 0 ? line + ReportLayout.rowPadding : 0)
                    + (flags > 0 ? line + ReportLayout.rowPadding : 0)
                    + Double(p.visibleFlags) * (2 * line + ReportLayout.rowPadding)
                    + (p.hiddenFlags > 0 ? line + ReportLayout.rowPadding : 0)
                XCTAssertLessThanOrEqual(used, ReportLayout.pageSize.height - 2 * ReportLayout.margin, "rows \(rows) flags \(flags)")
            }
        }
    }
}
