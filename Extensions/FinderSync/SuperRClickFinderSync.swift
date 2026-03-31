import AppKit
import FinderSync
import Foundation
import Shared

public final class SuperRClickFinderSync: FIFinderSync {
    private enum Constants {
        static let appGroupID = "group.com.haoqiqin.superrclick"
        static let debugLogFileName = "finder-sync-debug.log"
    }

    private let menuComposer = SuperRClickFinderMenuComposer()
    private var lastPresentedContext: SuperRClickFinderContext?
    /// Title → ActionID.rawValue lookup table, rebuilt every time a menu is presented.
    /// This is the ultimate fallback when macOS strips representedObject from menu items.
    private var titleToActionID: [String: String] = [:]

    public override init() {
        super.init()
        configureMonitoredDirectories()
        let controller = FIFinderSyncController.default()
        let dirs = controller.directoryURLs.map(\.path).joined(separator: "\n  ")
        let msg = "[SuperRClickFinderSync] init at \(Date())\nMonitored directories:\n  \(dirs)"
        NSLog("%@", msg)
        debugLog(msg)
    }

    public override var toolbarItemName: String {
        "Super RClick"
    }

    public override var toolbarItemToolTip: String {
        "Quick Finder actions for files and folders"
    }

    public override var toolbarItemImage: NSImage {
        let image = NSImage(
            systemSymbolName: "gearshape.fill",
            accessibilityDescription: "Super RClick"
        ) ?? NSImage()
        image.isTemplate = true
        return image
    }

    public override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let controller = FIFinderSyncController.default()
        let context = SuperRClickFinderContext(
            menuKind: SuperRClickFinderMenuKind(menuKind),
            targetedURL: controller.targetedURL(),
            selectedItemURLs: controller.selectedItemURLs() ?? [],
            monitoredDirectoryURLs: Array(controller.directoryURLs)
        )

        lastPresentedContext = context
        titleToActionID.removeAll()

        let menu = menuComposer.makeMenu(for: context, target: self)
        
        let selectedPaths = context.selectedItemURLs.map(\.path).joined(separator: ", ")
        debugLog("[menu] Kind=\(menuKind.rawValue) targeted=\(context.targetedURL?.path ?? "nil") selected=[\(selectedPaths)]")

        let finalMenu: NSMenu
        if menu.numberOfItems == 0 {
            debugLog("[menu] empty → using fallback menu")
            finalMenu = fallbackMenu()
        } else {
            finalMenu = menu
        }
        
        // Build title→actionID lookup as ultimate fallback
        buildTitleLookup(menu: finalMenu)
        debugLog("[menu] titleToActionID has \(titleToActionID.count) entries")
        return finalMenu
    }
    
    /// Builds a title → action ID lookup table for fallback resolution.
    private func buildTitleLookup(menu: NSMenu) {
        for item in menu.items {
            if let rawValue = item.representedObject as? String {
                titleToActionID[item.title] = rawValue
            }
            if let submenu = item.submenu {
                buildTitleLookup(menu: submenu)
            }
        }
    }

    public override func beginObservingDirectory(at url: URL) {
        // Do NOT reconfigure here — it causes an infinite reconfiguration loop on macOS 26
        debugLog("[SuperRClickFinderSync] beginObservingDirectory: \(url.path)")
    }

    public override func endObservingDirectory(at url: URL) {
        debugLog("[SuperRClickFinderSync] endObservingDirectory: \(url.path)")
    }

    @objc func handleMenuAction(_ sender: NSMenuItem) {
        // Strategy: try representedObject first, then fall back to title lookup
        let rawValue: String
        
        if let obj = sender.representedObject as? String, !obj.isEmpty {
            rawValue = obj
            debugLog("[handleMenuAction] resolved via representedObject: \(rawValue)")
        } else if let resolved = titleToActionID[sender.title] {
            rawValue = resolved
            debugLog("[handleMenuAction] resolved via title fallback: '\(sender.title)' → \(rawValue)")
        } else {
            debugLog("[handleMenuAction] FAILED to resolve action for title='\(sender.title)' tag=\(sender.tag) representedObject=\(String(describing: sender.representedObject))")
            return
        }

        let context = currentContext()
        debugLog("[handleMenuAction] performing action=\(rawValue) with \(context.effectiveSelectionURLs.count) URLs: \(context.effectiveSelectionURLs.map(\.path))")
        perform(actionRawValue: rawValue, with: context)
    }

    private func configureMonitoredDirectories() {
        let controller = FIFinderSyncController.default()
        // Global mode: always monitor entire home directory, no user config needed
        let home = RealUserDirectories.homeDirectory()
        controller.directoryURLs = [home]
        debugLog("[SuperRClickFinderSync] global mode — monitoring: \(home.path)")
    }

    private func fallbackMenu() -> NSMenu {
        let menu = NSMenu(title: "Super RClick")

        let openPreferences = NSMenuItem(
            title: "打开 Super RClick",
            action: #selector(handleMenuAction(_:)),
            keyEquivalent: ""
        )
        openPreferences.target = self
        openPreferences.representedObject = "utility:open-preferences"
        menu.addItem(openPreferences)

        let refreshTargets = NSMenuItem(
            title: "刷新监控目录",
            action: #selector(handleMenuAction(_:)),
            keyEquivalent: ""
        )
        refreshTargets.target = self
        refreshTargets.representedObject = "utility:refresh-targets"
        menu.addItem(refreshTargets)

        return menu
    }

    // condensedMonitoredDirectories removed — macOS 26 requires explicit directory registration

    private func currentContext() -> SuperRClickFinderContext {
        if let lastPresentedContext {
            return lastPresentedContext
        }

        let controller = FIFinderSyncController.default()
        return SuperRClickFinderContext(
            menuKind: .items,
            targetedURL: controller.targetedURL(),
            selectedItemURLs: controller.selectedItemURLs() ?? [],
            monitoredDirectoryURLs: Array(controller.directoryURLs)
        )
    }

    private func perform(actionRawValue: String, with context: SuperRClickFinderContext) {
        if actionRawValue.hasPrefix("new-") {
            handleNewFileAction(rawValue: actionRawValue, context: context)
            return
        }
        
        if actionRawValue.hasPrefix("custom-") {
            handleCustomAction(rawValue: actionRawValue, context: context)
            return
        }

        switch actionRawValue {
        case BuiltInActionCatalog.copyFullPath.id.rawValue,
             BuiltInActionCatalog.copyPOSIXPath.id.rawValue:
            copyPaths(for: context.effectiveSelectionURLs)
        case BuiltInActionCatalog.copyShellEscapedPath.id.rawValue:
            copyShellEscapedPaths(for: context.effectiveSelectionURLs)
        case BuiltInActionCatalog.openTerminalHere.id.rawValue:
            withSecurityScopedAccess(to: context.effectiveSelectionURLs) {
                openTerminalHere(for: context.effectiveSelectionURLs.first)
            }
        case BuiltInActionCatalog.batchRename.id.rawValue:
            triggerBatchRename(from: context)
        case BuiltInActionCatalog.compressItems.id.rawValue:
            withSecurityScopedAccess(to: context.effectiveSelectionURLs) {
                compressItems(context.effectiveSelectionURLs)
            }
        case BuiltInActionCatalog.convertImage.id.rawValue:
            withSecurityScopedAccess(to: context.effectiveSelectionURLs) {
                convertImages(context.effectiveSelectionURLs, targetFormat: "png")
            }
        case _ where actionRawValue.hasPrefix("convert-image:"):
            let format = String(actionRawValue.dropFirst("convert-image:".count))
            withSecurityScopedAccess(to: context.effectiveSelectionURLs) {
                convertImages(context.effectiveSelectionURLs, targetFormat: format)
            }
        case BuiltInActionCatalog.copySelectedText.id.rawValue:
            logPlaceholder("Copy Selected Text", context: context)
        case "utility:reveal-in-finder":
            revealInFinder(context.effectiveSelectionURLs)
        case "utility:open-preferences":
            openPreferencesApp()
        case "utility:refresh-targets":
            configureMonitoredDirectories()
            logPlaceholder("Refresh Monitored Folders", context: context)
        default:
            logPlaceholder("Unknown Action", context: context)
        }
    }

    private func handleNewFileAction(rawValue: String, context: SuperRClickFinderContext) {
        let targetDir: URL
        if let first = context.effectiveSelectionURLs.first {
            targetDir = first.hasDirectoryPath ? first : first.deletingLastPathComponent()
        } else if let targeted = context.targetedURL {
            targetDir = targeted
        } else {
            debugLog("[newFile] no target directory available, aborting")
            return
        }

        let ext = rawValue.replacingOccurrences(of: "new-", with: "")
        debugLog("[newFile] creating .\(ext) in \(targetDir.path)")

        let fileManager = FileManager.default
        var fileName = "Untitled.\(ext)"
        var fileURL = targetDir.appendingPathComponent(fileName)
        var counter = 1

        while fileManager.fileExists(atPath: fileURL.path) {
            fileName = "Untitled \(counter).\(ext)"
            fileURL = targetDir.appendingPathComponent(fileName)
            counter += 1
        }

        var fileData = Data()
        if let base64String = NewFileData.base64Templates[ext],
           let decodedData = Data(base64Encoded: base64String) {
            fileData = decodedData
            debugLog("[newFile] using template data (\(fileData.count) bytes)")
        } else {
            debugLog("[newFile] no template, creating empty file")
        }

        // Try direct creation first (FinderSync has implicit access to monitored dirs)
        let success = fileManager.createFile(atPath: fileURL.path, contents: fileData, attributes: nil)
        if success {
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            debugLog("[newFile] SUCCESS: \(fileURL.path)")
            NSLog("Super RClick created new file at %@", fileURL.path)
        } else {
            debugLog("[newFile] FAILED direct creation at \(fileURL.path), trying with security scope...")
            // Fallback: try with security-scoped access
            withSecurityScopedAccess(to: [targetDir]) {
                let retrySuccess = fileManager.createFile(atPath: fileURL.path, contents: fileData, attributes: nil)
                if retrySuccess {
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                    self.debugLog("[newFile] SUCCESS via security scope: \(fileURL.path)")
                } else {
                    self.debugLog("[newFile] FAILED even with security scope at \(fileURL.path)")
                    NSLog("Super RClick failed to create new file at %@", fileURL.path)
                }
            }
        }
    }

    private func handleCustomAction(rawValue: String, context: SuperRClickFinderContext) {
        let actionUUIDString = rawValue.replacingOccurrences(of: "custom-", with: "")
        guard let uuid = UUID(uuidString: actionUUIDString) else { return }
        
        do {
            let container = AppGroupContainer(groupIdentifier: Constants.appGroupID)
            let controller = try container.makePersistenceController()
            let state = controller.loadOrCreateState()
            
            guard let action = state.customActions.first(where: { $0.id == uuid }) else { return }
            
            executeCustomAction(action, context: context)
        } catch {
            NSLog("[SuperRClick] Failed to load custom action: \(error)")
        }
    }
    
    private func executeCustomAction(_ action: CustomAction, context: SuperRClickFinderContext) {
        let urls = context.effectiveSelectionURLs
        let selectedPaths = urls.map { $0.path }.joined(separator: "\n")
        let firstPath = urls.first?.path ?? ""
        
        // Configure shell environment with selected files
        var env = ProcessInfo.processInfo.environment
        env["SELECTED_FILES"] = selectedPaths
        env["FIRST_FILE"] = firstPath
        env["TARGET_DIR"] = (urls.first?.hasDirectoryPath == true) ? firstPath : (urls.first?.deletingLastPathComponent().path ?? "")
        
        switch action.actionType {
        case .openApplication:
            // "open -b <bundle_id>" or "open -a <AppName> file"
            let appIdentifier = action.scriptContent.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !appIdentifier.isEmpty else { return }
            
            if appIdentifier.contains(".") { // Looks like a bundle ID e.g. com.apple.Safari
                guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appIdentifier) else {
                    NSLog("[SuperRClick] Could not resolve application URL for bundle id %@", appIdentifier)
                    return
                }

                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                NSWorkspace.shared.open(urls, withApplicationAt: applicationURL, configuration: configuration) { _, error in
                    if let error {
                        NSLog("[SuperRClick] Failed to open %@ with %@: %@", urls.map(\.path).joined(separator: ", "), appIdentifier, error.localizedDescription)
                    }
                }
            } else { // Fallback, execute command line
                var args = ["-a", appIdentifier]
                args.append(contentsOf: urls.map(\.path))
                runProcess(launchPath: "/usr/bin/open", arguments: args, environment: env)
            }
            
        case .shellScript:
            // Write script to temp file and execute
            let tempDir = FileManager.default.temporaryDirectory
            let scriptURL = tempDir.appendingPathComponent(UUID().uuidString + ".sh")
            do {
                try action.scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
                runProcess(launchPath: "/bin/sh", arguments: ["-c", scriptURL.path], environment: env)
            } catch {
                NSLog("[SuperRClick] Shell Script failed to prepare: \(error)")
            }
            
        case .appleScript:
            let tempDir = FileManager.default.temporaryDirectory
            let scriptURL = tempDir.appendingPathComponent(UUID().uuidString + ".scpt")
            do {
                try action.scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
                runProcess(launchPath: "/usr/bin/osascript", arguments: [scriptURL.path], environment: env)
            } catch {
                NSLog("[SuperRClick] AppleScript failed to prepare: \(error)")
            }
        }
    }

    private func openPreferencesApp() {
        let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        NSWorkspace.shared.open(appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private func copyPaths(for urls: [URL]) {
        guard !urls.isEmpty else {
            debugLog("[copyPaths] empty urls, skipping")
            return
        }

        let paths = urls.map(\.path).joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(paths, forType: .string)
        debugLog("[copyPaths] set pasteboard success=\(success) content='\(paths)'")
    }

    private func copyShellEscapedPaths(for urls: [URL]) {
        guard !urls.isEmpty else {
            debugLog("[copyShellPaths] empty urls, skipping")
            return
        }

        let paths = urls.map { shellEscapedPath($0.path) }.joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let success = pasteboard.setString(paths, forType: .string)
        debugLog("[copyShellPaths] set pasteboard success=\(success) content='\(paths)'")
    }

    private func revealInFinder(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func openTerminalHere(for url: URL?) {
        guard let url else { return }

        let directory = normalizedDirectory(for: url)
        _ = runProcess(
            launchPath: "/usr/bin/open",
            arguments: ["-a", "Terminal", directory.path]
        )
    }

    private func compressItems(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        let parents = Set(urls.map { normalizedDirectory(for: $0).path })
        guard parents.count == 1, let parentPath = parents.first else {
            logPlaceholder("Compress requires items from the same folder", context: currentContext())
            return
        }

        let parentDirectory = URL(fileURLWithPath: parentPath, isDirectory: true)
        let archiveName = "SuperRClick-\(timestamp()).zip"
        _ = runProcess(
            launchPath: "/usr/bin/zip",
            arguments: ["-r", archiveName] + urls.map(\.lastPathComponent),
            currentDirectoryURL: parentDirectory
        )
    }

    private func convertImages(_ urls: [URL], targetFormat: String = "png") {
        guard !urls.isEmpty else { return }

        let sipsFormat: String
        let fileExtension: String
        switch targetFormat.lowercased() {
        case "jpeg", "jpg":
            sipsFormat = "jpeg"
            fileExtension = "jpg"
        case "png":
            sipsFormat = "png"
            fileExtension = "png"
        case "tiff":
            sipsFormat = "tiff"
            fileExtension = "tiff"
        case "heic":
            sipsFormat = "heic"
            fileExtension = "heic"
        case "webp":
            sipsFormat = "com.google.webp"
            fileExtension = "webp"
        default:
            sipsFormat = "png"
            fileExtension = "png"
        }

        for inputURL in urls {
            let destinationURL = uniqueDestinationURL(
                preferredURL: inputURL.deletingPathExtension().appendingPathExtension(fileExtension)
            )
            _ = runProcess(
                launchPath: "/usr/bin/sips",
                arguments: ["-s", "format", sipsFormat, inputURL.path, "--out", destinationURL.path]
            )
        }
    }

    private func logPlaceholder(_ actionName: String, context: SuperRClickFinderContext) {
        let selectionCount = context.effectiveSelectionURLs.count
        NSLog("Super RClick placeholder action '%@' invoked for %ld item(s)", actionName, selectionCount)
    }

    private func withSecurityScopedAccess(
        to urls: [URL],
        perform work: () -> Void
    ) {
        let startedURLs = urls
            .map(\.standardizedFileURL)
            .reduce(into: [URL]()) { result, url in
                if !result.contains(where: { $0.path == url.path }) {
                    result.append(url)
                }
            }
            .compactMap { url -> URL? in
                if url.startAccessingSecurityScopedResource() {
                    return url
                }

                do {
                    let bookmark = try ExternalCommandCenter.defaultBookmarkEncoder(url: url)
                    let resolvedURL = try ExternalCommandCenter.defaultBookmarkResolver(data: bookmark)
                    guard resolvedURL.startAccessingSecurityScopedResource() else {
                        return nil
                    }
                    return resolvedURL
                } catch {
                    NSLog("Super RClick failed to access %@ with security scope: %@", url.path, error.localizedDescription)
                    return nil
                }
            }

        defer {
            for scopedURL in startedURLs {
                scopedURL.stopAccessingSecurityScopedResource()
            }
        }

        work()
    }

    private func triggerBatchRename(from context: SuperRClickFinderContext) {
        let actionContext = context.actionContext
        guard !actionContext.items.isEmpty else {
            NSLog("Super RClick batch rename skipped because no actionable Finder items were available.")
            return
        }

        do {
            let commandCenter = AppGroupContainer(groupIdentifier: Constants.appGroupID).makeExternalCommandCenter()
            _ = try commandCenter.storeBatchRenameRequest(for: actionContext)
            DistributedNotificationCenter.default().post(name: Shared.ExternalCommandCenter.notificationName, object: nil)
            activateMainApp()
            let msg = "Super RClick queued batch rename for \(actionContext.items.count) item(s) and activated the main app."
            NSLog("%@", msg)
        } catch {
            let err = "Super RClick failed to queue batch rename: \(error.localizedDescription)"
            NSLog("%@", err)
        }
    }

    @discardableResult
    private func runProcess(
        launchPath: String,
        arguments: [String],
        currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil
    ) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        if let environment = environment {
            process.environment = environment
        }

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            NSLog("Super RClick FinderSync process failed for %@: %@", launchPath, error.localizedDescription)
            return 1
        }
    }

    private func debugLog(_ message: String) {
        guard let logURL = debugLogURL() else {
            return
        }

        let line = message + "\n\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        if FileManager.default.fileExists(atPath: logURL.path) {
            do {
                let handle = try FileHandle(forWritingTo: logURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                NSLog("Super RClick FinderSync could not append debug log: %@", error.localizedDescription)
            }
            return
        }

        do {
            try data.write(to: logURL, options: .atomic)
        } catch {
            NSLog("Super RClick FinderSync could not create debug log: %@", error.localizedDescription)
        }
    }

    private func debugLogURL() -> URL? {
        do {
            let container = AppGroupContainer(groupIdentifier: Constants.appGroupID)
            return try container.resolveDirectory().appendingPathComponent(Constants.debugLogFileName, isDirectory: false)
        } catch {
            NSLog("Super RClick FinderSync could not resolve debug log directory: %@", error.localizedDescription)
            return nil
        }
    }

    private func normalizedDirectory(for url: URL) -> URL {
        let path = url.path(percentEncoded: false)
        let isDirectoryLike = url.hasDirectoryPath || path.hasSuffix("/")
        return isDirectoryLike ? url : url.deletingLastPathComponent()
    }

    private func uniqueDestinationURL(preferredURL: URL) -> URL {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: preferredURL.path) else {
            return preferredURL
        }

        let stem = preferredURL.deletingPathExtension().lastPathComponent
        let directory = preferredURL.deletingLastPathComponent()
        let ext = preferredURL.pathExtension

        for index in 1...99 {
            let candidate = directory.appendingPathComponent("\(stem)-\(index)").appendingPathExtension(ext)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        return directory.appendingPathComponent("\(stem)-\(UUID().uuidString.prefix(6))").appendingPathExtension(ext)
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func shellEscapedPath(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    
    private func activateMainApp() {
        guard let appBundleURL = mainAppBundleURL() else {
            NSLog("Super RClick could not resolve the host app bundle URL for activation.")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false

        NSWorkspace.shared.openApplication(at: appBundleURL, configuration: configuration) { _, error in
            if let error {
                NSLog("Super RClick failed to activate the main app: %@", error.localizedDescription)
            }
        }
    }

    private func mainAppBundleURL() -> URL? {
        var candidate = Bundle.main.bundleURL

        for _ in 0..<4 {
            candidate = candidate.deletingLastPathComponent()
            if candidate.pathExtension == "app" {
                return candidate
            }
        }

        return nil
    }
}
