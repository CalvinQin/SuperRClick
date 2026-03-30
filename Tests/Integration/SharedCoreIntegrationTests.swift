import XCTest
@testable import Shared

final class SharedCoreIntegrationTests: XCTestCase {
    func testPersistenceRulesCanDriveEngineVisibility() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let controller = PersistenceController(storageDirectory: directory)
        let excludeRule = VisibilityRule(
            actionID: "copy-shell-escaped-path",
            mode: .exclude,
            allowedContextKinds: [.finderSelection]
        )

        try controller.updateVisibilityRules([excludeRule])
        let state = try controller.loadState()
        let engine = ActionEngine(visibilityRules: state.visibilityRules)

        let context = ActionContext.finderSelection([
            ActionItem(url: URL(fileURLWithPath: "/tmp/example.txt"), displayName: "example.txt")
        ])
        let actions = await engine.availableActions(for: context)
        let ids = actions.map(\.id.rawValue)

        XCTAssertFalse(ids.contains("copy-shell-escaped-path"))
        XCTAssertTrue(ids.contains("copy-full-path"))
    }
}

