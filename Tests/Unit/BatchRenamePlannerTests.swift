import XCTest
@testable import Shared

final class BatchRenamePlannerTests: XCTestCase {
    func testPrefixModeBuildsPreviewWithNumbering() {
        let planner = BatchRenamePlanner(fileExistsAtPath: { _ in false })
        let request = BatchRenameRequest(
            mode: .prefix,
            token: "IMG",
            numbering: BatchRenameNumberingOptions(isEnabled: true, start: 1, step: 1, padding: 3, separator: "-"),
            items: [
                BatchRenameItemInput(url: URL(fileURLWithPath: "/tmp/photo.jpg"), isDirectory: false)
            ]
        )

        let plan = planner.makePlan(for: request)

        XCTAssertTrue(plan.canApply)
        XCTAssertEqual(plan.previews.count, 1)
        XCTAssertEqual(plan.previews.first?.proposedName, "IMG-001-photo.jpg")
        XCTAssertEqual(plan.previews.first?.status, .ready)
    }

    func testDuplicateProposedNamesAreReportedAsConflicts() {
        let planner = BatchRenamePlanner(fileExistsAtPath: { _ in false })
        let request = BatchRenameRequest(
            mode: .prefix,
            token: "",
            numbering: BatchRenameNumberingOptions(isEnabled: false),
            items: [
                BatchRenameItemInput(url: URL(fileURLWithPath: "/tmp/report.txt"), isDirectory: false),
                BatchRenameItemInput(url: URL(fileURLWithPath: "/tmp/report.md"), isDirectory: false)
            ],
            preserveFileExtension: false
        )

        let plan = planner.makePlan(for: request)

        XCTAssertFalse(plan.canApply)
        XCTAssertEqual(plan.conflicts.map(\.kind), [.duplicateProposedName, .duplicateProposedName])
        XCTAssertEqual(plan.previews.map(\.status), [.duplicateProposedName, .duplicateProposedName])
    }
}
