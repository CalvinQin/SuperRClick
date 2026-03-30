import XCTest
@testable import Shared

final class BuiltInActionCatalogTests: XCTestCase {
    func testCatalogContainsStableUniqueActions() {
        let ids = BuiltInActionCatalog.all.map(\.id.rawValue)

        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(ids.contains("copy-full-path"))
        XCTAssertTrue(ids.contains("open-terminal-here"))
        XCTAssertTrue(ids.contains("copy-selected-text"))
    }

    func testFileAndTextActionsAreSeparated() {
        XCTAssertTrue(BuiltInActionCatalog.fileActions.allSatisfy { $0.section == .file || $0.section == .system })
        XCTAssertTrue(BuiltInActionCatalog.textActions.allSatisfy { $0.section == .text })
    }
}

