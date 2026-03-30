import XCTest
@testable import Shared

final class ActionEngineTests: XCTestCase {
    func testAvailableActionsRespectContextAndVisibilityRules() async {
        let context = ActionContext.finderSelection([
            ActionItem(url: URL(fileURLWithPath: "/tmp/photo.png"), displayName: "photo.png")
        ])

        let engine = ActionEngine()
        let actions = await engine.availableActions(for: context)
        let ids = actions.map(\.id.rawValue)

        XCTAssertTrue(ids.contains("copy-full-path"))
        XCTAssertTrue(ids.contains("convert-image"))
        XCTAssertFalse(ids.contains("copy-selected-text"))
    }

    func testRegisteredHandlerExecutes() async {
        let engine = ActionEngine()
        let actionID: ActionID = "copy-full-path"
        let context = ActionContext.finderSelection([
            ActionItem(url: URL(fileURLWithPath: "/tmp/example.txt"), displayName: "example.txt")
        ])

        await engine.registerHandler(for: actionID) { _ in
            .completed(message: "Copied")
        }

        let result = await engine.execute(actionID: actionID, context: context)

        XCTAssertEqual(result, .completed(message: "Copied"))
    }

    func testHiddenActionReturnsBlockedResult() async {
        let rule = VisibilityRule(
            actionID: "copy-full-path",
            mode: .exclude,
            allowedContextKinds: [.finderSelection]
        )
        let engine = ActionEngine(visibilityRules: [rule])
        let context = ActionContext.finderSelection([
            ActionItem(url: URL(fileURLWithPath: "/tmp/example.txt"), displayName: "example.txt")
        ])

        let result = await engine.execute(actionID: "copy-full-path", context: context)

        guard case .blocked = result else {
            return XCTFail("Expected blocked result")
        }
    }
}

