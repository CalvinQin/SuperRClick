import XCTest
@testable import Shared

final class PersistenceControllerTests: XCTestCase {
    func testStateRoundTripsThroughDisk() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let controller = PersistenceController(storageDirectory: directory)

        let state = PersistenceState(
            pinnedActions: [PinnedAction(actionID: "copy-full-path", order: 1)],
            visibilityRules: [
                VisibilityRule(actionID: "copy-full-path", mode: .exclude, allowedContextKinds: [.finderSelection])
            ],
            workspaceProfiles: [
                WorkspaceProfile(
                    name: "Default",
                    rootURL: URL(fileURLWithPath: "/tmp/project"),
                    pinnedActionIDs: ["copy-full-path"]
                )
            ],
            monitoredFolders: [
                MonitoredFolder(
                    name: "Desktop",
                    url: URL(fileURLWithPath: "/tmp/Desktop", isDirectory: true),
                    preset: .desktop
                )
            ],
            actionHistory: [
                ActionInvocationRecord(
                    actionID: "copy-full-path",
                    context: ContextSnapshot(kind: .finderSelection, itemPaths: ["/tmp/example.txt"]),
                    outcome: .success,
                    note: "Round-trip"
                )
            ]
        )

        try controller.saveState(state)
        let loaded = try controller.loadState()

        XCTAssertEqual(loaded.pinnedActions, state.pinnedActions)
        XCTAssertEqual(loaded.visibilityRules, state.visibilityRules)
        XCTAssertEqual(loaded.workspaceProfiles.map(\.name), state.workspaceProfiles.map(\.name))
        XCTAssertEqual(loaded.workspaceProfiles.map(\.rootURL.path), state.workspaceProfiles.map(\.rootURL.path))
        XCTAssertEqual(loaded.monitoredFolders.map(\.name), state.monitoredFolders.map(\.name))
        XCTAssertEqual(loaded.monitoredFolders.map(\.url.path), state.monitoredFolders.map(\.url.path))
        XCTAssertEqual(loaded.monitoredFolders.map(\.preset), state.monitoredFolders.map(\.preset))
        XCTAssertEqual(loaded.actionHistory.map(\.actionID), state.actionHistory.map(\.actionID))
        XCTAssertEqual(loaded.actionHistory.map(\.outcome), state.actionHistory.map(\.outcome))
        XCTAssertEqual(loaded.actionHistory.map(\.note), state.actionHistory.map(\.note))
    }

    func testAppendInvocationKeepsRecentHistoryFirst() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let controller = PersistenceController(storageDirectory: directory)
        let record = ActionInvocationRecord(
            actionID: "copy-full-path",
            context: ContextSnapshot(kind: .finderSelection, itemPaths: ["/tmp/example.txt"]),
            outcome: .success
        )

        try controller.appendInvocation(record)
        let state = try controller.loadState()

        let loadedRecord = try XCTUnwrap(state.actionHistory.first)
        XCTAssertEqual(loadedRecord.actionID, record.actionID)
        XCTAssertEqual(loadedRecord.outcome, record.outcome)
        XCTAssertEqual(loadedRecord.note, record.note)
        XCTAssertEqual(loadedRecord.context, record.context)
    }

    func testLegacyStateWithoutMonitoredFoldersStillDecodes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let controller = PersistenceController(storageDirectory: directory)
        let legacyJSON = """
        {
          "actionHistory" : [ ],
          "pinnedActions" : [ ],
          "visibilityRules" : [ ],
          "workspaceProfiles" : [ ]
        }
        """

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try XCTUnwrap(legacyJSON.data(using: .utf8))
        try data.write(to: controller.stateFileURL)

        let loaded = try controller.loadState()

        XCTAssertTrue(loaded.monitoredFolders.isEmpty)
        XCTAssertTrue(loaded.workspaceProfiles.isEmpty)
    }
}
