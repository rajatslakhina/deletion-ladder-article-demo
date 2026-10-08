import XCTest
@testable import DeletionLadder

final class DeletionLadderTests: XCTestCase {
    private let floor = DeletionLadder(catalog: SampleSprint.catalog, policy: .protectedFloor)
    private let linesOnly = DeletionLadder(catalog: SampleSprint.catalog, policy: .linesOnly)

    private func change(_ id: String) throws -> ProposedChange {
        try XCTUnwrap(SampleSprint.changes.first { $0.id == id }, "missing sample \(id)")
    }

    func testUnrequestedCodeGoesEntirely() throws {
        let verdict = floor.evaluate(try change("analytics"))
        XCTAssertEqual(verdict.rung, .needsToExist)
        XCTAssertEqual(verdict.projectedLines, 0)
        XCTAssertEqual(verdict.unsafeDeletionCount, 0, "protection for deleted code isn't an unsafe deletion")
    }

    func testFirstRungThatHoldsWins() {
        var catalog = CapabilityCatalog()
        catalog.register(Provider(rung: .installedDependency, symbol: "Dep", callSiteLines: 2), for: "x")
        catalog.register(Provider(rung: .alreadyInCodebase, symbol: "Ours", callSiteLines: 3), for: "x")
        let verdict = DeletionLadder(catalog: catalog).evaluate(
            ProposedChange(id: "x", title: "x", capability: "x", lines: [.logic: 40]))
        XCTAssertEqual(verdict.rung, .alreadyInCodebase)
        XCTAssertEqual(verdict.replacement?.symbol, "Ours")
        XCTAssertEqual(verdict.projectedLines, 3)
    }

    func testProviderThatCoversARoleCanRemoveIt() throws {
        let verdict = floor.evaluate(try change("date-picker"))
        XCTAssertEqual(verdict.rung, .platformFeature)
        XCTAssertEqual(verdict.projectedLines, 4, "DatePicker brings its own accessibility")
        XCTAssertTrue(verdict.keptProtected.isEmpty)
    }

    func testFloorKeepsValidationTheReplacementDoesNotDo() throws {
        let verdict = floor.evaluate(try change("deep-link"))
        XCTAssertEqual(verdict.keptProtected[.validation], 11)
        XCTAssertEqual(verdict.projectedLines, 3 + 11)
        XCTAssertEqual(verdict.unsafeDeletionCount, 0)
    }

    func testLinesOnlyPolicyDeletesTheValidation() throws {
        let verdict = linesOnly.evaluate(try change("deep-link"))
        XCTAssertEqual(verdict.projectedLines, 3)
        XCTAssertEqual(verdict.unsafeDeletions[.validation], 11)
    }

    func testKeychainKeepsSecurityAndErrorHandling() throws {
        let verdict = floor.evaluate(try change("keychain"))
        XCTAssertEqual(verdict.keptProtected[.security], 4)
        XCTAssertEqual(verdict.keptProtected[.errorHandling], 6)
        XCTAssertEqual(verdict.projectedLines, 14)
    }

    func testNoProviderMeansNoChange() throws {
        let verdict = floor.evaluate(try change("settings-toggle"))
        XCTAssertEqual(verdict.rung, .minimumThatWorks)
        XCTAssertNil(verdict.replacement)
        XCTAssertEqual(verdict.removedLines, 0)
    }

    func testAlreadyMinimalCodeIsNotInflated() throws {
        // `.refreshable` costs 3 lines and the agent already wrote 3.
        let verdict = floor.evaluate(try change("pull-to-refresh"))
        XCTAssertEqual(verdict.rung, .minimumThatWorks)
        XCTAssertEqual(verdict.projectedLines, 3)
        XCTAssertEqual(verdict.reduction, 0)
    }

    func testProjectionNeverExceedsOriginal() {
        var catalog = CapabilityCatalog()
        catalog.register(Provider(rung: .platformFeature, symbol: "Big", callSiteLines: 50), for: "y")
        let verdict = DeletionLadder(catalog: catalog).evaluate(
            ProposedChange(id: "y", title: "y", capability: "y", lines: [.logic: 5, .validation: 2]))
        XCTAssertEqual(verdict.projectedLines, 7)
        XCTAssertEqual(verdict.rung, .minimumThatWorks)
    }

    func testEmptyChangeHasZeroReduction() {
        let verdict = floor.evaluate(ProposedChange(id: "e", title: "e", capability: "date-picker", lines: [:]))
        XCTAssertEqual(verdict.reduction, 0)
        XCTAssertEqual(verdict.projectedLines, 0)
    }

    func testSprintReportUnderFloor() {
        let report = ReductionReport(floor.evaluate(SampleSprint.changes))
        XCTAssertEqual(report.changeCount, 12)
        XCTAssertEqual(report.linesBefore, 710)
        XCTAssertEqual(report.linesAfter, 59)
        XCTAssertEqual(report.unsafeDeletions, 0)
        XCTAssertEqual(report.untouchedCount, 2)
        XCTAssertEqual(report.meanReduction, 0.767, accuracy: 0.001)
        XCTAssertEqual(report.medianReduction, 0.915, accuracy: 0.001)
        // The date picker and the image cache carry about half of everything removed.
        XCTAssertEqual(report.topShare, 330.0 / 651.0, accuracy: 1e-9)
    }

    func testLinesOnlyLooksBetterAndIsWorse() {
        let safe = ReductionReport(floor.evaluate(SampleSprint.changes))
        let naive = ReductionReport(linesOnly.evaluate(SampleSprint.changes))
        XCTAssertGreaterThan(naive.linesRemoved, safe.linesRemoved)
        XCTAssertEqual(naive.linesRemoved - safe.linesRemoved, naive.unsafeDeletions)
        XCTAssertEqual(naive.unsafeDeletions, 21)
        XCTAssertEqual(naive.linesAfter, 38)
    }

    func testMedianHandlesEvenOddAndEmpty() {
        XCTAssertEqual(ReductionReport.median(of: []), 0)
        XCTAssertEqual(ReductionReport.median(of: [0.1, 0.5, 0.9]), 0.5)
        XCTAssertEqual(ReductionReport.median(of: [0, 0.2, 0.4, 1]), 0.3, accuracy: 1e-9)
    }

    func testTopShareWithFewerChangesThanTopCount() {
        let one = floor.evaluate([SampleSprint.changes[0]])
        let report = ReductionReport(one, topCount: 5)
        XCTAssertEqual(report.topCount, 1)
        XCTAssertEqual(report.topShare, 1)
        XCTAssertEqual(ReductionReport([]).topShare, 0)
    }

    func testPromptListsAllRungsAndTheFloor() {
        let text = PromptRenderer.render(catalog: SampleSprint.catalog, capabilities: ["share-sheet", "unknown"])
        for rung in Rung.allCases { XCTAssertTrue(text.contains(rung.question)) }
        XCTAssertTrue(text.contains("Never remove input validation"))
        XCTAssertTrue(text.contains("`ShareLink(item:)`"))
        XCTAssertFalse(text.contains("unknown"))
    }
}
