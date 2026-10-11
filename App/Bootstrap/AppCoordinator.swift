import AppKit
import FinderSync
import Foundation
import Observation
import Shared
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class AppCoordinator {
    static var isIsolatedPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["SUPERRCLICK_TEST_STORAGE"]?.hasPrefix("/") == true
        #else
        false
        #endif
    }

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
    }

    @ObservationIgnored private let actionEngine: ActionEngine
    @ObservationIgnored private let appGroupContainer: AppGroupContainer
    @ObservationIgnored private let externalCommandCenter: Shared.ExternalCommandCenter
    @ObservationIgnored private let platformExecutor: PlatformActionExecutor
    @ObservationIgnored private let aiExecutor: AIActionExecutor
    @ObservationIgnored private let customExecutor: CustomActionExecutor
    @ObservationIgnored private var externalCommandObserver: NSObjectProtocol?
    @ObservationIgnored private var setupActivationTask: Task<Void, Never>?
    @ObservationIgnored private var activeExternalSecurityScopedURLs: [URL] = []
    @ObservationIgnored private var handledExternalRequestIDs: Set<UUID> = []
    @ObservationIgnored private var activeProgressTaskID: UUID?

    var sampleContext: ActionContext
    var actionSections: [ActionSectionSnapshot] = []
    var allDefinitions: [ActionDefinition] = []
    var pinnedActions: [ActionDefinition] = []
    var recentHistory: [ActionInvocationRecord] = []
    var persistenceState = PersistenceState()
    var statusBanner: StatusBanner?
    var selectedSection: SidebarSection? = .actionLibrary
    var actionBeingEdited: CustomAction?
    var taskProgress: TaskProgressInfo?
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
        platformExecutor: PlatformActionExecutor = PlatformActionExecutor(),
        aiExecutor: AIActionExecutor = AIActionExecutor(),
        customExecutor: CustomActionExecutor = CustomActionExecutor()
    ) {
        self.actionEngine = actionEngine
        self.appGroupContainer = appGroupContainer
        self.externalCommandCenter = appGroupContainer.makeExternalCommandCenter()
        self.platformExecutor = platformExecutor
        self.aiExecutor = aiExecutor
        self.customExecutor = customExecutor
        self.sampleContext = AppCoordinator.makeDefaultContext()
        if Self.isIsolatedPreview { hasCompletedSetup = true }

        if !Self.isIsolatedPreview {
            setupActivationTask = Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification) {
                    guard !Task.isCancelled, let self else { return }
                    self.refreshSetupStatus()
                    DesktopBridgeManager.shared.checkPermissions(prompt: false)
                }
            }
        }

        Task {
            await bootstrap()
        }
    }

    deinit {
        setupActivationTask?.cancel()
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
        guard !Self.isIsolatedPreview else { return }
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
                title: L("动作库已刷新", "Action library refreshed"),
                detail: nil
            )
        }
    }

    func presentSetupCenter() {
        isPresentingSetupCenter = true
        refreshSetupStatus()
    }

    func refreshSetupStatus() {
        guard !Self.isIsolatedPreview else { return }
        guard !isRefreshingSetupStatus else {
            return
        }

        isRefreshingSetupStatus = true
        defer { isRefreshingSetupStatus = false }

        let isEnabled = FIFinderSyncController.isExtensionEnabled
        finderExtensionStatus = isEnabled ? .ready : .actionRequired
        finderExtensionDetail = isEnabled
            ? L("Finder 扩展已启用。请在 Finder 中右键点击文件，确认菜单是否显示。", "Finder extension is enabled. Right-click a file in Finder to check the menu.")
            : L("请在“系统设置 → 通用 → 登录项与扩展”中启用 Super RClick 的 Finder 扩展。", "Enable the Super RClick Finder extension in System Settings → General → Login Items & Extensions.")
        lastSetupRefreshAt = Date()
    }

    func openFinderExtensionsSettings() {
        guard !Self.isIsolatedPreview else { return }
        FIFinderSyncController.showExtensionManagementInterface()
    }

    func openAccessibilitySettings() {
        guard !Self.isIsolatedPreview else { return }
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openInputMonitoringSettings() {
        guard !Self.isIsolatedPreview else { return }
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func run(_ action: ActionDefinition) {
        run(actionID: action.id, context: sampleContext)
    }

    /// Resolve the current saved definition and freeze the selection for this invocation.
    func run(actionID: ActionID, context: ActionContext) {
        if actionID.rawValue.hasPrefix("custom-") {
            runCustomAction(actionID: actionID, context: context)
            return
        }

        guard let action = (BuiltInActionCatalog.all + NewFileCatalog.all).first(where: { $0.id == actionID }) else {
            statusBanner = StatusBanner(tone: .warning, title: L("动作不可用", "Action unavailable"),
                                        detail: L("该动作已被移除，请刷新后再试。", "This action was removed. Refresh and try again."))
            return
        }

        if action.id == BuiltInActionCatalog.batchRename.id {
            openBatchRename(for: context)
            return
        }

        if action.id == BuiltInActionCatalog.convertImage.id {
            sampleContext = context
            runImageConversionWithFormatPicker()
            return
        }

        Task {
            if AIActionCatalog.all.contains(where: { $0.id == action.id }) {
                let localCount = context.items.count
                let localSnapshot = context.snapshot
                let localConfig = persistenceState.aiConfig
                
                executeWithProgress(title: action.title, totalItems: localCount) { [self] onProgress in
                    let reporter = AIProgressWrapper(callback: onProgress, totalItems: localCount)
                    do {
                        try await self.aiExecutor.execute(actionID: action.id, context: localSnapshot, aiConfig: localConfig, progressReporter: reporter)
                        return .completed(message: L("AI 操作成功", "AI operation succeeded"))
                    } catch {
                        return .failed(reason: error.localizedDescription, recoverable: true)
                    }
                } completion: { [self] result in
                    Task {
                        await persistInvocation(for: action, result: result, context: context)
                        await refreshModel()
                        statusBanner = AppCoordinator.statusBanner(for: action, result: result)
                    }
                }
            } else {
                let result = await actionEngine.execute(actionID: action.id, context: context)
                await persistInvocation(for: action, result: result, context: context)
                await refreshModel()
                statusBanner = AppCoordinator.statusBanner(for: action, result: result)
            }
        }
    }

    private func runCustomAction(actionID: ActionID, context: ActionContext) {
        guard let custom = persistenceState.customActions.first(where: { $0.toActionDefinition().id == actionID }),
              custom.isEnabled else {
            statusBanner = StatusBanner(tone: .warning, title: L("自定义动作不可用", "Custom action unavailable"),
                                        detail: L("此动作已停用或删除，请刷新菜单后再试。", "This action was disabled or deleted. Refresh the menu and try again."))
            return
        }
        let action = custom.toActionDefinition()
        guard action.matches(context), !isActionHidden(action) else {
            statusBanner = StatusBanner(tone: .warning, title: L("选择不满足动作条件", "Selection does not match this action"),
                                        detail: L("请检查所选文件的数量和扩展名。", "Check the selected file count and extensions."))
            return
        }

        executeWithProgress(title: action.title, totalItems: context.items.count) { [customExecutor] onProgress in
            onProgress?(0, context.items.count, custom.name)
            let result = await customExecutor.execute(custom, context: context)
            onProgress?(context.items.count, context.items.count, custom.name)
            return result
        } completion: { [self] result in
            Task {
                await persistInvocation(for: action, result: result, context: context)
                await refreshModel()
                statusBanner = AppCoordinator.statusBanner(for: action, result: result)
            }
        }
    }

    /// The app's panel has no live Finder selection. Always ask for an explicit target.
    func runFromPanel(_ action: ActionDefinition) {
        if action.availability.requiresTextSelection {
            statusBanner = StatusBanner(
                tone: .info,
                title: L("此动作需要选中文本", "This action needs selected text"),
                detail: L("此面板没有文本选择。请在原应用中选中文本并使用复制命令。", "This panel has no text selection. Select text and use Copy in the source app.")
            )
            return
        }
        switch action.id {
        case BuiltInActionCatalog.batchRename.id:
            openBatchRename()
        case BuiltInActionCatalog.convertImage.id:
            runImageConversionFromToolbox()
        case BuiltInActionCatalog.compressItems.id:
            runCompressFromToolbox()
        case BuiltInActionCatalog.openTerminalHere.id:
            runOpenTerminalFromToolbox()
        default:
            let isTemplate = action.section == .newFile
            let panel = NSOpenPanel()
            panel.title = action.title
            panel.prompt = L("选择", "Choose")
            panel.canChooseFiles = !isTemplate
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = !isTemplate
            guard panel.runModal() == .OK, let firstURL = panel.urls.first else { return }
            if isTemplate {
                sampleContext = .finderContainer(firstURL, displayName: firstURL.lastPathComponent,
                                                sourceApplicationBundleIdentifier: Bundle.main.bundleIdentifier)
            } else {
                let items = panel.urls.map { url in
                    ActionItem(url: url, displayName: url.lastPathComponent,
                               isDirectory: (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false)
                }
                sampleContext = .finderSelection(items, sourceApplicationBundleIdentifier: Bundle.main.bundleIdentifier)
            }
            run(action)
        }
    }

    func runImageConversionWithFormatPicker() {
        let selectedContext = sampleContext
        let formats = ["png", "jpeg", "tiff", "heic"]

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

        let enrichedContext = ActionContext.finderSelection(
            selectedContext.items,
            sourceApplicationBundleIdentifier: selectedContext.sourceApplicationBundleIdentifier,
            workspaceIdentifier: selectedContext.workspaceIdentifier,
            metadata: selectedContext.metadata.merging(["convertImage.format": selectedFormat]) { _, new in new }
        )

        guard let action = BuiltInActionCatalog.definition(for: BuiltInActionCatalog.convertImage.id) else { return }
        let itemCount = selectedContext.items.count

        executeWithProgress(
            title: L("正在转换图片...", "Converting images..."),
            totalItems: itemCount
        ) { [self] onProgress in
            await platformExecutor.execute(actionID: action.id, context: enrichedContext, onProgress: onProgress)
        } completion: { [self] result in
            Task {
                await persistInvocation(for: action, result: result, context: enrichedContext)
                await refreshModel()
                statusBanner = AppCoordinator.statusBanner(for: action, result: result)
            }
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

        executeWithProgress(
            title: L("正在压缩文件...", "Compressing files..."),
            totalItems: items.count
        ) { [self] onProgress in
            await platformExecutor.execute(actionID: action.id, context: context, onProgress: onProgress)
        } completion: { [self] result in
            Task {
                await persistInvocation(for: action, result: result, context: context)
                await refreshModel()
                statusBanner = AppCoordinator.statusBanner(for: action, result: result)
            }
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

    func quickJumpToDirectory() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = L("快速跳转目录", "Quick Jump to Directory")
        alert.informativeText = L("输入或粘贴目录路径，将在访达中打开。", "Enter or paste a directory path to open in Finder.")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L("打开", "Open"))
        alert.addButton(withTitle: L("取消", "Cancel"))

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = L("例如: ~/Downloads 或 /Users/...", "e.g. ~/Downloads or /Users/...")
        textField.stringValue = "~/"
        alert.accessoryView = textField
        alert.window.initialFirstResponder = textField

        guard alert.runModal() == .alertFirstButtonReturn else { return }

        var path = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }

        // Expand ~ to home directory
        if path.hasPrefix("~") {
            path = (path as NSString).expandingTildeInPath
        }

        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) {
            if isDir.boolValue {
                NSWorkspace.shared.open(url)
            } else {
                // If it's a file, reveal it in Finder
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } else {
            let errorAlert = NSAlert()
            errorAlert.messageText = L("路径不存在", "Path Not Found")
            errorAlert.informativeText = L("输入的路径不存在: \(path)", "The path does not exist: \(path)")
            errorAlert.alertStyle = .warning
            errorAlert.addButton(withTitle: L("确定", "OK"))
            errorAlert.runModal()
        }
    }

    func togglePinned(_ action: ActionDefinition) {
        var updated = persistenceState
        if let index = updated.pinnedActions.firstIndex(where: { $0.actionID == action.id }) {
            updated.pinnedActions.remove(at: index)
        } else {
            let nextOrder = (updated.pinnedActions.map(\.order).max() ?? -1) + 1
            updated.pinnedActions.append(
                PinnedAction(actionID: action.id, order: nextOrder, isFavorite: true)
            )
        }

        guard saveState(updated) else { return }

        Task {
            await refreshModel()
        }
    }

    func isPinned(_ action: ActionDefinition) -> Bool {
        persistenceState.pinnedActions.contains(where: { $0.actionID == action.id })
    }

    func openBatchRename(for context: ActionContext? = nil) {
        if isPresentingBatchRename || isApplyingBatchRename {
            showBatchRenamePanel()
            return
        }
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
        guard !Self.isIsolatedPreview else { return }
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
        guard !isApplyingBatchRename else { return }
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
        guard !isApplyingBatchRename else { return }
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
        guard !isApplyingBatchRename else { return }
        batchRenameDraft = draft
        recalculateBatchRenamePlan()
    }

    func applyBatchRename() {
        guard !isApplyingBatchRename else { return }
        guard let context = batchRenameContext,
              let plan = batchRenamePlan,
              plan.canApply,
              let action = BuiltInActionCatalog.definition(for: BuiltInActionCatalog.batchRename.id) else {
            return
        }

        isApplyingBatchRename = true
        let renamableCount = plan.previews.filter { $0.sourceURL.path != $0.proposedURL.path }.count

        let didStart = executeWithProgress(
            title: L("正在重命名...", "Renaming files..."),
            totalItems: renamableCount
        ) { [self] onProgress in
            await platformExecutor.applyBatchRename(plan: plan, onProgress: onProgress)
        } completion: { [self] result in
            Task {
                await persistInvocation(for: action, result: result, context: context)
                await refreshModel()

                isApplyingBatchRename = false
                statusBanner = AppCoordinator.statusBanner(for: action, result: result)

                if case .completed = result {
                    dismissBatchRename()
                }
            }
        }
        if !didStart {
            isApplyingBatchRename = false
        }
    }

    // MARK: - Progress-tracked execution

    @discardableResult
    func executeWithProgress(
        title: String,
        totalItems: Int,
        operation: @escaping @Sendable (ProgressCallback?) async -> ActionExecutionResult,
        completion: @escaping @MainActor (ActionExecutionResult) -> Void
    ) -> Bool {
        guard activeProgressTaskID == nil else {
            statusBanner = StatusBanner(
                tone: .warning,
                title: L("已有任务正在运行", "Another task is running"),
                detail: L("请等待当前任务完成后再试。", "Wait for the current task to finish, then try again.")
            )
            return false
        }

        let progress = TaskProgressInfo(
            title: title,
            detail: L("准备中...", "Preparing..."),
            current: 0,
            total: totalItems
        )
        let taskID = progress.id
        activeProgressTaskID = taskID
        taskProgress = progress

        let progressBinding = Binding<TaskProgressInfo?>(
            get: { [weak self] in self?.taskProgress },
            set: { [weak self] in self?.taskProgress = $0 }
        )
        TaskProgressWindowController.shared.show(info: progressBinding)

        Task { [self] in
            let onProgress: ProgressCallback = { @Sendable [weak self] current, total, detail in
                Task { @MainActor [weak self] in
                    guard self?.activeProgressTaskID == taskID,
                          var p = self?.taskProgress,
                          p.id == taskID, !p.isComplete else { return }
                    p.current = current
                    p.total = total
                    p.detail = detail
                    self?.taskProgress = p
                }
            }

            let result = await operation(onProgress)

            let isSuccess: Bool
            let resultMessage: String
            switch result {
            case .completed(let msg):
                isSuccess = true
                resultMessage = msg ?? L("操作完成", "Operation completed")
            case .failed(let reason, _):
                isSuccess = false
                resultMessage = reason
            case .blocked(let reason):
                isSuccess = false
                resultMessage = reason
            default:
                isSuccess = false
                resultMessage = L("操作未知结果", "Unknown result")
            }

            // Batch all final mutations into a single read-modify-write
            // to avoid Swift runtime exclusivity crash
            if var p = taskProgress, p.id == taskID {
                p.isComplete = true
                p.isSuccess = isSuccess
                p.resultMessage = resultMessage
                p.current = p.total
                taskProgress = p
            }
            activeProgressTaskID = nil

            // Auto-close after 3 seconds on success
            if isSuccess {
                TaskProgressWindowController.shared.scheduleAutoClose(delay: 3.0)
            }

            completion(result)
        }
        return true
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
        guard !Self.isIsolatedPreview else { return }
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

            let resolvedCommand = try externalCommandCenter.resolveRequest(request)
            NSLog("[SuperRClick] consumePendingExternalCommands: resolved command, context items=%d", resolvedCommand.context.items.count)
            
            if request.kind == .presentBatchRename {
                handleExternalBatchRenameRequest(resolvedCommand)
            } else if request.kind == .runAction, let actionIDRaw = request.metadata["target.action.id"] {
                let actionID = ActionID(rawValue: actionIDRaw)
                if let action = BuiltInActionCatalog.definition(for: actionID) ?? AIActionCatalog.all.first(where: { $0.id == actionID }) {
                    self.sampleContext = resolvedCommand.context
                    self.run(action)
                }
            }
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
        var updated = persistenceState
        updated.visibilityRules.removeAll(where: { $0.actionID == action.id })

        if isHidden {
            updated.visibilityRules.append(
                VisibilityRule(
                    actionID: action.id,
                    mode: .exclude,
                    allowedContextKinds: [.finderSelection, .mixedSelection]
                )
            )
        }

        guard saveState(updated) else { return }

        Task {
            await actionEngine.setVisibilityRules(persistenceState.visibilityRules)
            await refreshModel()
        }
    }

    // MARK: - Custom Actions

    func presentActionEditor(_ action: CustomAction? = nil) {
        guard actionBeingEdited == nil, isReady else { return }
        actionBeingEdited = action ?? CustomAction()
    }

    func saveCustomAction(_ action: CustomAction) throws {
        let action = try action.validated()
        var updated = persistenceState
        let existingIndex = updated.customActions.firstIndex(where: { $0.id == action.id })
        if let existingIndex {
            updated.customActions[existingIndex] = action
        } else {
            updated.customActions.append(action)
        }
        let controller = try appGroupContainer.makePersistenceController()
        try controller.saveState(updated)
        persistenceState = updated
        statusBanner = StatusBanner(
            tone: .success,
            title: existingIndex == nil
                ? L("已创建自定义动作", "Custom action created")
                : L("已保存自定义动作", "Custom action saved"),
            detail: action.name
        )

        Task {
            await refreshModel()
        }
    }

    func deleteCustomAction(_ action: CustomAction) {
        var updated = persistenceState
        updated.customActions.removeAll(where: { $0.id == action.id })
        guard saveState(updated) else { return }
        statusBanner = StatusBanner(tone: .success, title: L("已删除动作", "Action deleted"), detail: action.name)

        Task {
            await refreshModel()
        }
    }

    func setCustomActionEnabled(_ action: CustomAction, isEnabled: Bool) {
        var updated = persistenceState
        guard let index = updated.customActions.firstIndex(where: { $0.id == action.id }) else { return }
        updated.customActions[index].isEnabled = isEnabled
        _ = saveState(updated)
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
        var updated = persistenceState
        updated.actionHistory.removeAll()
        guard saveState(updated) else { return }
        statusBanner = StatusBanner(tone: .success, title: L("执行记录已清除", "Activity cleared"), detail: nil)

        Task {
            await refreshModel()
        }
    }

    private func bootstrap() async {
        do {
            let controller = try appGroupContainer.makePersistenceController()
            let isFirstLaunch = !FileManager.default.fileExists(atPath: controller.stateFileURL.path)
            persistenceState = controller.loadOrCreateState()
            var didSeedDefaults = false

            let migratedState = migrateBuiltInFolderPaths(in: persistenceState)
            if migratedState != persistenceState {
                persistenceState = migratedState
                didSeedDefaults = true
            }

            if isFirstLaunch {
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
        await actionEngine.reloadDefinitions(BuiltInActionCatalog.all + NewFileCatalog.all)
        allDefinitions = await actionEngine.allDefinitions()
        
        // Group all definitions regardless of current context visibility so Action Library shows everything
        let groupedDefinitions = Dictionary(grouping: allDefinitions, by: \.section)
        
        var combinedSections = groupedDefinitions.keys.sorted().map { section in
            let actionsInSection = (groupedDefinitions[section] ?? []).sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return ActionSectionSnapshot(section: section, actions: actionsInSection)
        }
        
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

    @discardableResult
    private func saveState(_ updated: PersistenceState) -> Bool {
        do {
            let controller = try appGroupContainer.makePersistenceController()
            try controller.saveState(updated)
            persistenceState = updated
            return true
        } catch {
            statusBanner = StatusBanner(
                tone: .error,
                title: L("设置未保存", "Settings were not saved"),
                detail: error.localizedDescription
            )
            return false
        }
    }

    @discardableResult
    private func persistState() -> Bool { saveState(persistenceState) }
    
    func saveAIConfig(_ config: AIConfig) -> Bool {
        var updated = persistenceState
        updated.aiConfig = config
        return saveState(updated)
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

struct AIProgressWrapper: ProgressReporting {
    let callback: ProgressCallback?
    let totalItems: Int

    func updateProgress(fractionCompleted: Double, message: String?) {
        callback?(Int(fractionCompleted * Double(totalItems)), totalItems, message ?? "")
    }
}
