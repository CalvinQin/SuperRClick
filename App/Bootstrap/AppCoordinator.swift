import AppKit
import Foundation
import Observation
import Shared
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class AppCoordinator {
    enum SetupCapabilityStatus {
        case ready
        case actionRequired
        case planned
    }

    struct ActionSectionSnapshot: Identifiable {
        let section: ActionSection
        let actions: [ActionDefinition]

        var id: ActionSection { section }
    }

    struct StatusBanner: Identifiable {
        enum Tone {
            case info
            case success
            case warning
            case error
        }

        let id = UUID()
        let tone: Tone
        let title: String
        let detail: String?

        var color: Color {
            switch tone {
            case .info:
                .blue
            case .success:
                .green
            case .warning:
                .orange
            case .error:
                .red
            }
        }

        var iconName: String {
            switch tone {
            case .info:
                "info.circle.fill"
            case .success:
                "checkmark.circle.fill"
            case .warning:
                "exclamationmark.triangle.fill"
            case .error:
                "xmark.octagon.fill"
            }
        }
    }

    private enum Constants {
        static let appGroupID = "group.com.haoqiqin.superrclick"
        static let batchRenameDemoFolderName = "Batch Rename Demo"
        static let setupCompletedDefaultsKey = "setup.completed"
        static let finderExtensionBundleIdentifier = "com.haoqiqin.SuperRClick.FinderSync"
    }

    @ObservationIgnored private let actionEngine: ActionEngine
    @ObservationIgnored private let appGroupContainer: AppGroupContainer
    @ObservationIgnored private let externalCommandCenter: Shared.ExternalCommandCenter
    @ObservationIgnored private let platformExecutor: PlatformActionExecutor
    @ObservationIgnored private var externalCommandObserver: NSObjectProtocol?
    @ObservationIgnored private var activeExternalSecurityScopedURLs: [URL] = []
    @ObservationIgnored private var handledExternalRequestIDs: Set<UUID> = []

    var sampleContext: ActionContext
    var actionSections: [ActionSectionSnapshot] = []
    var allDefinitions: [ActionDefinition] = []
    var pinnedActions: [ActionDefinition] = []
    var recentHistory: [ActionInvocationRecord] = []
    var persistenceState = PersistenceState()
    var statusBanner: StatusBanner?
    var isReady = false
    var hasCompletedSetup = UserDefaults.standard.bool(forKey: Constants.setupCompletedDefaultsKey)
    var isPresentingSetupCenter = false
    var isRefreshingSetupStatus = false
    var finderExtensionStatus: SetupCapabilityStatus = .actionRequired
    var finderExtensionDetail = L("Super RClick 尚未确认 Finder 扩展是否可用。", "Super RClick has not yet confirmed whether the Finder extension is available.")
    var lastSetupRefreshAt: Date?
    var isPresentingBatchRename = false
    var isApplyingBatchRename = false
    var queuedExternalResolvedCommand: ResolvedExternalCommand?
    var batchRenameDraft = BatchRenameDraft(
        mode: .prefix,
        token: "Renamed",
        numbering: BatchRenameNumberingOptions(isEnabled: true, start: 1, step: 1, padding: 2, separator: "-"),
        preserveFileExtension: true,
        items: []
    )
    var batchRenamePlan: BatchRenamePlan?
    var batchRenameContext: ActionContext?
    
    @ObservationIgnored private var currentDesktopMenuBuilder: DesktopBridgeMenuBuilder?

    init(
        actionEngine: ActionEngine = ActionEngine(),
        appGroupContainer: AppGroupContainer = AppGroupContainer(groupIdentifier: Constants.appGroupID),
        platformExecutor: PlatformActionExecutor = PlatformActionExecutor()
    ) {
        self.actionEngine = actionEngine
        self.appGroupContainer = appGroupContainer
        self.externalCommandCenter = appGroupContainer.makeExternalCommandCenter()
        self.platformExecutor = platformExecutor
        self.sampleContext = AppCoordinator.makeDefaultContext()

        Task {
            await bootstrap()
        }
    }

    var totalAvailableActions: Int {
        actionSections.reduce(into: 0) { partialResult, section in
            partialResult += section.actions.count
        }
    }

    var monitoredFolders: [MonitoredFolder] {
        persistenceState.monitoredFolders.sorted(by: AppCoordinator.monitoredFolderSort)
    }

    var enabledMonitoredFolders: [MonitoredFolder] {
        monitoredFolders.filter(\.isEnabled)
    }

    var canCompleteSetup: Bool {
        finderExtensionStatus == .ready && !enabledMonitoredFolders.isEmpty
    }

    var setupOutstandingCount: Int {
        var pending = 0
        if finderExtensionStatus != .ready {
            pending += 1
        }
        if enabledMonitoredFolders.isEmpty {
            pending += 1
        }
        return pending
    }

    func setupDesktopBridge() {
        DesktopBridgeManager.shared.onDesktopRightClick = { [weak self] point in
            guard let self = self else { return }
            self.showDesktopMenu(at: point)
        }
    }
    
    func showDesktopMenu(at point: CGPoint) {
        let urls = DesktopSelectionProvider.getSelectedFileURLs()
        
        let contextItems: [ActionItem]
        if urls.isEmpty {
            let desktopURL = RealUserDirectories.desktop()
            contextItems = [ActionItem(url: desktopURL, displayName: "Desktop", contentTypeIdentifier: nil, isDirectory: true)]
        } else {
            contextItems = urls.map { url in
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                return ActionItem(url: url, displayName: url.lastPathComponent, contentTypeIdentifier: nil, isDirectory: isDirectory.boolValue)
            }
        }
        
        let context = ActionContext.finderSelection(contextItems, sourceApplicationBundleIdentifier: "com.apple.finder")
        
        let builder = DesktopBridgeMenuBuilder(coordinator: self)
        self.currentDesktopMenuBuilder = builder
        let menu = builder.makeMenu(for: context)
        
        // Use popUp(positioning:at:in:) — no temporary window needed
        let screenPoint = NSPoint(x: point.x, y: point.y)
        menu.popUp(positioning: nil, at: screenPoint, in: nil)
    }

    func refresh() {
        Task {
            await refreshModel()
            statusBanner = StatusBanner(
                tone: .info,
                title: "Refreshed action catalog",
                detail: "The app reloaded visibility rules, monitored folders, pinned actions, and recent history."
            )
        }
    }

    func presentSetupCenter() {
        isPresentingSetupCenter = true
        refreshSetupStatus()
    }

    func refreshSetupStatus() {
        guard !isRefreshingSetupStatus else {
            return
        }

        isRefreshingSetupStatus = true

        Task {
            let status = await Task.detached(priority: .userInitiated) {
                Self.detectFinderExtensionStatus()
            }.value

            finderExtensionStatus = status.isEnabled ? .ready : .actionRequired
            finderExtensionDetail = status.detail
            lastSetupRefreshAt = Date()
            isRefreshingSetupStatus = false
        }
    }

    func openFinderExtensionsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
            return
        }

        if let legacyURL = URL(string: "x-apple.systempreferences:com.apple.preferences.extensions") {
            NSWorkspace.shared.open(legacyURL)
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openInputMonitoringSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func run(_ action: ActionDefinition) {
        if action.id == BuiltInActionCatalog.batchRename.id {
            openBatchRename(for: sampleContext)
            return
        }

        if action.id == BuiltInActionCatalog.convertImage.id {
            runImageConversionWithFormatPicker()
            return
        }

        Task {
            let result = await actionEngine.execute(actionID: action.id, context: sampleContext)
            await persistInvocation(for: action, result: result, context: sampleContext)
            await refreshModel()
            statusBanner = AppCoordinator.statusBanner(for: action, result: result)
        }
    }

    func runImageConversionWithFormatPicker() {
        let formats = ["png", "jpeg", "webp", "tiff", "heic"]

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("选择目标格式", "Choose Target Format")
        alert.informativeText = L("请选择图片转换的目标格式。转换后的文件将保存到原目录。", "Select the target format for image conversion. Converted files will be saved to the original directory.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("转换", "Convert"))
        alert.addButton(withTitle: L("取消", "Cancel"))

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 200, height: 28))
        for fmt in formats {
            popup.addItem(withTitle: fmt.uppercased())
        }
        alert.accessoryView = popup

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let selectedFormat = formats[popup.indexOfSelectedItem]

        var enrichedContext = sampleContext
        enrichedContext = ActionContext.finderSelection(
            sampleContext.items,
            sourceApplicationBundleIdentifier: sampleContext.sourceApplicationBundleIdentifier,
            workspaceIdentifier: sampleContext.workspaceIdentifier,
            metadata: sampleContext.metadata.merging(["convertImage.format": selectedFormat]) { _, new in new }
        )

        guard let action = BuiltInActionCatalog.definition(for: BuiltInActionCatalog.convertImage.id) else { return }

        Task {
            let result = await actionEngine.execute(actionID: action.id, context: enrichedContext)
            await persistInvocation(for: action, result: result, context: enrichedContext)
            await refreshModel()
            statusBanner = AppCoordinator.statusBanner(for: action, result: result)
        }
    }

    // MARK: - Toolbox Actions (with file pickers)

    func runImageConversionFromToolbox() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = L("选择要转换的图片", "Select images to convert")
        panel.prompt = L("选择", "Select")
        panel.message = L("请选择一个或多个图片文件进行格式转换。", "Select one or more image files to convert.")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .webP, .image]

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        let items = panel.urls.map { url in
            ActionItem(url: url, displayName: url.lastPathComponent, contentTypeIdentifier: nil, isDirectory: false)
        }
        sampleContext = ActionContext.finderSelection(items, sourceApplicationBundleIdentifier: "com.haoqiqin.SuperRClick")

        runImageConversionWithFormatPicker()
    }

    func runCompressFromToolbox() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = L("选择要压缩的文件", "Select files to compress")
        panel.prompt = L("选择", "Select")
        panel.message = L("请选择一个或多个文件/文件夹进行压缩。", "Select one or more files or folders to compress.")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        let items = panel.urls.map { url in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            return ActionItem(url: url, displayName: url.lastPathComponent, contentTypeIdentifier: nil, isDirectory: isDir.boolValue)
        }
        let context = ActionContext.finderSelection(items, sourceApplicationBundleIdentifier: "com.haoqiqin.SuperRClick")

        guard let action = BuiltInActionCatalog.definition(for: BuiltInActionCatalog.compressItems.id) else { return }

        Task {
            let result = await actionEngine.execute(actionID: action.id, context: context)
            await persistInvocation(for: action, result: result, context: context)
            await refreshModel()
            statusBanner = AppCoordinator.statusBanner(for: action, result: result)
        }
    }

    func runOpenTerminalFromToolbox() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = L("选择要在终端打开的文件夹", "Select folder to open in Terminal")
        panel.prompt = L("选择", "Select")
        panel.message = L("请选择一个文件夹，将在该目录打开终端。", "Select a folder to open Terminal in that directory.")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let items = [ActionItem(url: url, displayName: url.lastPathComponent, contentTypeIdentifier: nil, isDirectory: true)]
        let context = ActionContext.finderSelection(items, sourceApplicationBundleIdentifier: "com.haoqiqin.SuperRClick")

        guard let action = BuiltInActionCatalog.definition(for: BuiltInActionCatalog.openTerminalHere.id) else { return }

        Task {
            let result = await actionEngine.execute(actionID: action.id, context: context)
            await persistInvocation(for: action, result: result, context: context)
            await refreshModel()
            statusBanner = AppCoordinator.statusBanner(for: action, result: result)
        }
    }

    func togglePinned(_ action: ActionDefinition) {
        if let index = persistenceState.pinnedActions.firstIndex(where: { $0.actionID == action.id }) {
            persistenceState.pinnedActions.remove(at: index)
        } else {
            let nextOrder = (persistenceState.pinnedActions.map(\.order).max() ?? -1) + 1
            persistenceState.pinnedActions.append(
                PinnedAction(actionID: action.id, order: nextOrder, isFavorite: true)
            )
        }

        persistState()

        Task {
            await refreshModel()
        }
    }

    func isPinned(_ action: ActionDefinition) -> Bool {
        persistenceState.pinnedActions.contains(where: { $0.actionID == action.id })
    }

    func openBatchRename(for context: ActionContext? = nil) {
        releaseActiveExternalSecurityScopes()

        // If context has real file items, use them directly
        if let context, !context.items.isEmpty,
           !context.isFinderDesktopSurface,
           context.finderSurface != .container {
            batchRenameContext = context
            batchRenameDraft = BatchRenameDraft(context: context)
            if batchRenameDraft.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                batchRenameDraft.token = "Renamed"
            }
            recalculateBatchRenamePlan()
            isPresentingBatchRename = true
            showBatchRenamePanel()
            return
        }

        // No real Finder selection — prompt user to pick files
        promptFilesForBatchRename()
    }

    private func promptFilesForBatchRename() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.title = L("选择要批量重命名的文件", "Select files to batch rename")
        panel.prompt = L("选择", "Select")
        panel.message = L("请选择一个或多个文件/文件夹进行批量重命名。", "Select one or more files or folders to batch rename.")
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false

        guard panel.runModal() == .OK, !panel.urls.isEmpty else {
            return
        }

        let items = panel.urls.map { url in
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            return ActionItem(
                url: url,
                displayName: url.lastPathComponent,
                contentTypeIdentifier: nil,
                isDirectory: isDir.boolValue
            )
        }

        let resolvedContext = ActionContext.finderSelection(
            items,
            sourceApplicationBundleIdentifier: "com.haoqiqin.SuperRClick"
        )
        batchRenameContext = resolvedContext
        batchRenameDraft = BatchRenameDraft(context: resolvedContext)
        if batchRenameDraft.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            batchRenameDraft.token = "Renamed"
        }
        recalculateBatchRenamePlan()
        isPresentingBatchRename = true
        showBatchRenamePanel()
    }

    func ensureExternalCommandMonitoring() async {
        guard externalCommandObserver == nil else {
            NSLog("[SuperRClick] ensureExternalCommandMonitoring: observer already exists, skipping")
            return
        }

        NSLog("[SuperRClick] ensureExternalCommandMonitoring: setting up DistributedNotification observer")
        externalCommandObserver = DistributedNotificationCenter.default().addObserver(
            forName: Shared.ExternalCommandCenter.notificationName,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            NSLog("[SuperRClick] DistributedNotification RECEIVED — calling consumePendingExternalCommands")
            Task { @MainActor in
                await self?.consumePendingExternalCommands()
            }
        }

        NSLog("[SuperRClick] ensureExternalCommandMonitoring: checking for any pending commands on startup")
        await consumePendingExternalCommands()
    }

    func dismissBatchRename() {
        isPresentingBatchRename = false
        isApplyingBatchRename = false
        batchRenameContext = nil
        batchRenamePlan = nil
        closeBatchRenamePanel()
        releaseActiveExternalSecurityScopes()

        if let queuedResolvedCommand = queuedExternalResolvedCommand {
            self.queuedExternalResolvedCommand = nil

            Task { @MainActor in
                self.presentExternalBatchRename(queuedResolvedCommand)
            }
        }
    }

    func updateBatchRenameDraft(
        mode: BatchRenameMode? = nil,
        token: String? = nil,
        numberingEnabled: Bool? = nil,
        numberingStart: Int? = nil,
        numberingPadding: Int? = nil,
        preserveFileExtension: Bool? = nil,
        separator: String? = nil
    ) {
        if let mode {
            batchRenameDraft.mode = mode
        }
        if let token {
            batchRenameDraft.token = token
        }
        if let numberingEnabled {
            batchRenameDraft.numbering.isEnabled = numberingEnabled
        }
        if let numberingStart {
            batchRenameDraft.numbering.start = max(1, numberingStart)
        }
        if let numberingPadding {
            batchRenameDraft.numbering.padding = max(0, numberingPadding)
        }
        if let preserveFileExtension {
            batchRenameDraft.preserveFileExtension = preserveFileExtension
        }
        if let separator {
            batchRenameDraft.numbering.separator = separator
        }

        recalculateBatchRenamePlan()
    }

    func updateBatchRenameDraft(_ draft: BatchRenameDraft) {
        batchRenameDraft = draft
        recalculateBatchRenamePlan()
    }

    func applyBatchRename() {
        guard let context = batchRenameContext,
              let plan = batchRenamePlan,
              let action = BuiltInActionCatalog.definition(for: BuiltInActionCatalog.batchRename.id) else {
            return
        }

        isApplyingBatchRename = true

        Task {
            let result = await platformExecutor.applyBatchRename(plan: plan)
            await persistInvocation(for: action, result: result, context: context)
            await refreshModel()

            isApplyingBatchRename = false
            statusBanner = AppCoordinator.statusBanner(for: action, result: result)

            if case .completed = result {
                dismissBatchRename()
            }
        }
    }

    func presentBatchRename(with draft: BatchRenameDraft? = nil) {
        if let draft {
            releaseActiveExternalSecurityScopes()
            batchRenameContext = ActionContext.finderSelection(
                draft.items.map {
                    ActionItem(
                        url: $0.url,
                        displayName: $0.displayName,
                        contentTypeIdentifier: nil,
                        isDirectory: $0.isDirectory
                    )
                },
                sourceApplicationBundleIdentifier: "com.haoqiqin.SuperRClick"
            )
            batchRenameDraft = draft
            recalculateBatchRenamePlan()
            isPresentingBatchRename = true
            return
        }

        promptFilesForBatchRename()
    }

    func consumePendingExternalCommands() async {
        NSLog("[SuperRClick] consumePendingExternalCommands: ENTER")
        do {
            let storageDir = try appGroupContainer.resolveDirectory()
            let filePath = storageDir.appendingPathComponent("pending-external-command.json").path
            NSLog("[SuperRClick] consumePendingExternalCommands: looking for file at %@, exists=%d", filePath, FileManager.default.fileExists(atPath: filePath))

            guard let request = try externalCommandCenter.consumePendingRequest() else {
                NSLog("[SuperRClick] consumePendingExternalCommands: no pending request found")
                return
            }

            NSLog("[SuperRClick] consumePendingExternalCommands: found request id=%@ kind=%@ items=%d", request.id.uuidString, request.kind.rawValue, request.items.count)

            let resolvedCommand = try externalCommandCenter.resolveBatchRenameRequest(request)
            NSLog("[SuperRClick] consumePendingExternalCommands: resolved command, context items=%d", resolvedCommand.context.items.count)
            handleExternalBatchRenameRequest(resolvedCommand)
        } catch {
            let errorMsg = error.localizedDescription
            NSLog("[SuperRClick] consumePendingExternalCommands: ERROR — %@", errorMsg)
            statusBanner = StatusBanner(
                tone: .warning,
                title: "Could not open pending Finder selection",
                detail: errorMsg
            )
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Failed to open Finder selection"
            alert.informativeText = errorMsg
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    func promptForMonitoredFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.prompt = "Add Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.message = "Choose a folder that Super RClick should monitor in Finder and on the Desktop."

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        addMonitoredFolder(url)
    }

    func addMonitoredFolder(_ url: URL) {
        let canonicalURL = canonicalized(url)
        guard !isMonitoredFolder(canonicalURL) else {
            statusBanner = StatusBanner(
                tone: .info,
                title: "Folder already covered",
                detail: "\(displayName(for: canonicalURL)) is already monitored."
            )
            return
        }

        let preset = AppCoordinator.preset(for: canonicalURL)
        let folder = MonitoredFolder(
            name: displayName(for: canonicalURL),
            url: canonicalURL,
            preset: preset
        )

        persistenceState.monitoredFolders.append(folder)

        if !persistenceState.workspaceProfiles.contains(where: {
            canonicalPath($0.rootURL) == canonicalPath(canonicalURL)
        }) {
            persistenceState.workspaceProfiles.append(
                WorkspaceProfile(
                    name: folder.name,
                    rootURL: canonicalURL,
                    pinnedActionIDs: AppCoordinator.recommendedActionIDs(for: preset)
                )
            )
        }

        persistConfigurationState(
            title: "Added monitored folder",
            detail: "\(folder.name) is now included in Finder and Desktop coverage."
        )
    }

    func removeMonitoredFolder(_ url: URL) {
        let canonicalURL = canonicalized(url)
        let canonicalTarget = canonicalPath(canonicalURL)

        persistenceState.monitoredFolders.removeAll { canonicalPath($0.url) == canonicalTarget }
        persistenceState.workspaceProfiles.removeAll { canonicalPath($0.rootURL) == canonicalTarget }

        persistConfigurationState(
            title: "Removed monitored folder",
            detail: "\(displayName(for: canonicalURL)) will no longer appear in Finder Sync coverage."
        )
    }

    func isMonitoredFolder(_ url: URL) -> Bool {
        let target = canonicalPath(url)
        return persistenceState.monitoredFolders.contains { canonicalPath($0.url) == target }
    }

    func isActionHidden(_ action: ActionDefinition) -> Bool {
        persistenceState.visibilityRules.contains(where: {
            $0.actionID == action.id && $0.mode == .exclude
        })
    }

    func setActionHidden(_ action: ActionDefinition, isHidden: Bool) {
        persistenceState.visibilityRules.removeAll(where: { $0.actionID == action.id })

        if isHidden {
            persistenceState.visibilityRules.append(
                VisibilityRule(
                    actionID: action.id,
                    mode: .exclude,
                    allowedContextKinds: [.finderSelection, .mixedSelection]
                )
            )
        }

        persistState()

        Task {
            await actionEngine.setVisibilityRules(persistenceState.visibilityRules)
            await refreshModel()
        }
    }

    // MARK: - Custom Actions

    func addCustomAction(_ action: CustomAction) {
        persistenceState.customActions.append(action)
        persistState()

        statusBanner = StatusBanner(
            tone: .success,
            title: L("已创建自定义动作", "Custom action created"),
            detail: action.name
        )

        Task {
            await refreshModel()
        }
    }

    func deleteCustomAction(_ action: CustomAction) {
        persistenceState.customActions.removeAll(where: { $0.id == action.id })
        persistState()

        Task {
            await refreshModel()
        }
    }

    // MARK: - Monitored Folder Toggle

    func toggleMonitoredFolder(_ folder: MonitoredFolder) {
        if let index = persistenceState.monitoredFolders.firstIndex(where: { $0.id == folder.id }) {
            persistenceState.monitoredFolders[index].isEnabled.toggle()
            persistState()
        }
    }

    // MARK: - History

    func clearHistory() {
        persistenceState.actionHistory.removeAll()
        persistState()

        Task {
            await refreshModel()
        }
    }

    private func bootstrap() async {
        do {
            let controller = try appGroupContainer.makePersistenceController()
            persistenceState = controller.loadOrCreateState()
            var didSeedDefaults = false

            let migratedState = migrateBuiltInFolderPaths(in: persistenceState)
            if migratedState != persistenceState {
                persistenceState = migratedState
                didSeedDefaults = true
            }

            if persistenceState.pinnedActions.isEmpty {
                persistenceState.pinnedActions = defaultPinnedActions()
                didSeedDefaults = true
            }

            if persistenceState.monitoredFolders.isEmpty {
                persistenceState.monitoredFolders = defaultMonitoredFolders(
                    from: persistenceState.workspaceProfiles
                )
                didSeedDefaults = true
            }

            let monitoredFoldersWithHome = ensureHomeMonitoredFolder(in: persistenceState.monitoredFolders)
            if monitoredFoldersWithHome != persistenceState.monitoredFolders {
                persistenceState.monitoredFolders = monitoredFoldersWithHome
                didSeedDefaults = true
            }

            let synchronizedProfiles = synchronizeWorkspaceProfiles(
                existingProfiles: persistenceState.workspaceProfiles,
                monitoredFolders: persistenceState.monitoredFolders
            )
            if synchronizedProfiles != persistenceState.workspaceProfiles {
                persistenceState.workspaceProfiles = synchronizedProfiles
                didSeedDefaults = true
            }

            if didSeedDefaults {
                try controller.saveState(persistenceState)
            }
        } catch {
            statusBanner = StatusBanner(
                tone: .warning,
                title: "Using fallback persistence",
                detail: error.localizedDescription
            )
            persistenceState.pinnedActions = defaultPinnedActions()
            persistenceState.monitoredFolders = defaultMonitoredFolders()
            persistenceState.workspaceProfiles = synchronizeWorkspaceProfiles(
                existingProfiles: persistenceState.workspaceProfiles,
                monitoredFolders: persistenceState.monitoredFolders
            )
        }

        await registerPlatformHandlers()
        await actionEngine.setVisibilityRules(persistenceState.visibilityRules)
        await refreshModel()
        await ensureExternalCommandMonitoring()
        await consumePendingExternalCommands()
        refreshSetupStatus()
        setupDesktopBridge()
        isReady = true
    }

    private func registerPlatformHandlers() async {
        for definition in BuiltInActionCatalog.all {
            let actionID = definition.id
            await actionEngine.registerHandler(for: actionID) { [platformExecutor] context in
                await platformExecutor.execute(actionID: actionID, context: context)
            }
        }
        
        for definition in NewFileCatalog.all {
            let actionID = definition.id
            await actionEngine.registerHandler(for: actionID) { [platformExecutor] context in
                await platformExecutor.execute(actionID: actionID, context: context)
            }
        }
    }

    private func refreshModel() async {
        // Reload definitions so language changes take effect
        await actionEngine.reloadDefinitions()
        allDefinitions = await actionEngine.allDefinitions() + NewFileCatalog.all
        
        var combinedSections = await actionEngine.groupedAvailableActions(for: sampleContext).map { group in
            let filteredActions = group.actions.filter { action in
                !(sampleContext.isFinderDesktopSurface && action.id == BuiltInActionCatalog.batchRename.id)
            }
            return ActionSectionSnapshot(section: group.section, actions: filteredActions)
        }
        
        // Add new file section manually since it's not in ActionEngine defaults
        let newFileSnapshot = ActionSectionSnapshot(section: .newFile, actions: NewFileCatalog.all)
        combinedSections.append(newFileSnapshot)
        combinedSections.sort { $0.section < $1.section }
        
        actionSections = combinedSections.filter { !$0.actions.isEmpty }

        let definitionsByID = Dictionary(uniqueKeysWithValues: allDefinitions.map { ($0.id, $0) })
        pinnedActions = persistenceState.pinnedActions
            .sorted(by: { $0.order < $1.order })
            .compactMap { definitionsByID[$0.actionID] }
            .filter { definition in
                !(sampleContext.isFinderDesktopSurface && definition.id == BuiltInActionCatalog.batchRename.id)
            }
        recentHistory = Array(persistenceState.actionHistory.prefix(12))
    }

    private func persistInvocation(
        for action: ActionDefinition,
        result: ActionExecutionResult,
        context: ActionContext
    ) async {
        let record = ActionInvocationRecord(
            actionID: action.id,
            context: context.snapshot,
            outcome: AppCoordinator.outcome(for: result),
            note: AppCoordinator.note(for: result)
        )

        do {
            let controller = try appGroupContainer.makePersistenceController()
            try controller.appendInvocation(record)
            persistenceState = controller.loadOrCreateState()
        } catch {
            persistenceState.actionHistory.insert(record, at: 0)
            statusBanner = StatusBanner(
                tone: .warning,
                title: "Could not write history to disk",
                detail: error.localizedDescription
            )
        }
    }

    private func persistState() {
        do {
            let controller = try appGroupContainer.makePersistenceController()
            try controller.saveState(persistenceState)
        } catch {
            statusBanner = StatusBanner(
                tone: .warning,
                title: "Could not save settings",
                detail: error.localizedDescription
            )
        }
    }

    private func defaultPinnedActions() -> [PinnedAction] {
        [
            PinnedAction(actionID: BuiltInActionCatalog.copyFullPath.id, order: 0),
            PinnedAction(actionID: BuiltInActionCatalog.openTerminalHere.id, order: 1),
            PinnedAction(actionID: BuiltInActionCatalog.compressItems.id, order: 2)
        ]
    }

    private func persistConfigurationState(title: String, detail: String) {
        persistState()
        Task {
            await refreshModel()
        }
        statusBanner = StatusBanner(
            tone: .success,
            title: title,
            detail: detail
        )
    }

    private func recalculateBatchRenamePlan() {
        guard let context = batchRenameContext else {
            batchRenamePlan = nil
            return
        }

        let planner = BatchRenamePlanner()
        batchRenameDraft.items = context.items.map(BatchRenameItemInput.init(actionItem:))
        batchRenamePlan = planner.makePlan(for: batchRenameDraft.request)
    }

    private func handleExternalBatchRenameRequest(_ resolvedCommand: ResolvedExternalCommand) {
        NSLog("[SuperRClick] handleExternalBatchRenameRequest: ENTER with id=%@", resolvedCommand.request.id.uuidString)
        guard handledExternalRequestIDs.insert(resolvedCommand.request.id).inserted else {
            NSLog("[SuperRClick] handleExternalBatchRenameRequest: DUPLICATE id, skipping")
            return
        }

        guard resolvedCommand.context.hasFileItems else {
            NSLog("[SuperRClick] handleExternalBatchRenameRequest: EMPTY context, no file items")
            statusBanner = StatusBanner(
                tone: .warning,
                title: "Ignored empty batch rename request",
                detail: "Finder did not provide any files or folders to rename."
            )
            return
        }

        if isPresentingBatchRename || isApplyingBatchRename {
            NSLog("[SuperRClick] handleExternalBatchRenameRequest: already presenting, queuing")
            queuedExternalResolvedCommand = resolvedCommand
            return
        }

        NSLog("[SuperRClick] handleExternalBatchRenameRequest: calling presentExternalBatchRename")
        presentExternalBatchRename(resolvedCommand)
    }

    private func presentExternalBatchRename(_ resolvedCommand: ResolvedExternalCommand) {
        NSLog("[SuperRClick] presentExternalBatchRename: ENTER")
        let resolvedContext = resolvedCommand.context
        var resolvedDraft = BatchRenameDraft(context: resolvedContext)
        if resolvedDraft.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedDraft.token = "Renamed"
        }

        releaseActiveExternalSecurityScopes()
        activeExternalSecurityScopedURLs = resolvedCommand.securityScopedURLs
        batchRenameContext = resolvedContext
        batchRenameDraft = resolvedDraft
        sampleContext = resolvedContext
        recalculateBatchRenamePlan()
        isPresentingBatchRename = true
        NSLog("[SuperRClick] presentExternalBatchRename: about to call showBatchRenamePanel")
        showBatchRenamePanel()
        NSLog("[SuperRClick] presentExternalBatchRename: showBatchRenamePanel returned, activating app")
        NSApp.activate(ignoringOtherApps: true)
        Task {
            await refreshModel()
        }
    }

    // MARK: - Batch Rename Panel Window Management

    private func showBatchRenamePanel() {
        BatchRenameWindowController.shared.show(coordinator: self)
    }

    private func closeBatchRenamePanel() {
        BatchRenameWindowController.shared.close()
    }

    private func releaseActiveExternalSecurityScopes() {
        guard !activeExternalSecurityScopedURLs.isEmpty else {
            return
        }

        for url in activeExternalSecurityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }

        activeExternalSecurityScopedURLs.removeAll()
    }

    // Demo context generation removed — batch rename now always uses real files
    // from either FinderSync selection or user-picked files via NSOpenPanel.

    private func defaultMonitoredFolders(from profiles: [WorkspaceProfile] = []) -> [MonitoredFolder] {
        if !profiles.isEmpty {
            let mappedFolders = profiles.map { profile in
                let canonicalURL = RealUserDirectories.migrateSandboxedURLIfNeeded(profile.rootURL)
                return MonitoredFolder(
                    name: profile.name,
                    url: canonicalized(canonicalURL),
                    preset: AppCoordinator.preset(for: canonicalized(canonicalURL))
                )
            }

            return ensureHomeMonitoredFolder(in: mappedFolders)
        }

        var folders = [
            MonitoredFolder(
                name: "Home",
                url: canonicalized(RealUserDirectories.homeDirectory()),
                preset: .custom
            )
        ]

        let candidates = RealUserDirectories.knownRoots()
            .map { ($0.key, Optional($0.value)) }

        folders.append(contentsOf: candidates.compactMap { preset, url in
            guard let url else { return nil }
            let canonicalURL = canonicalized(url)
            return MonitoredFolder(
                name: AppCoordinator.defaultName(for: preset, url: canonicalURL),
                url: canonicalURL,
                preset: preset
            )
        })

        return deduplicatedMonitoredFolders(folders)
    }

    private func synchronizeWorkspaceProfiles(
        existingProfiles: [WorkspaceProfile],
        monitoredFolders: [MonitoredFolder]
    ) -> [WorkspaceProfile] {
        var profiles = existingProfiles

        for folder in monitoredFolders {
            let canonicalURL = canonicalPath(folder.url)
            guard !profiles.contains(where: { canonicalPath($0.rootURL) == canonicalURL }) else {
                continue
            }

            profiles.append(
                WorkspaceProfile(
                    name: folder.name,
                    rootURL: folder.url,
                    pinnedActionIDs: AppCoordinator.recommendedActionIDs(for: folder.preset)
                )
            )
        }

        return profiles.sorted { canonicalPath($0.rootURL) < canonicalPath($1.rootURL) }
    }

    private func migrateBuiltInFolderPaths(in state: PersistenceState) -> PersistenceState {
        var nextState = state

        let migratedFolders = state.monitoredFolders.map { folder -> MonitoredFolder in
            var updatedFolder = folder
            let migratedURL = canonicalized(RealUserDirectories.migrateSandboxedURLIfNeeded(folder.url))
            updatedFolder.url = migratedURL

            if folder.preset != .custom {
                updatedFolder.name = AppCoordinator.defaultName(for: folder.preset, url: migratedURL)
            }

            return updatedFolder
        }

        let migratedProfiles = state.workspaceProfiles.map { profile -> WorkspaceProfile in
            var updatedProfile = profile
            let migratedURL = canonicalized(RealUserDirectories.migrateSandboxedURLIfNeeded(profile.rootURL))
            updatedProfile.rootURL = migratedURL

            let migratedPreset = AppCoordinator.preset(for: migratedURL)
            if migratedPreset != .custom {
                updatedProfile.name = AppCoordinator.defaultName(for: migratedPreset, url: migratedURL)
            }

            return updatedProfile
        }

        nextState.monitoredFolders = deduplicatedMonitoredFolders(migratedFolders)
        nextState.workspaceProfiles = deduplicatedWorkspaceProfiles(migratedProfiles)
        return nextState
    }

    private func deduplicatedMonitoredFolders(_ folders: [MonitoredFolder]) -> [MonitoredFolder] {
        var deduplicated: [MonitoredFolder] = []

        for folder in folders {
            let candidateURL = canonicalized(folder.url)
            let candidatePath = canonicalPath(candidateURL)

            if let existingIndex = deduplicated.firstIndex(where: { canonicalPath($0.url) == candidatePath }) {
                deduplicated[existingIndex].isEnabled = deduplicated[existingIndex].isEnabled || folder.isEnabled
                if deduplicated[existingIndex].preset == .custom && folder.preset != .custom {
                    deduplicated[existingIndex].preset = folder.preset
                    deduplicated[existingIndex].name = folder.name
                }
                continue
            }

            var normalizedFolder = folder
            normalizedFolder.url = candidateURL
            deduplicated.append(normalizedFolder)
        }

        return deduplicated.sorted(by: AppCoordinator.monitoredFolderSort)
    }

    private func ensureHomeMonitoredFolder(in folders: [MonitoredFolder]) -> [MonitoredFolder] {
        let homeURL = canonicalized(RealUserDirectories.homeDirectory())
        let homePath = canonicalPath(homeURL)

        guard !folders.contains(where: { canonicalPath($0.url) == homePath }) else {
            return deduplicatedMonitoredFolders(folders)
        }

        var nextFolders = folders
        nextFolders.append(
            MonitoredFolder(
                name: "Home",
                url: homeURL,
                preset: .custom
            )
        )
        return deduplicatedMonitoredFolders(nextFolders)
    }

    private func deduplicatedWorkspaceProfiles(_ profiles: [WorkspaceProfile]) -> [WorkspaceProfile] {
        var deduplicated: [WorkspaceProfile] = []

        for profile in profiles {
            let candidateURL = canonicalized(profile.rootURL)
            let candidatePath = canonicalPath(candidateURL)

            if let existingIndex = deduplicated.firstIndex(where: { canonicalPath($0.rootURL) == candidatePath }) {
                deduplicated[existingIndex].pinnedActionIDs = Array(
                    Set(deduplicated[existingIndex].pinnedActionIDs + profile.pinnedActionIDs)
                ).sorted { $0.rawValue < $1.rawValue }
                deduplicated[existingIndex].visibilityRuleIDs = Array(
                    Set(deduplicated[existingIndex].visibilityRuleIDs + profile.visibilityRuleIDs)
                ).sorted { $0.uuidString < $1.uuidString }
                continue
            }

            var normalizedProfile = profile
            normalizedProfile.rootURL = candidateURL
            deduplicated.append(normalizedProfile)
        }

        return deduplicated.sorted { canonicalPath($0.rootURL) < canonicalPath($1.rootURL) }
    }

    func setSetupCompleted(_ completed: Bool) {
        hasCompletedSetup = completed
        UserDefaults.standard.set(completed, forKey: Constants.setupCompletedDefaultsKey)
    }

    private nonisolated static func detectFinderExtensionStatus() -> (isEnabled: Bool, detail: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = [
            "-m",
            "-A",
            "-D",
            "-v",
            "-p",
            "com.apple.FinderSync",
            "-i",
            Constants.finderExtensionBundleIdentifier
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            let isEnabled = output
                .split(separator: "\n")
                .contains(where: { $0.contains("+") && $0.contains(Constants.finderExtensionBundleIdentifier) })

            if isEnabled {
                return (
                    true,
                    L("Finder 扩展已启用。Finder 窗口和已覆盖目录中的右键菜单应该可以正常出现。", "Finder extension is enabled. Context menus should appear in Finder windows.")
                )
            }

            return (
                false,
                L("Finder 扩展还没有被系统标记为启用。请前往系统设置中的扩展页面开启它。", "Finder extension is not enabled. Please enable it in System Settings > Extensions.")
            )
        } catch {
            return (
                false,
                L("暂时无法读取 Finder 扩展状态：\(error.localizedDescription)", "Cannot read Finder extension status: \(error.localizedDescription)")
            )
        }
    }

    private func canonicalized(_ url: URL) -> URL {
        url.standardizedFileURL
    }

    private func canonicalPath(_ url: URL) -> String {
        canonicalized(url).path(percentEncoded: false)
    }

    private func displayName(for url: URL) -> String {
        AppCoordinator.defaultName(for: AppCoordinator.preset(for: url), url: url)
    }

    private static func monitoredFolderSort(lhs: MonitoredFolder, rhs: MonitoredFolder) -> Bool {
        let left = monitoredFolderSortRank(lhs.preset)
        let right = monitoredFolderSortRank(rhs.preset)

        if left == right {
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        return left < right
    }

    private static func monitoredFolderSortRank(_ preset: MonitoredFolderPreset) -> Int {
        switch preset {
        case .desktop:
            return 0
        case .documents:
            return 1
        case .downloads:
            return 2
        case .custom:
            return 3
        }
    }

    private static func preset(for url: URL) -> MonitoredFolderPreset {
        let canonicalURL = url.standardizedFileURL.path(percentEncoded: false)

        for (preset, candidateURL) in RealUserDirectories.knownRoots() {
            if candidateURL.standardizedFileURL.path(percentEncoded: false) == canonicalURL {
                return preset
            }
        }

        return .custom
    }

    private static func defaultName(for preset: MonitoredFolderPreset, url: URL) -> String {
        switch preset {
        case .desktop:
            return "Desktop"
        case .documents:
            return "Documents"
        case .downloads:
            return "Downloads"
        case .custom:
            return FileManager.default.displayName(atPath: url.path)
        }
    }

    private static func recommendedActionIDs(for preset: MonitoredFolderPreset) -> [ActionID] {
        switch preset {
        case .desktop:
            return [
                BuiltInActionCatalog.openTerminalHere.id,
                BuiltInActionCatalog.compressItems.id,
                BuiltInActionCatalog.batchRename.id
            ]
        case .documents:
            return [
                BuiltInActionCatalog.copyFullPath.id,
                BuiltInActionCatalog.compressItems.id
            ]
        case .downloads:
            return [
                BuiltInActionCatalog.convertImage.id,
                BuiltInActionCatalog.copyShellEscapedPath.id,
                BuiltInActionCatalog.compressItems.id
            ]
        case .custom:
            return [
                BuiltInActionCatalog.copyFullPath.id,
                BuiltInActionCatalog.openTerminalHere.id
            ]
        }
    }

    private static func makeDefaultContext() -> ActionContext {
        let desktop = RealUserDirectories.desktop()

        return ActionContext.finderContainer(
            desktop,
            displayName: "Desktop",
            surface: .desktop,
            sourceApplicationBundleIdentifier: "com.apple.finder",
            workspaceIdentifier: desktop.path
        )
    }

    private static func outcome(for result: ActionExecutionResult) -> InvocationOutcome {
        switch result {
        case .completed:
            .success
        case .blocked:
            .blocked
        case .failed:
            .failure
        case .missingHandler:
            .missingHandler
        }
    }

    private static func note(for result: ActionExecutionResult) -> String? {
        switch result {
        case let .completed(message):
            message
        case let .blocked(reason):
            reason
        case let .failed(reason, _):
            reason
        case let .missingHandler(actionID):
            "Missing handler for \(actionID.rawValue)"
        }
    }

    private static func statusBanner(
        for action: ActionDefinition,
        result: ActionExecutionResult
    ) -> StatusBanner {
        switch result {
        case let .completed(message):
            return StatusBanner(
                tone: .success,
                title: L("\(action.title) 已完成", "\(action.title) completed"),
                detail: message
            )
        case let .blocked(reason):
            return StatusBanner(
                tone: .warning,
                title: L("\(action.title) 已拦截", "\(action.title) was blocked"),
                detail: reason
            )
        case let .failed(reason, _):
            return StatusBanner(
                tone: .error,
                title: L("\(action.title) 失败", "\(action.title) failed"),
                detail: reason
            )
        case let .missingHandler(actionID):
            return StatusBanner(
                tone: .warning,
                title: L("未找到 \(action.title) 的处理器", "No handler for \(action.title)"),
                detail: L("缺少动作实现：\(actionID.rawValue)", "Missing action implementation for \(actionID.rawValue).")
            )
        }
    }
}
