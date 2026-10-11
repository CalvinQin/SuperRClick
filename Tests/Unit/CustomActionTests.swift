import XCTest
@testable import Shared

final class CustomActionTests: XCTestCase {
    func testRejectsBlankNames() {
        for name in ["", " \t\n", "\u{00A0}\u{3000}"] {
            let action = CustomAction(name: name, scriptContent: "echo hello")

            XCTAssertThrowsError(try action.validated()) { error in
                XCTAssertEqual(error as? CustomAction.ValidationError, .emptyName)
                XCTAssertEqual(error.localizedDescription, L("请输入动作名称。", "Enter an action name."))
            }
        }
    }

    func testRejectsBlankContentForEveryActionType() {
        for actionType in CustomActionType.allCases {
            for content in ["", " \t\r\n"] {
                let action = CustomAction(name: "Example", actionType: actionType, scriptContent: content)

                XCTAssertThrowsError(try action.validated()) { error in
                    XCTAssertEqual(error as? CustomAction.ValidationError, .emptyContent(actionType))
                    XCTAssertNotNil((error as? LocalizedError)?.errorDescription)
                }
            }
        }
    }

    func testNormalizesExtensionsAndPreservesTheirFirstOccurrenceOrder() throws {
        let action = CustomAction(
            name: "Example",
            scriptContent: "echo hello",
            fileExtensionFilter: [" .TXT ", "txt", "\n.PDF\t", "..Md", "PDF", "", "  "]
        )

        XCTAssertEqual(try action.validated().fileExtensionFilter, ["txt", "pdf", "md"])
    }

    func testRejectsInvalidExtensionEntries() {
        for entry in [".", "...", "t xt", "t\nxt", "t\txt", "t\u{00A0}xt", "a/b", "a\\b", "*", "t?t", "[ab]", "txt,pdf", "txt，pdf"] {
            let action = CustomAction(name: "Example", scriptContent: "echo hello", fileExtensionFilter: [entry])

            XCTAssertThrowsError(try action.validated(), "Unexpectedly accepted \(entry.debugDescription)") { error in
                XCTAssertEqual(error as? CustomAction.ValidationError, .invalidFileExtension(entry))
            }
        }
    }

    func testSelectionCountMustBeWithinSupportedRange() throws {
        for count in [-1, 0, 101, Int.max] {
            let action = CustomAction(name: "Example", scriptContent: "echo hello", minimumSelectionCount: count)

            XCTAssertThrowsError(try action.validated()) { error in
                XCTAssertEqual(error as? CustomAction.ValidationError, .invalidMinimumSelectionCount)
            }
        }

        for count in [1, 100] {
            let action = CustomAction(name: "Example", scriptContent: "echo hello", minimumSelectionCount: count)
            XCTAssertEqual(try action.validated().minimumSelectionCount, count)
        }
    }

    func testValidationReturnsNormalizedCopyWhilePreservingIdentityAndScriptBytes() throws {
        let script = "\n  cat <<'TEXT'\r\n  preserve spacing\r\nTEXT\n\t"
        let action = CustomAction(
            name: " \nExample\t ",
            subtitle: "\tDescription\n",
            systemImageName: "terminal",
            actionType: .shellScript,
            scriptContent: script,
            section: .file,
            fileExtensionFilter: [" .TXT "],
            minimumSelectionCount: 2,
            isEnabled: false,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let original = action

        let validated = try action.validated()

        XCTAssertEqual(action, original)
        XCTAssertEqual(validated.id, original.id)
        XCTAssertEqual(validated.createdAt, original.createdAt)
        XCTAssertEqual(validated.isEnabled, original.isEnabled)
        XCTAssertEqual(validated.actionType, original.actionType)
        XCTAssertEqual(validated.systemImageName, original.systemImageName)
        XCTAssertEqual(validated.section, original.section)
        XCTAssertEqual(validated.minimumSelectionCount, original.minimumSelectionCount)
        XCTAssertEqual(Array(validated.scriptContent.utf8), Array(script.utf8))
        XCTAssertEqual(validated.name, "Example")
        XCTAssertEqual(validated.subtitle, "Description")
        XCTAssertEqual(validated.fileExtensionFilter, ["txt"])
        XCTAssertEqual(try validated.validated(), validated)
    }

    func testParsesBothCommaSeparatorsWithoutDiscardingInvalidEntries() {
        XCTAssertEqual(CustomAction.parseFileExtensions(" .TXT, pdf， .md ,, ， \n"), [".TXT", "pdf", ".md"])
        XCTAssertEqual(CustomAction.parseFileExtensions(" \t\n，,,"), [])
        XCTAssertEqual(CustomAction.parseFileExtensions("txt,*.pdf"), ["txt", "*.pdf"])
    }

    func testNormalizedExtensionMatchesFinderSelection() throws {
        let action = try CustomAction(name: "Example", scriptContent: "echo hello", fileExtensionFilter: [" .TXT "]).validated()
        let matchingContext = ActionContext.finderSelection([ActionItem(url: URL(fileURLWithPath: "/tmp/report.TXT"))])
        let otherContext = ActionContext.finderSelection([ActionItem(url: URL(fileURLWithPath: "/tmp/report.pdf"))])

        XCTAssertTrue(action.toActionDefinition().matches(matchingContext))
        XCTAssertFalse(action.toActionDefinition().matches(otherContext))
    }

    func testEmptyFilterKeepsAllFileTypesAvailable() throws {
        let action = try CustomAction(name: "Example", scriptContent: "echo hello").validated()
        let context = ActionContext.finderSelection([ActionItem(url: URL(fileURLWithPath: "/tmp/report.pdf"))])

        XCTAssertTrue(action.fileExtensionFilter.isEmpty)
        XCTAssertTrue(action.toActionDefinition().matches(context))
    }
}
