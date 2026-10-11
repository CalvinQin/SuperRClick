import Foundation
import Shared

private struct CheckResult: Codable {
    let name: String
    let passed: Bool
    let detail: String
}

private enum CheckError: Error {
    case timeout(String)
    case invalidIsolation
}

private actor SuspendedOperation {
    private var continuation: CheckedContinuation<ActionExecutionResult, Never>?
    private var callback: ProgressCallback?
    private(set) var executions = 0

    func run(_ callback: ProgressCallback?) async -> ActionExecutionResult {
        executions += 1
        self.callback = callback
        return await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilStarted() async throws {
        let deadline = Date().addingTimeInterval(5)
        while continuation == nil {
            guard Date() < deadline else { throw CheckError.timeout("suspended operation start") }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func report(_ current: Int, _ total: Int, _ detail: String) {
        callback?(current, total, detail)
    }

    func finish() {
        continuation?.resume(returning: .completed(message: "Fixture operation complete"))
        continuation = nil
    }
}

@main
@MainActor
struct CoordinatorBehaviorChecks {
    private static var results: [CheckResult] = []

    private static func check(_ condition: Bool, _ name: String, _ detail: String) {
        results.append(CheckResult(name: name, passed: condition, detail: detail))
        print("\(condition ? "PASS" : "FAIL") \(name): \(detail)")
    }

    private static func waitUntil(_ name: String, condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(10)
        while !condition() {
            guard Date() < deadline else { throw CheckError.timeout(name) }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private static func makeContext(_ urls: [URL]) -> ActionContext {
        .finderSelection(urls.map { ActionItem(url: $0, displayName: $0.lastPathComponent) })
    }

    static func main() async {
        do {
            guard let storagePath = ProcessInfo.processInfo.environment["SUPERRCLICK_TEST_STORAGE"],
                  storagePath.hasPrefix("/tmp/superrclick-coordinator-"),
                  AppCoordinator.isIsolatedPreview else { throw CheckError.invalidIsolation }
            let storage = URL(fileURLWithPath: storagePath, isDirectory: true)
            let root = storage.deletingLastPathComponent()
            let controller = PersistenceController(storageDirectory: storage)
            let coordinator = AppCoordinator(customExecutor: CustomActionExecutor(temporaryDirectory: root))
            try await waitUntil("coordinator bootstrap") { coordinator.isReady }
            check(try AppGroupContainer().resolveDirectory().path == storage.path,
                  "isolated-storage", "Production persistence resolves only to the temporary session.")

            try await progressReentryAndLateCallbacks(coordinator, root: root)
            try await successfulRenameAndGuards(coordinator, root: root)
            try cancellationBeforeApply(coordinator, root: root)
            try blockedConflict(coordinator, root: root)
            try await recoverableRenameFailure(coordinator, root: root)
            try aiPersistence(coordinator, controller: controller, root: root)
            try desktopAIMenuVisibility(coordinator, root: root)
            try await customActionRouting(coordinator, root: root)
            try await customExecutorFailurePaths(root: root)

            let reloaded = AppCoordinator()
            try await waitUntil("reload bootstrap") { reloaded.isReady }
            check(reloaded.persistenceState.aiConfig == coordinator.persistenceState.aiConfig,
                  "ai-reload", "A fresh coordinator restores the successfully saved configuration.")
        } catch {
            check(false, "harness-completion", String(describing: error))
        }

        if let reportPath = ProcessInfo.processInfo.environment["SUPERRCLICK_FUNCTIONAL_REPORT"] {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                try encoder.encode(results).write(to: URL(fileURLWithPath: reportPath), options: .atomic)
            } catch {
                print("FAIL report-write: \(error)")
                exit(1)
            }
        }
        print("RESULT \(results.filter(\.passed).count)/\(results.count) checks passed")
        exit(results.allSatisfy(\.passed) ? 0 : 1)
    }

    private static func progressReentryAndLateCallbacks(_ coordinator: AppCoordinator, root: URL) async throws {
        let first = SuspendedOperation()
        let rejected = SuspendedOperation()
        var completions = 0
        let showCount = TaskProgressWindowController.shared.showCount
        let accepted = coordinator.executeWithProgress(title: "First fixture", totalItems: 10) { callback in
            await first.run(callback)
        } completion: { _ in completions += 1 }
        let firstID = coordinator.taskProgress?.id
        let refused = coordinator.executeWithProgress(title: "Duplicate fixture", totalItems: 99) { callback in
            await rejected.run(callback)
        } completion: { _ in completions += 100 }
        try await first.waitUntilStarted()
        check(accepted && !refused && coordinator.taskProgress?.id == firstID && TaskProgressWindowController.shared.showCount == showCount + 1,
              "progress-refuses-overlapping-task", "A second progress task cannot replace the active task or its window.")
        check(await rejected.executions == 0 && coordinator.statusBanner?.tone == .warning,
              "progress-rejection-has-feedback", "Rejected work is never invoked and exposes a warning to the user.")
        await first.report(3, 10, "active-progress")
        try await waitUntil("active progress callback") { coordinator.taskProgress?.current == 3 }

        let source = root.appendingPathComponent("rename-while-other-task.txt")
        try Data("not-renamed".utf8).write(to: source)
        coordinator.openBatchRename(for: makeContext([source]))
        coordinator.updateBatchRenameDraft(token: "ShouldWait", numberingEnabled: false)
        coordinator.applyBatchRename()
        check(!coordinator.isApplyingBatchRename && coordinator.isPresentingBatchRename && coordinator.batchRenameContext != nil && coordinator.taskProgress?.id == firstID,
              "rename-rejection-does-not-stick-busy", "Rename remains editable when another progress operation owns execution.")
        coordinator.dismissBatchRename()
        check(FileManager.default.fileExists(atPath: source.path),
              "rename-rejected-before-file-work", "No rename occurs when global task admission rejects it.")

        await first.finish()
        try await waitUntil("first progress completion") { completions == 1 }
        let second = SuspendedOperation()
        let restarted = coordinator.executeWithProgress(title: "Next fixture", totalItems: 20) { callback in
            await second.run(callback)
        } completion: { _ in completions += 1 }
        try await second.waitUntilStarted()
        await second.report(4, 20, "new-task-progress")
        try await waitUntil("second progress callback") { coordinator.taskProgress?.current == 4 }
        let secondID = coordinator.taskProgress?.id
        await first.report(99, 99, "stale-progress")
        try await Task.sleep(for: .milliseconds(50))
        check(restarted && secondID != firstID && coordinator.taskProgress?.id == secondID && coordinator.taskProgress?.current == 4 && coordinator.taskProgress?.detail == "new-task-progress",
              "progress-ignores-late-callback", "A finished operation's callback cannot corrupt the next operation's progress.")
        await second.finish()
        try await waitUntil("second progress completion") { completions == 2 }
        check(coordinator.taskProgress?.isComplete == true,
              "progress-releases-admission-after-completion", "A new operation can start and finish after the first one completes.")
    }

    private static func desktopAIMenuVisibility(_ coordinator: AppCoordinator, root: URL) throws {
        let originalConfig = coordinator.persistenceState.aiConfig
        let custom = CustomAction(name: "AI switch custom fixture", actionType: .shellScript,
                                  scriptContent: "printf unused", fileExtensionFilter: ["png"])
        try coordinator.saveCustomAction(custom)
        defer {
            coordinator.deleteCustomAction(custom)
            _ = coordinator.saveAIConfig(originalConfig)
        }
        let context = makeContext([root.appendingPathComponent("menu-only-image.png")])
        let builder = DesktopBridgeMenuBuilder(coordinator: coordinator)
        let localTitles = Set(AIActionCatalog.all.filter {
            $0.id == AIActionCatalog.ocrExtract || $0.id == AIActionCatalog.removeBackground
        }.map(\.title))
        let remoteTitles = Set(AIActionCatalog.all.filter {
            $0.id != AIActionCatalog.ocrExtract && $0.id != AIActionCatalog.removeBackground
        }.map(\.title))

        var config = originalConfig
        config.isEnabled = false
        let disabledSaved = coordinator.saveAIConfig(config)
        let disabledTitles = Set(builder.makeMenu(for: context).items.map(\.title))
        check(disabledSaved && localTitles.isSubset(of: disabledTitles) && remoteTitles.isDisjoint(with: disabledTitles),
              "desktop-ai-disabled-preserves-local-actions", "Turning remote AI off hides smart rename and auto-tag while retaining local OCR and background removal.")

        config.isEnabled = true
        let enabledSaved = coordinator.saveAIConfig(config)
        let enabledTitles = Set(builder.makeMenu(for: context).items.map(\.title))
        check(enabledSaved && localTitles.union(remoteTitles).isSubset(of: enabledTitles),
              "desktop-ai-enabled-restores-remote-actions", "Turning remote AI on restores both remote actions alongside local image tools without executing AI.")
        check(disabledTitles.contains(custom.name) && enabledTitles.contains(custom.name),
              "desktop-ai-setting-preserves-custom-menu", "An eligible custom action remains available in both AI settings; the next checks execute its real routing path.")
    }

    private static func customActionRouting(_ coordinator: AppCoordinator, root: URL) async throws {
        let directory = root.appendingPathComponent("custom fixture 中文", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let sources = [directory.appendingPathComponent("first 中文.txt"), directory.appendingPathComponent("second file.txt")]
        for source in sources { try Data("untouched-input".utf8).write(to: source) }
        let output = directory.appendingPathComponent("custom-output.txt")
        var custom = CustomAction(name: "Functional custom route", actionType: .shellScript, scriptContent: """
        /bin/sleep 0.15
        printf '%s\n' "$FIRST_FILE" "$TARGET_DIR" "$SELECTED_FILES" >> "$TARGET_DIR/custom-output.txt"
        printf 'fixture-completed'
        """, fileExtensionFilter: ["txt"])
        try coordinator.saveCustomAction(custom)
        let context = makeContext(sources)
        let builder = DesktopBridgeMenuBuilder(coordinator: coordinator)
        let menu = builder.makeMenu(for: context)
        guard let item = menu.items.first(where: { $0.title == custom.name }) else {
            check(false, "custom-desktop-menu-item", "The enabled custom action is missing from the actual menu builder.")
            return
        }
        let historyCount = coordinator.persistenceState.actionHistory.count
        let shows = TaskProgressWindowController.shared.showCount
        builder.handleAction(item)
        let progressID = coordinator.taskProgress?.id
        builder.handleAction(item)
        coordinator.sampleContext = makeContext([root.appendingPathComponent("unrelated-selection.txt")])
        try await Task.sleep(for: .milliseconds(30))
        check(coordinator.taskProgress?.isComplete == false && coordinator.taskProgress?.id == progressID,
              "custom-subprocess-keeps-main-actor-responsive", "The main actor runs while the real shell fixture is still sleeping.")
        try await waitUntil("custom shell result") { coordinator.persistenceState.actionHistory.count == historyCount + 1 }
        let expected = [sources[0].path, directory.path, sources[0].path, sources[1].path].joined(separator: "\n") + "\n"
        check(try String(contentsOf: output, encoding: .utf8) == expected,
              "custom-desktop-route-executes-real-script", "The custom-UUID menu payload reaches the executor once with correct selected-file environment values.")
        check(TaskProgressWindowController.shared.showCount == shows + 1 && coordinator.persistenceState.actionHistory.first?.outcome == .success && coordinator.persistenceState.actionHistory.first?.context == context.snapshot,
              "custom-duplicate-is-rejected-context-is-frozen", "Two clicks create one successful invocation using the original selection.")

        custom.scriptContent = "printf 'fixture failure' >&2; exit 7"
        try coordinator.saveCustomAction(custom)
        coordinator.run(actionID: custom.toActionDefinition().id, context: context)
        try await waitUntil("custom failure record") { coordinator.persistenceState.actionHistory.count == historyCount + 2 }
        check(coordinator.persistenceState.actionHistory.first?.outcome == .failure && coordinator.taskProgress?.resultMessage?.contains("7") == true && coordinator.taskProgress?.resultMessage?.contains("fixture failure") == true,
              "custom-edited-script-reports-nonzero-exit", "Updated saved script content runs immediately and exposes exit code plus stderr.")

        coordinator.setCustomActionEnabled(custom, isEnabled: false)
        let disabledShows = TaskProgressWindowController.shared.showCount
        builder.handleAction(item)
        check(TaskProgressWindowController.shared.showCount == disabledShows && coordinator.statusBanner?.tone == .warning,
              "custom-stale-menu-refuses-disabled-action", "A menu constructed before disabling cannot execute the now-disabled action.")
        coordinator.setCustomActionEnabled(custom, isEnabled: true)
        coordinator.run(actionID: custom.toActionDefinition().id, context: makeContext([root.appendingPathComponent("wrong.md")]))
        check(TaskProgressWindowController.shared.showCount == disabledShows && coordinator.statusBanner?.tone == .warning,
              "custom-rechecks-selection-conditions", "An extension mismatch is rejected before launching any script.")
        coordinator.deleteCustomAction(custom)
        builder.handleAction(item)
        check(TaskProgressWindowController.shared.showCount == disabledShows && coordinator.statusBanner?.tone == .warning,
              "custom-stale-menu-refuses-deleted-action", "Deleting an action invalidates its previously constructed menu item.")
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix("SuperRClickAction-") }
        check(leftovers.isEmpty, "custom-cleans-temporary-script-and-output", "Both successful and failed processes clean up their temporary execution files.")
    }

    private static func customExecutorFailurePaths(root: URL) async throws {
        let source = root.appendingPathComponent("executor-source.txt")
        try Data("fixture".utf8).write(to: source)
        let context = makeContext([source])
        let executor = CustomActionExecutor(temporaryDirectory: root)

        let arithmetic = CustomAction(name: "Pure arithmetic", actionType: .appleScript, scriptContent: "return 40 + 2")
        let arithmeticResult = await executor.execute(arithmetic, context: context)
        check(arithmeticResult == .completed(message: "42"),
              "custom-applescript-local-arithmetic", "The actual osascript process returns 42 without sending Apple Events to another application.")

        let verbose = CustomAction(name: "Verbose output", actionType: .shellScript, scriptContent: "printf '%020000d' 0")
        let verboseResult = await executor.execute(verbose, context: context)
        if case let .completed(message) = verboseResult {
            check(message?.count == 16_384 && message?.allSatisfy(\.isNumber) == true,
                  "custom-large-output-completes-with-bounded-message", "A real 20 KB stdout stream completes without pipe deadlock and is capped for display.")
        } else {
            check(false, "custom-large-output-completes-with-bounded-message", String(describing: verboseResult))
        }

        let missingDirectory = makeContext([root.appendingPathComponent("does-not-exist/file.txt")])
        let launchFailure = await executor.execute(verbose, context: missingDirectory)
        if case .failed = launchFailure {
            check(true, "custom-process-start-failure-is-recoverable", "An absent working directory returns failure instead of hanging the continuation.")
        } else {
            check(false, "custom-process-start-failure-is-recoverable", String(describing: launchFailure))
        }

        let missingApp = CustomAction(name: "Missing fixture application", actionType: .openApplication,
                                      scriptContent: "com.superrclick.functional.nonexistent.\(UUID().uuidString)")
        let missingAppResult = await executor.execute(missingApp, context: context)
        if case .failed = missingAppResult {
            check(true, "custom-missing-application-reports-failure", "A random nonexistent bundle identifier produces an explicit error; no app is opened.")
        } else {
            check(false, "custom-missing-application-reports-failure", String(describing: missingAppResult))
        }
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasPrefix("SuperRClickAction-") }
        check(leftovers.isEmpty, "custom-error-paths-clean-execution-files", "Launch failures and nonzero process exits also remove temporary scripts and output.")
    }

    private static func successfulRenameAndGuards(_ coordinator: AppCoordinator, root: URL) async throws {
        let directory = root.appendingPathComponent("rename-success", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let names = ["alpha.txt", "two words.md", "中文文件.txt"]
        let sources = names.map { directory.appendingPathComponent($0) }
        for (index, source) in sources.enumerated() {
            try Data("payload-\(index)".utf8).write(to: source)
        }
        coordinator.openBatchRename(for: makeContext(sources))
        coordinator.updateBatchRenameDraft(token: "Checked", numberingEnabled: false, separator: "-")
        let originalDraft = coordinator.batchRenameDraft
        let originalContext = coordinator.batchRenameContext
        let historyCount = coordinator.persistenceState.actionHistory.count
        let showCount = TaskProgressWindowController.shared.showCount

        coordinator.applyBatchRename()
        let firstProgressID = coordinator.taskProgress?.id
        check(coordinator.isApplyingBatchRename, "rename-starts-synchronously", "The busy guard is set before execution yields.")
        coordinator.applyBatchRename()
        coordinator.dismissBatchRename()
        coordinator.updateBatchRenameDraft(token: "Unwanted")
        var replacement = originalDraft
        replacement.token = "AlsoUnwanted"
        coordinator.updateBatchRenameDraft(replacement)
        coordinator.openBatchRename(for: makeContext([root.appendingPathComponent("other.txt")]))
        check(coordinator.isApplyingBatchRename && coordinator.isPresentingBatchRename,
              "rename-refuses-cancel", "Cancel cannot clear an operation that is still running.")
        check(coordinator.batchRenameDraft == originalDraft && coordinator.batchRenameContext == originalContext,
              "rename-freezes-draft-context", "Both edit APIs and another open request preserve the active inputs.")
        check(coordinator.taskProgress?.id == firstProgressID && TaskProgressWindowController.shared.showCount == showCount + 1,
              "rename-refuses-duplicate-apply", "Two immediate Apply calls start one execution/progress session.")

        try await waitUntil("successful rename") { !coordinator.isApplyingBatchRename }
        let destinationNames = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
        check(destinationNames == names.map { "Checked-" + $0 }.sorted(),
              "rename-real-files-once", "Only the three intended final filenames exist, including spaces and Unicode.")
        var contentsPreserved = true
        for (index, name) in names.enumerated() {
            let data = try Data(contentsOf: directory.appendingPathComponent("Checked-" + name))
            contentsPreserved = contentsPreserved && data == Data("payload-\(index)".utf8)
        }
        check(contentsPreserved, "rename-preserves-content", "All renamed files retain their original bytes.")
        check(coordinator.persistenceState.actionHistory.count == historyCount + 1 && coordinator.persistenceState.actionHistory.first?.outcome == .success,
              "rename-single-success-record", "Duplicate Apply produces exactly one successful history entry.")
        check(!coordinator.isPresentingBatchRename && coordinator.batchRenameContext == nil && coordinator.batchRenamePlan == nil,
              "rename-completes-and-cleans-up", "Success releases busy state and dismisses the completed draft.")
        coordinator.applyBatchRename()
        check(TaskProgressWindowController.shared.showCount == showCount + 1,
              "rename-ignores-apply-after-completion", "A stale Apply after completion cannot repeat the operation.")
    }

    private static func cancellationBeforeApply(_ coordinator: AppCoordinator, root: URL) throws {
        let source = root.appendingPathComponent("cancel-original.txt")
        try Data("untouched".utf8).write(to: source)
        let historyCount = coordinator.persistenceState.actionHistory.count
        coordinator.openBatchRename(for: makeContext([source]))
        coordinator.updateBatchRenameDraft(token: "Cancelled", numberingEnabled: false)
        coordinator.dismissBatchRename()
        check(try Data(contentsOf: source) == Data("untouched".utf8) && coordinator.persistenceState.actionHistory.count == historyCount && !coordinator.isPresentingBatchRename,
              "rename-cancel-before-apply", "Cancelling a preview leaves its file and history untouched.")
    }

    private static func blockedConflict(_ coordinator: AppCoordinator, root: URL) throws {
        let directory = root.appendingPathComponent("rename-conflict", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let source = directory.appendingPathComponent("source.txt")
        let destination = directory.appendingPathComponent("Checked-source.txt")
        try Data("source".utf8).write(to: source)
        try Data("existing".utf8).write(to: destination)
        coordinator.openBatchRename(for: makeContext([source]))
        coordinator.updateBatchRenameDraft(token: "Checked", numberingEnabled: false, separator: "-")
        let showCount = TaskProgressWindowController.shared.showCount
        coordinator.applyBatchRename()
        check(coordinator.batchRenamePlan?.canApply == false && !coordinator.isApplyingBatchRename && TaskProgressWindowController.shared.showCount == showCount,
              "rename-blocks-conflicting-plan", "Coordinator refuses an existing target before executing.")
        let originalBytes = try Data(contentsOf: source)
        let destinationBytes = try Data(contentsOf: destination)
        check(originalBytes == Data("source".utf8) && destinationBytes == Data("existing".utf8),
              "rename-conflict-preserves-both-files", "Conflict handling does not overwrite either file.")
        coordinator.dismissBatchRename()
    }

    private static func recoverableRenameFailure(_ coordinator: AppCoordinator, root: URL) async throws {
        let source = root.appendingPathComponent("missing-after-preview.txt")
        try Data("temporary".utf8).write(to: source)
        coordinator.openBatchRename(for: makeContext([source]))
        coordinator.updateBatchRenameDraft(token: "Checked", numberingEnabled: false)
        let originalDraft = coordinator.batchRenameDraft
        try FileManager.default.removeItem(at: source)
        coordinator.applyBatchRename()
        try await waitUntil("failed rename") { !coordinator.isApplyingBatchRename }
        check(coordinator.taskProgress?.isComplete == true && coordinator.taskProgress?.isSuccess == false && coordinator.persistenceState.actionHistory.first?.outcome == .failure,
              "rename-reports-filesystem-failure", "A source removed after preview produces a real failed result and history entry.")
        check(coordinator.isPresentingBatchRename && coordinator.batchRenameDraft == originalDraft && coordinator.batchRenameContext != nil,
              "rename-failure-keeps-draft", "Failure restores edit/cancel availability without silently discarding the draft.")
        coordinator.dismissBatchRename()
        check(!coordinator.isPresentingBatchRename && coordinator.batchRenameContext == nil,
              "rename-cancel-after-failure", "Cancel works again after the operation has finished.")
    }

    private static func aiPersistence(_ coordinator: AppCoordinator, controller: PersistenceController, root: URL) throws {
        let saved = coordinator.persistenceState.aiConfig
        var draft = saved
        draft.isEnabled.toggle()
        draft.model = "functional-draft-model"
        coordinator.togglePinned(BuiltInActionCatalog.copyFullPath)
        check(try controller.loadState().aiConfig == saved && coordinator.persistenceState.aiConfig == saved,
              "ai-draft-does-not-leak-to-unrelated-save", "A local draft is not included in the real pin persistence path.")
        check(coordinator.saveAIConfig(draft), "ai-save-returns-success", "Explicit AI save reports its actual disk write result.")
        check(try controller.loadState().aiConfig == draft && coordinator.persistenceState.aiConfig == draft,
              "ai-save-updates-disk-and-memory", "Explicitly saving a disabled AI configuration updates both representations.")

        let beforeFailure = coordinator.persistenceState
        draft.model = "retry-this-unsaved-model"
        let retryDraft = draft
        let backup = root.appendingPathComponent("state-before-write-failure.json")
        try FileManager.default.moveItem(at: controller.stateFileURL, to: backup)
        try FileManager.default.createDirectory(at: controller.stateFileURL, withIntermediateDirectories: false)
        defer {
            try? FileManager.default.removeItem(at: controller.stateFileURL)
            try? FileManager.default.moveItem(at: backup, to: controller.stateFileURL)
        }
        check(!coordinator.saveAIConfig(draft), "ai-save-reports-write-failure", "A directory occupying the state-file path causes a real atomic write failure.")
        check(coordinator.persistenceState == beforeFailure && draft == retryDraft && coordinator.statusBanner?.tone == .error,
              "ai-failure-keeps-saved-state-and-draft", "Failed saving cannot mutate shared settings and leaves the retry value intact.")
        let backupData = try Data(contentsOf: backup)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        check(try decoder.decode(PersistenceState.self, from: backupData).aiConfig == beforeFailure.aiConfig,
              "ai-failure-preserves-last-saved-config", "The previous persisted configuration remains intact during write failure.")
    }
}
