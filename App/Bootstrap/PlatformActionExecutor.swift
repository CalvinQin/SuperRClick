import AppKit
import Foundation
import Shared

typealias ProgressCallback = @Sendable (Int, Int, String) -> Void

actor PlatformActionExecutor {
    private let revealCreatedFile: @Sendable (URL) async -> Void

    init(revealCreatedFile: @escaping @Sendable (URL) async -> Void = { url in
        await MainActor.run { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }) {
        self.revealCreatedFile = revealCreatedFile
    }

    func execute(actionID: ActionID, context: ActionContext, onProgress: ProgressCallback? = nil) async -> ActionExecutionResult {
        switch actionID.rawValue {
        case BuiltInActionCatalog.copyFullPath.id.rawValue:
            return await copyPaths(context.itemURLs, transform: \.path)
        case BuiltInActionCatalog.copyPOSIXPath.id.rawValue:
            return await copyPaths(context.itemURLs, transform: \.path)
        case BuiltInActionCatalog.copyShellEscapedPath.id.rawValue:
            return await copyPaths(context.itemURLs, transform: Self.shellEscapedPath)
        case BuiltInActionCatalog.openTerminalHere.id.rawValue:
            return await openTerminalHere(for: context.itemURLs.first)
        case BuiltInActionCatalog.compressItems.id.rawValue:
            return await compressItems(context.itemURLs, onProgress: onProgress)
        case BuiltInActionCatalog.batchRename.id.rawValue:
            return .blocked(reason: "Batch rename UI will land in the next milestone.")
        case BuiltInActionCatalog.convertImage.id.rawValue:
            let targetFormat = context.metadata["convertImage.format"] ?? "png"
            return await convertImages(context.itemURLs, targetFormat: targetFormat, onProgress: onProgress)
        case BuiltInActionCatalog.copySelectedText.id.rawValue:
            return await copySelectedText(context.selectedText)
        default:
            if actionID.rawValue.starts(with: "new-") {
                if let ext = actionID.rawValue.split(separator: "-").last {
                    return await createNewFile(extension: String(ext), context: context)
                }
            }
            return .missingHandler(actionID: actionID)
        }
    }

    func applyBatchRename(plan: BatchRenamePlan, onProgress: ProgressCallback? = nil) async -> ActionExecutionResult {
        guard !plan.previews.isEmpty else {
            return .blocked(reason: "Select at least one file or folder to rename.")
        }

        guard !plan.hasConflicts else {
            return .blocked(reason: plan.summary)
        }

        if let protectedPreview = plan.previews.first(where: { isProtectedLocation($0.sourceURL) }) {
            return .blocked(reason: "Refusing to rename protected location: \(protectedPreview.sourceName).")
        }

        guard plan.previews.allSatisfy({ preview in
            !preview.proposedName.contains("/") && !preview.proposedName.contains("\0") &&
            preview.sourceURL.deletingLastPathComponent().standardizedFileURL ==
                preview.proposedURL.deletingLastPathComponent().standardizedFileURL
        }) else {
            return .blocked(reason: L("新名称不能包含路径分隔符。", "New names cannot contain path separators."))
        }

        let fileManager = FileManager.default
        var renamed: [BatchRenamePreviewItem] = []
        let renamable = plan.previews.filter { $0.sourceURL.path != $0.proposedURL.path }
        let total = renamable.count

        for preview in renamable {
            do {
                onProgress?(renamed.count, total, preview.sourceName)
                try fileManager.moveItem(at: preview.sourceURL, to: preview.proposedURL)
                renamed.append(preview)
            } catch {
                var unrestored: [String] = []
                for previous in renamed.reversed() {
                    do {
                        try fileManager.moveItem(at: previous.proposedURL, to: previous.sourceURL)
                    } catch {
                        unrestored.append(previous.proposedURL.path)
                    }
                }
                let recovery = unrestored.isEmpty
                    ? L("先前已重命名的项目已恢复。", "Previously renamed items were restored.")
                    : L("部分项目无法恢复，仍位于：\(unrestored.joined(separator: "、"))。",
                        "Some items could not be restored and remain at: \(unrestored.joined(separator: ", ")).")
                return .failed(
                    reason: L("无法重命名“\(preview.sourceName)”：\(error.localizedDescription) \(recovery)",
                              "Could not rename “\(preview.sourceName)”: \(error.localizedDescription) \(recovery)"),
                    recoverable: true
                )
            }
        }
        onProgress?(renamed.count, total, "")

        return .completed(message: L("已重命名 \(renamed.count) 个项目。", "Renamed \(renamed.count) item(s)."))
    }

    private func createNewFile(extension ext: String, context: ActionContext) async -> ActionExecutionResult {
        guard let url = context.itemURLs.first else {
            return .blocked(reason: "Please pick a directory first.")
        }
        
        let directory = normalizedDirectory(for: url)
        
        let fileData = NewFileData.contents(forExtension: ext)
        do {
            let targetURL = try ExclusiveFileOutput.write(
                fileData,
                preferredURL: directory.appendingPathComponent("Untitled.\(ext)"),
                suffixSeparator: " "
            )
            await revealCreatedFile(targetURL)
            return .completed(message: "Created new \(ext.uppercased()) file.")
        } catch {
            return .failed(reason: error.localizedDescription, recoverable: true)
        }
    }

    private func copyPaths(
        _ urls: [URL],
        transform: (URL) -> String
    ) async -> ActionExecutionResult {
        guard !urls.isEmpty else {
            return .blocked(reason: "No file or folder is selected.")
        }

        let payload = urls.map(transform).joined(separator: "\n")
        await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(payload, forType: .string)
        }

        return .completed(message: "Copied \(urls.count) path(s) to the clipboard.")
    }

    private func copySelectedText(_ text: String?) async -> ActionExecutionResult {
        guard let text, !text.isEmpty else {
            return .blocked(reason: "No selected text is available.")
        }

        await MainActor.run {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }

        return .completed(message: "Copied plain text to the clipboard.")
    }

    private func openTerminalHere(for url: URL?) async -> ActionExecutionResult {
        guard let url else {
            return .blocked(reason: "Pick a file or folder first.")
        }

        let directory = normalizedDirectory(for: url)
        let result = await runProcess(
            launchPath: "/usr/bin/open",
            arguments: ["-a", "Terminal", directory.path]
        )

        guard result.terminationStatus == 0 else {
            return .failed(reason: result.errorOutput.isEmpty ? "Terminal launch failed." : result.errorOutput, recoverable: true)
        }

        return .completed(message: "Opened Terminal at \(directory.path).")
    }

    private func compressItems(_ urls: [URL], onProgress: ProgressCallback? = nil) async -> ActionExecutionResult {
        let plan: ZipArchivePlan
        do {
            plan = try ZipArchivePlan(selectedURLs: urls)
        } catch let error as ZipArchivePlan.ValidationError {
            if case .missingInput = error {
                return .failed(reason: error.localizedDescription, recoverable: true)
            }
            return .blocked(reason: error.localizedDescription)
        } catch {
            return .failed(reason: error.localizedDescription, recoverable: true)
        }

        onProgress?(0, urls.count, L("正在准备压缩...", "Preparing compression..."))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = plan.workingDirectoryURL
        process.arguments = plan.arguments

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            try? FileManager.default.removeItem(at: plan.archiveURL)
            return .failed(reason: error.localizedDescription, recoverable: true)
        }

        guard process.terminationStatus == 0 else {
            try? FileManager.default.removeItem(at: plan.archiveURL)
            return .failed(reason: L("zip 退出码 \(process.terminationStatus)。", "zip exited with code \(process.terminationStatus)."), recoverable: true)
        }

        onProgress?(urls.count, urls.count, plan.archiveURL.lastPathComponent)
        return .completed(message: L("已创建压缩包 \(plan.archiveURL.lastPathComponent)。", "Created archive \(plan.archiveURL.lastPathComponent)."))
    }

    private func convertImages(_ urls: [URL], targetFormat: String, onProgress: ProgressCallback? = nil) async -> ActionExecutionResult {
        guard !urls.isEmpty else {
            return .blocked(reason: L("请至少选择一张图片进行转换。", "Select at least one image to convert."))
        }

        // sips uses specific format identifiers
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
            return .blocked(reason: L("macOS 不支持通过 sips 导出 WebP 格式。请选择 PNG/JPEG/HEIC/TIFF。", "macOS does not support WebP export via sips. Please choose PNG/JPEG/HEIC/TIFF."))
        default:
            sipsFormat = "png"
            fileExtension = "png"
        }

        let total = urls.count
        var convertedCount = 0
        var failedNames: [String] = []
        for (index, inputURL) in urls.enumerated() {
            onProgress?(index, total, inputURL.lastPathComponent)

            let destinationURL = inputURL.deletingPathExtension().appendingPathExtension(fileExtension)
            do {
                let output = try ExclusiveFileOutput(preferredURL: destinationURL)
                defer { output.cleanup() }
                let result = await runProcess(
                    launchPath: "/usr/bin/sips",
                    arguments: ["-s", "format", sipsFormat, inputURL.path, "--out", output.temporaryURL.path]
                )
                if result.terminationStatus == 0 {
                    _ = try output.publish()
                    convertedCount += 1
                } else {
                    failedNames.append(inputURL.lastPathComponent)
                }
            } catch {
                failedNames.append(inputURL.lastPathComponent)
            }
        }
        onProgress?(total, total, "")

        guard failedNames.isEmpty else {
            let names = failedNames.joined(separator: ", ")
            return .failed(reason: L(
                "已转换 \(convertedCount)/\(total) 张图片。未能转换：\(names)。原始文件未更改。",
                "Converted \(convertedCount) of \(total) image(s). Could not convert: \(names). Original files were not changed."
            ), recoverable: true)
        }

        return .completed(message: L(
            "已将 \(convertedCount) 张图片转换为 \(targetFormat.uppercased())。",
            "Converted \(convertedCount) image(s) to \(targetFormat.uppercased())."
        ))
    }

    private func runProcess(
        launchPath: String,
        arguments: [String]
    ) async -> (terminationStatus: Int32, standardOutput: String, errorOutput: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return (1, "", error.localizedDescription)
        }

        let standardOutput = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let errorOutput = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (process.terminationStatus, standardOutput, errorOutput)
    }

    private func normalizedDirectory(for url: URL) -> URL {
        let path = url.path(percentEncoded: false)
        let isDirectoryLike = url.hasDirectoryPath || path.hasSuffix("/")
        return isDirectoryLike ? url : url.deletingLastPathComponent()
    }

    private func isProtectedLocation(_ url: URL) -> Bool {
        let protectedDirectories: [URL?] = [
            RealUserDirectories.homeDirectory(),
            RealUserDirectories.desktop(),
            RealUserDirectories.documents(),
            RealUserDirectories.downloads()
        ]

        let target = url.standardizedFileURL.resolvingSymlinksInPath().path
        return protectedDirectories
            .compactMap { $0?.standardizedFileURL.resolvingSymlinksInPath().path }
            .contains(target)
    }

    private static func shellEscapedPath(_ url: URL) -> String {
        shellEscapedPath(url.path)
    }

    private static func shellEscapedPath(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
