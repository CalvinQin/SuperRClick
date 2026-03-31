import AppKit
import Foundation
import Shared

typealias ProgressCallback = @Sendable (Int, Int, String) -> Void

actor PlatformActionExecutor {
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

        let fileManager = FileManager.default
        var renamedCount = 0
        let renamable = plan.previews.filter { $0.sourceURL.path != $0.proposedURL.path }
        let total = renamable.count

        for preview in renamable {
            do {
                onProgress?(renamedCount, total, preview.sourceName)
                try fileManager.moveItem(at: preview.sourceURL, to: preview.proposedURL)
                renamedCount += 1
            } catch {
                return .failed(
                    reason: L("重命名 \(renamedCount) 个后停止：\(error.localizedDescription)",
                              "Stopped after renaming \(renamedCount) item(s): \(error.localizedDescription)"),
                    recoverable: true
                )
            }
        }
        onProgress?(renamedCount, total, "")

        return .completed(message: L("已重命名 \(renamedCount) 个项目。", "Renamed \(renamedCount) item(s)."))
    }

    private func createNewFile(extension ext: String, context: ActionContext) async -> ActionExecutionResult {
        guard let url = context.itemURLs.first else {
            return .blocked(reason: "Please pick a directory first.")
        }
        
        let directory = normalizedDirectory(for: url)
        
        // Ensure standard naming: extension is passed like "txt"
        let baseName = "Untitled"
        var targetURL = directory.appendingPathComponent("\(baseName).\(ext)")
        
        var counter = 1
        while FileManager.default.fileExists(atPath: targetURL.path) {
            targetURL = directory.appendingPathComponent("\(baseName) \(counter).\(ext)")
            counter += 1
        }
        
        var fileData: Data? = nil
        if let base64String = NewFileData.base64Templates[ext],
           let decodedData = Data(base64Encoded: base64String) {
            fileData = decodedData
        }
        
        let success = FileManager.default.createFile(atPath: targetURL.path, contents: fileData, attributes: nil)
        if success {
            NSWorkspace.shared.activateFileViewerSelecting([targetURL])
            return .completed(message: "Created new \(ext.uppercased()) file.")
        } else {
            return .failed(reason: "Unable to create file at \(targetURL.path)", recoverable: true)
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
        guard !urls.isEmpty else {
            return .blocked(reason: L("请至少选择一个文件或文件夹进行压缩。", "Select at least one file or folder to compress."))
        }

        let parents = Set(urls.map { normalizedDirectory(for: $0).path })
        guard parents.count == 1, let parentPath = parents.first else {
            return .blocked(reason: L("压缩功能要求所有文件在同一文件夹下。", "Compression currently requires items from the same folder."))
        }

        let parentDirectory = URL(fileURLWithPath: parentPath, isDirectory: true)
        let archiveName = "SuperRClick-\(timestamp()).zip"
        let archiveURL = parentDirectory.appendingPathComponent(archiveName)

        onProgress?(0, urls.count, L("正在准备压缩...", "Preparing compression..."))

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = parentDirectory
        process.arguments = ["-r", archiveURL.lastPathComponent] + urls.map(\.lastPathComponent)

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return .failed(reason: error.localizedDescription, recoverable: true)
        }

        onProgress?(urls.count, urls.count, archiveURL.lastPathComponent)

        guard process.terminationStatus == 0 else {
            return .failed(reason: L("zip 退出码 \(process.terminationStatus)。", "zip exited with code \(process.terminationStatus)."), recoverable: true)
        }

        return .completed(message: L("已创建压缩包 \(archiveURL.lastPathComponent)。", "Created archive \(archiveURL.lastPathComponent)."))
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
        for (index, inputURL) in urls.enumerated() {
            onProgress?(index, total, inputURL.lastPathComponent)

            let destinationURL = inputURL.deletingPathExtension().appendingPathExtension(fileExtension)
            let uniqueOutput = uniqueDestinationURL(preferredURL: destinationURL)

            let result = await runProcess(
                launchPath: "/usr/bin/sips",
                arguments: ["-s", "format", sipsFormat, inputURL.path, "--out", uniqueOutput.path]
            )

            if result.terminationStatus == 0 {
                convertedCount += 1
            }
        }
        onProgress?(total, total, "")

        guard convertedCount > 0 else {
            return .failed(reason: L("所选图片均无法转换。", "None of the selected images could be converted."), recoverable: true)
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
