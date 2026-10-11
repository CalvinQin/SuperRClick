import Foundation
import XCTest

/// Real UI and disk writes in a fresh directory per test. DEBUG isolation also skips
/// Finder monitoring, setup, network, and Keychain access; scripts are never executed.
@MainActor
final class SuperRClickUITests: XCTestCase {
    override nonisolated func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRequiredFieldsAndCancelNeverSaveADraft() throws {
        let session = try launchSession()
        let app = session.app
        let originalData = try Data(contentsOf: session.stateURL)
        openNewAction(in: app)
        expect(app.buttons["action.save"], "enabled == false", in: app)
        app.buttons["action.cancel"].click()
        expectEditorClosed(in: app)
        XCTAssertEqual(try Data(contentsOf: session.stateURL), originalData)

        openNewAction(in: app)
        replaceText(app.textFields["action.name"], with: "Unsaved draft", in: app)
        expect(app.buttons["action.save"], "enabled == false", in: app)
        replaceText(app.textViews["action.script"], with: "echo draft", in: app)
        expect(app.buttons["action.save"], "enabled == true", in: app)
        replaceText(app.textFields["action.name"], with: "", in: app)
        expect(app.buttons["action.save"], "enabled == false", in: app)
        replaceText(app.textFields["action.name"], with: "Unsaved draft", in: app)

        app.buttons["action.cancel"].click()
        let keepEditing = app.buttons["Keep Editing"]
        expect(keepEditing, "exists == true", in: app)
        attachWindow(app, named: "01-editor-discard-confirmation")
        keepEditing.click()
        expect(app.textFields["action.name"], "value == 'Unsaved draft'", in: app)
        XCTAssertEqual(try Data(contentsOf: session.stateURL), originalData)
        discardEditor(in: app)
        XCTAssertEqual(try Data(contentsOf: session.stateURL), originalData)
        XCTAssertTrue(try session.readState().customActions.isEmpty)
    }

    func testCreateEditCancelThenSavePreservesIdentityAfterRelaunch() throws {
        let session = try launchSession()
        let app = session.app
        openNewAction(in: app)
        fillAction(in: app, name: "UI Test Action", script: "echo original")
        replaceText(app.textFields["action.description"], with: "Original description", in: app)
        app.buttons["action.save"].click()
        expectEditorClosed(in: app)
        let created = try XCTUnwrap(session.readState().customActions.first)
        XCTAssertEqual(try session.readState().customActions.count, 1)
        selectCustomActions(in: app)
        let edit = app.buttons["edit.\(created.id.uuidString)"]
        expect(edit, "exists == true", in: app)
        attachWindow(app, named: "02-library-created-action")

        edit.click()
        replaceText(app.textFields["action.name"], with: "Discard this rename", in: app)
        replaceText(app.textViews["action.script"], with: "echo discarded", in: app)
        discardEditor(in: app)
        XCTAssertEqual(try session.readState().customActions, [created])
        edit.click()
        expect(app.textFields["action.name"], "value == 'UI Test Action'", in: app)
        expect(app.textViews["action.script"], "value == 'echo original'", in: app)
        replaceText(app.textFields["action.name"], with: "Updated UI Action", in: app)
        replaceText(app.textViews["action.script"], with: "echo updated", in: app)
        replaceText(app.textFields["action.description"], with: "Saved description", in: app)
        app.buttons["action.save"].click()
        expectEditorClosed(in: app)
        let saved = try XCTUnwrap(session.readState().customActions.first)
        XCTAssertEqual(try session.readState().customActions.count, 1, "Editing must update, not duplicate, an action.")
        XCTAssertEqual(saved.id, created.id)
        XCTAssertEqual(saved.createdAt, created.createdAt)
        XCTAssertEqual(saved.name, "Updated UI Action")
        XCTAssertEqual(saved.scriptContent, "echo updated")
        XCTAssertEqual(saved.subtitle, "Saved description")

        relaunch(session)
        selectCustomActions(in: app)
        let restoredEdit = app.buttons["edit.\(created.id.uuidString)"]
        expect(restoredEdit, "exists == true", in: app)
        restoredEdit.click()
        expect(app.textFields["action.name"], "value == 'Updated UI Action'", in: app)
        expect(app.textViews["action.script"], "value == 'echo updated'", in: app)
        expect(app.textFields["action.description"], "value == 'Saved description'", in: app)
        XCTAssertEqual(try session.readState().customActions, [saved])
        attachWindow(app, named: "03-editor-restored-after-relaunch")
        app.buttons["action.cancel"].click()
        expectEditorClosed(in: app)
    }

    func testInvalidExtensionsShowInlineErrorAndRetainDraftForCorrection() throws {
        let session = try launchSession()
        let app = session.app
        openNewAction(in: app)
        fillAction(in: app, name: "Extension validation", script: "echo validation")
        replaceText(app.textFields["action.extensions"], with: "*.txt, pdf", in: app)
        app.buttons["action.save"].click()
        expect(element("action.saveError", in: app), "exists == true", in: app)
        expect(app.textFields["action.extensions"], "value == '*.txt, pdf'", in: app)
        expect(app.textFields["action.name"], "value == 'Extension validation'", in: app)
        expect(app.textViews["action.script"], "value == 'echo validation'", in: app)
        XCTAssertTrue(try session.readState().customActions.isEmpty)
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS %@ OR value CONTAINS %@", "not a valid extension", "not a valid extension")).firstMatch.exists,
                      app.debugDescription)
        attachWindow(app, named: "04-editor-inline-extension-error")
        replaceText(app.textFields["action.extensions"], with: ".TXT, pdf, txt", in: app)
        app.buttons["action.save"].click()
        expectEditorClosed(in: app)
        let saved = try XCTUnwrap(session.readState().customActions.first)
        XCTAssertEqual(saved.fileExtensionFilter, ["txt", "pdf"])
        XCTAssertEqual(saved.scriptContent, "echo validation")
        XCTAssertEqual(try session.readState().customActions.count, 1)
    }

    func testDiskWriteFailureKeepsEditorAndRetrySavesExactlyOnce() throws {
        let session = try launchSession()
        let app = session.app
        openNewAction(in: app)
        fillAction(in: app, name: "Retry after disk failure", script: "echo retry")
        // A nonempty directory where JSON should be written produces a real atomic-write error.
        let backup = session.directory.appendingPathComponent("state-before-failure.json")
        try FileManager.default.moveItem(at: session.stateURL, to: backup)
        try FileManager.default.createDirectory(at: session.stateURL, withIntermediateDirectories: false)
        let marker = session.stateURL.appendingPathComponent("write-blocker")
        try Data("test-owned blocker".utf8).write(to: marker)
        app.buttons["action.save"].click()
        expect(element("action.saveError", in: app), "exists == true", in: app)
        expect(app.textFields["action.name"], "value == 'Retry after disk failure'", in: app)
        expect(app.textViews["action.script"], "value == 'echo retry'", in: app)
        expect(app.buttons["action.save"], "enabled == true", in: app)
        XCTAssertFalse(app.staticTexts["Custom action created"].exists, "A failed write must not announce success.")
        XCTAssertFalse(element("operation.status", in: app).exists, "Only the editor's error should be presented.")
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        attachWindow(app, named: "05-editor-disk-error-draft-retained")
        // Repeating Save during the failure must keep the same draft open.
        app.buttons["action.save"].click()
        expect(element("action.saveError", in: app), "exists == true", in: app)
        expect(app.textFields["action.name"], "value == 'Retry after disk failure'", in: app)
        try FileManager.default.removeItem(at: session.stateURL)
        try FileManager.default.moveItem(at: backup, to: session.stateURL)
        XCTAssertTrue(try session.readState().customActions.isEmpty)
        app.buttons["action.save"].click()
        expectEditorClosed(in: app)
        let actions = try session.readState().customActions
        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions.first?.name, "Retry after disk failure")
        XCTAssertEqual(actions.first?.scriptContent, "echo retry")
        selectCustomActions(in: app)
        attachWindow(app, named: "06-library-retry-succeeded")
    }

    func testSearchClearAndBuiltInPinVisibilityPersist() throws {
        let session = try launchSession()
        let app = session.app
        let actionID = "copy-full-path"
        let initialState = try session.readState()
        let initiallyPinned = initialState.isPinned(actionID)
        let initiallyHidden = initialState.isHidden(actionID)
        attachWindow(app, named: "00-library-initial-state")
        let search = app.searchFields.firstMatch
        replaceText(search, with: "no-results-\(UUID().uuidString)", in: app)
        expect(element("library.emptyState", in: app), "exists == true", in: app)
        attachWindow(app, named: "07-library-search-empty-state")
        app.buttons["library.clearFilters"].click()
        expect(search, "value == ''", in: app)
        let pin = app.buttons["pin.\(actionID)"]
        expect(pin, "exists == true", in: app)
        pin.click()
        expect(pin, initiallyPinned ? "label BEGINSWITH 'Pin '" : "label BEGINSWITH 'Unpin '", in: app)
        let visibility = element("visibility.\(actionID)", in: app)
        visibility.click()
        expectToggle(visibility, isOn: initiallyHidden, in: app)
        XCTAssertEqual(try session.readState().isPinned(actionID), !initiallyPinned)
        XCTAssertEqual(try session.readState().isHidden(actionID), !initiallyHidden)
        element("sidebar.pinned", in: app).click()
        element("sidebar.actionLibrary", in: app).click()
        expectToggle(element("visibility.\(actionID)", in: app), isOn: initiallyHidden, in: app)
        attachWindow(app, named: "08-library-pin-and-visibility")
        relaunch(session)
        let restoredPin = app.buttons["pin.\(actionID)"]
        expect(restoredPin, initiallyPinned ? "label BEGINSWITH 'Pin '" : "label BEGINSWITH 'Unpin '", in: app)
        expectToggle(element("visibility.\(actionID)", in: app), isOn: initiallyHidden, in: app)
        XCTAssertEqual(try session.readState().isPinned(actionID), !initiallyPinned)
        XCTAssertEqual(try session.readState().isHidden(actionID), !initiallyHidden)
        // Both controls must work in both directions.
        restoredPin.click()
        element("visibility.\(actionID)", in: app).click()
        expectToggle(element("visibility.\(actionID)", in: app), isOn: !initiallyHidden, in: app)
        XCTAssertEqual(try session.readState().isPinned(actionID), initiallyPinned)
        XCTAssertEqual(try session.readState().isHidden(actionID), initiallyHidden)
    }

    func testUnsavedAIDraftIsDiscardedAndDoesNotLeakIntoActionSaves() throws {
        let session = try launchSession()
        let app = session.app
        let actionID = "copy-full-path"
        let initialState = try session.readState()
        XCTAssertTrue(initialState.aiConfig.isEnabled)

        element("sidebar.settings", in: app).click()
        let enabled = element("ai.enabled", in: app)
        reveal(enabled, in: app)
        expectToggle(enabled, isOn: true, in: app)
        enabled.click()
        expectToggle(enabled, isOn: false, in: app)
        expect(element("ai.unsavedChanges", in: app), "exists == true", in: app)
        XCTAssertTrue(try session.readState().aiConfig.isEnabled)

        element("sidebar.actionLibrary", in: app).click()
        waitForLibrary(in: app)
        let pin = app.buttons["pin.\(actionID)"]
        reveal(pin, in: app)
        pin.click()
        let stateAfterPin = try session.readState()
        XCTAssertEqual(stateAfterPin.isPinned(actionID), !initialState.isPinned(actionID))
        XCTAssertTrue(stateAfterPin.aiConfig.isEnabled,
                      "Saving an action preference must not persist an unsaved AI draft.")

        element("sidebar.settings", in: app).click()
        let restoredEnabled = element("ai.enabled", in: app)
        reveal(restoredEnabled, in: app)
        expectToggle(restoredEnabled, isOn: true, in: app)
        expect(element("ai.unsavedChanges", in: app), "exists == false", in: app)
        restoredEnabled.click()
        expectToggle(restoredEnabled, isOn: false, in: app)
        expect(element("ai.unsavedChanges", in: app), "exists == true", in: app)
        let save = app.buttons["ai.save"]
        reveal(save, in: app)
        expect(save, "enabled == true", in: app)
        save.click()
        expect(element("ai.unsavedChanges", in: app), "exists == false", in: app)
        expect(element("ai.saveError", in: app), "exists == false", in: app)
        XCTAssertFalse(try session.readState().aiConfig.isEnabled)
        XCTAssertEqual(try session.readState().isPinned(actionID), !initialState.isPinned(actionID))
    }

    func testDisablingAICanBeSavedAndSurvivesRelaunch() throws {
        let session = try launchSession()
        let app = session.app
        XCTAssertTrue(try session.readState().aiConfig.isEnabled)
        element("sidebar.settings", in: app).click()
        let enabled = element("ai.enabled", in: app)
        reveal(enabled, in: app)
        expectToggle(enabled, isOn: true, in: app)
        enabled.click()
        expectToggle(enabled, isOn: false, in: app)
        let save = app.buttons["ai.save"]
        reveal(save, in: app)
        expect(save, "enabled == true", in: app)
        expect(element("ai.unsavedChanges", in: app), "exists == true", in: app)
        XCTAssertTrue(try session.readState().aiConfig.isEnabled, "The draft must not be written before Save.")
        save.click()
        expect(save, "label CONTAINS 'Saved'", in: app)
        XCTAssertFalse(try session.readState().aiConfig.isEnabled)
        XCTAssertFalse(element("ai.saveError", in: app).exists)
        expect(app.buttons["ai.testConnection"], "enabled == false", in: app)
        attachWindow(app, named: "09-settings-ai-disabled-and-saved")
        save.click()
        XCTAssertFalse(try session.readState().aiConfig.isEnabled)
        relaunch(session)
        element("sidebar.settings", in: app).click()
        let restoredEnabled = element("ai.enabled", in: app)
        reveal(restoredEnabled, in: app)
        expectToggle(restoredEnabled, isOn: false, in: app)
        XCTAssertFalse(try session.readState().aiConfig.isEnabled)
    }

    // MARK: - Native UI helpers

    private func launchSession() throws -> Session {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuperRClick-UITests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let app = XCUIApplication()
        app.launchEnvironment["SUPERRCLICK_TEST_STORAGE"] = directory.path
        app.launchArguments = ["-app_selected_language", "en", "-AppleLanguages", "(en)", "-showInDock", "YES"]
        addTeardownBlock {
            await MainActor.run { app.terminate() }
            try FileManager.default.removeItem(at: directory)
        }
        app.launch()
        waitForLibrary(in: app)
        return Session(app: app, directory: directory)
    }

    private func relaunch(_ session: Session) {
        session.app.terminate()
        session.app.launch()
        waitForLibrary(in: session.app)
    }

    private func waitForLibrary(in app: XCUIApplication) {
        expect(app.windows.firstMatch, "exists == true", in: app)
        expect(app.buttons["library.newAction"], "exists == true AND enabled == true", in: app)
    }

    private func openNewAction(in app: XCUIApplication) {
        app.buttons["library.newAction"].click()
        expect(app.textFields["action.name"], "exists == true", in: app)
    }

    private func fillAction(in app: XCUIApplication, name: String, script: String) {
        replaceText(app.textFields["action.name"], with: name, in: app)
        replaceText(app.textViews["action.script"], with: script, in: app)
    }

    private func discardEditor(in app: XCUIApplication) {
        app.buttons["action.cancel"].click()
        let discard = app.buttons["Discard Changes"]
        expect(discard, "exists == true", in: app)
        discard.click()
        expectEditorClosed(in: app)
    }

    private func expectEditorClosed(in app: XCUIApplication) {
        expect(app.buttons["action.save"], "exists == false", in: app)
    }

    private func selectCustomActions(in app: XCUIApplication) {
        // Native segmented controls can expose their choices as radio buttons on macOS.
        let custom = element("library.scope", in: app).descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Custom'")).firstMatch
        expect(custom, "exists == true", in: app)
        custom.click()
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func replaceText(_ field: XCUIElement, with text: String, in app: XCUIApplication) {
        reveal(field, in: app)
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeKey(XCUIKeyboardKey.delete, modifierFlags: [])
        if !text.isEmpty { field.typeText(text) }
        expect(field, NSPredicate(format: "value == %@", text), in: app)
    }

    private func reveal(_ target: XCUIElement, in app: XCUIApplication) {
        // Bounded native scrolling and accessibility hit-testing, never arbitrary sleeps.
        let fallbackScroll = app.sheets.firstMatch.exists
            ? app.sheets.firstMatch.scrollViews.firstMatch : app.windows.firstMatch.scrollViews.firstMatch
        for _ in 0..<10 {
            if target.exists && target.isHittable { return }
            let scroll: XCUIElement
            if target.exists {
                let enclosing = app.scrollViews.containing(.any, identifier: target.identifier).firstMatch
                scroll = enclosing.exists ? enclosing : fallbackScroll
            } else {
                scroll = fallbackScroll
            }
            guard scroll.exists else { break }
            let deltaY: CGFloat = target.exists && target.frame.midY < scroll.frame.midY ? 220 : -220
            scroll.scroll(byDeltaX: 0, deltaY: deltaY)
        }
        expect(target, "exists == true AND hittable == true", in: app)
    }

    private func expectToggle(_ toggle: XCUIElement, isOn: Bool, in app: XCUIApplication) {
        expect(toggle, NSPredicate(format: "value == %@ OR value == %@", NSNumber(value: isOn), isOn ? "1" : "0"), in: app)
    }

    private func expect(_ target: XCUIElement, _ format: String, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        expect(target, NSPredicate(format: format), in: app, file: file, line: line)
    }

    private func expect(_ target: XCUIElement, _ predicate: NSPredicate, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: target)], timeout: 8)
        XCTAssertEqual(result, .completed,
                       "Expected \(predicate.predicateFormat) for \(target).\n\(app.debugDescription)", file: file, line: line)
    }

    private func attachWindow(_ app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private struct Session {
    let app: XCUIApplication
    let directory: URL
    var stateURL: URL { directory.appendingPathComponent("super-rclick-state.json") }
    func readState() throws -> StoredState {
        try JSONDecoder().decode(StoredState.self, from: Data(contentsOf: stateURL))
    }
}

/// Decode the disk contract independently of the app's in-memory model.
private struct StoredState: Decodable {
    let customActions: [StoredAction]
    let pinnedActions: [StoredPin]
    let visibilityRules: [StoredVisibilityRule]
    let aiConfig: StoredAIConfig
    func isPinned(_ actionID: String) -> Bool { pinnedActions.contains { $0.actionID.rawValue == actionID } }
    func isHidden(_ actionID: String) -> Bool {
        visibilityRules.contains { $0.actionID?.rawValue == actionID && $0.mode == "exclude" }
    }
}

private struct StoredAction: Decodable, Equatable {
    let id: UUID
    let name: String
    let subtitle: String
    let scriptContent: String
    let fileExtensionFilter: [String]
    let createdAt: Double
}

private struct StoredPin: Decodable { let actionID: StoredActionID }
private struct StoredVisibilityRule: Decodable {
    let actionID: StoredActionID?
    let mode: String
}
private struct StoredAIConfig: Decodable { let isEnabled: Bool }

private struct StoredActionID: Decodable {
    let rawValue: String
    private enum CodingKeys: String, CodingKey { case rawValue }
    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer().decode(String.self) {
            rawValue = value
        } else {
            rawValue = try decoder.container(keyedBy: CodingKeys.self).decode(String.self, forKey: .rawValue)
        }
    }
}
