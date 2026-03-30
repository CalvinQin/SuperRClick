import Foundation
import XCTest
@testable import Shared

final class ExternalCommandCenterTests: XCTestCase {
    func testStoreAndConsumeBatchRenameRequestRoundTripsPendingFile() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let center = ExternalCommandCenter(
            container: AppGroupContainer(groupIdentifier: nil, fallbackFolderName: tempDirectory.lastPathComponent),
            bookmarkEncoder: { Data($0.path.utf8) },
            bookmarkResolver: { data in
                URL(fileURLWithPath: String(decoding: data, as: UTF8.self))
            },
            securityScopeStarter: { _ in false }
        )

        let context = ActionContext.finderSelection(
            [
                ActionItem(url: URL(fileURLWithPath: "/tmp/example-a.txt"), displayName: "example-a.txt", isDirectory: false),
                ActionItem(url: URL(fileURLWithPath: "/tmp/example-b.txt"), displayName: "example-b.txt", isDirectory: false)
            ],
            sourceApplicationBundleIdentifier: "com.apple.finder",
            workspaceIdentifier: "/tmp"
        )

        let request = try center.storeBatchRenameRequest(for: context)
        let pending = try center.loadPendingRequest()
        XCTAssertEqual(pending?.id, request.id)
        XCTAssertEqual(pending?.items.count, 2)

        let consumed = try center.consumePendingRequest()
        XCTAssertEqual(consumed?.id, request.id)
        XCTAssertNil(try center.loadPendingRequest())
    }

    func testResolveBatchRenameRequestRestoresActionContext() throws {
        let item = ExternalCommandItem(
            bookmarkData: Data("/tmp/demo.txt".utf8),
            displayName: "demo.txt",
            isDirectory: false
        )
        let request = ExternalCommandRequest(
            kind: .presentBatchRename,
            sourceApplicationBundleIdentifier: "com.apple.finder",
            workspaceIdentifier: "/tmp",
            metadata: ["finder.surface": "selection"],
            items: [item]
        )

        let center = ExternalCommandCenter(
            container: AppGroupContainer(groupIdentifier: nil, fallbackFolderName: "UnitTest"),
            bookmarkEncoder: { _ in Data() },
            bookmarkResolver: { data in
                URL(fileURLWithPath: String(decoding: data, as: UTF8.self))
            },
            securityScopeStarter: { _ in true }
        )

        let resolved = try center.resolveBatchRenameRequest(request)
        XCTAssertEqual(resolved.context.items.count, 1)
        XCTAssertEqual(resolved.context.items.first?.url.path, "/tmp/demo.txt")
        XCTAssertEqual(resolved.context.metadata["external.command.kind"], ExternalCommandKind.presentBatchRename.rawValue)
        XCTAssertEqual(resolved.securityScopedURLs.count, 1)
    }

    func testStoreBatchRenameRequestRejectsEmptySelection() {
        let center = ExternalCommandCenter(
            container: AppGroupContainer(groupIdentifier: nil, fallbackFolderName: "UnitTest"),
            bookmarkEncoder: { _ in Data() },
            bookmarkResolver: { _ in URL(fileURLWithPath: "/tmp") },
            securityScopeStarter: { _ in false }
        )

        XCTAssertThrowsError(try center.storeBatchRenameRequest(for: ActionContext.finderSelection([]))) { error in
            XCTAssertEqual(
                (error as? ExternalCommandCenter.ExternalCommandError)?.errorDescription,
                ExternalCommandCenter.ExternalCommandError.missingItems.errorDescription
            )
        }
    }
}

