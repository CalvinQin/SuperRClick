import XCTest
@testable import Shared

final class ActionContextTests: XCTestCase {
    func testInfersFinderSelectionKind() {
        let context = ActionContext.finderSelection([
            ActionItem(url: URL(fileURLWithPath: "/tmp/example.txt"), displayName: "example.txt")
        ])

        XCTAssertEqual(context.kind, .finderSelection)
        XCTAssertTrue(context.hasFileItems)
        XCTAssertFalse(context.hasTextSelection)
        XCTAssertEqual(context.totalSelectionCount, 1)
        XCTAssertEqual(context.summary, "example.txt")
    }

    func testInfersMixedSelectionKindAndSnapshot() {
        let context = ActionContext.mixedSelection(
            items: [ActionItem(url: URL(fileURLWithPath: "/tmp/example.png"), displayName: "example.png")],
            selectedText: "Hello, Super RClick"
        )

        XCTAssertEqual(context.kind, .mixedSelection)
        XCTAssertTrue(context.hasFileItems)
        XCTAssertTrue(context.hasTextSelection)
        XCTAssertEqual(context.snapshot.kind, .mixedSelection)
        XCTAssertEqual(context.snapshot.itemPaths, ["/tmp/example.png"])
        XCTAssertNotNil(context.snapshot.selectedTextPreview)
    }

    func testFinderContainerPreservesDesktopMetadata() {
        let desktopURL = URL(fileURLWithPath: "/tmp/Desktop", isDirectory: true)
        let context = ActionContext.finderContainer(
            desktopURL,
            displayName: "Desktop",
            surface: .desktop,
            sourceApplicationBundleIdentifier: "com.apple.finder"
        )

        XCTAssertEqual(context.kind, .finderSelection)
        XCTAssertEqual(context.finderMenuKind, "container")
        XCTAssertEqual(context.finderSurface, .desktop)
        XCTAssertTrue(context.isFinderDesktopSurface)
        XCTAssertEqual(context.primaryDirectoryURL?.path, desktopURL.path)
        XCTAssertEqual(context.summary, "Desktop")
    }
}
