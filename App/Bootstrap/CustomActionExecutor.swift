import Foundation
import Shared

/// Executes the user's saved actions without blocking the application's main actor.
actor CustomActionExecutor {
    private let temporaryDirectory: URL

    init(temporaryDirectory: URL = FileManager.default.temporaryDirectory) {
        self.temporaryDirectory = temporaryDirectory
    }

    func execute(_ candidate: CustomAction, context: ActionContext) async -> ActionExecutionResult {
        let action: CustomAction
        do {
            action = try candidate.validated()
        } catch {
            return .blocked(reason: error.localizedDescription)
        }
        guard action.isEnabled, action.toActionDefinition().matches(context) else {
            return .blocked(reason: L("此自定义动作不适用于当前选择。", "This custom action is not available for the current selection."))
        }

        let workspace = temporaryDirectory.appendingPathComponent("SuperRClickAction-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: workspace) }

            let process = Process()
            var environment = ProcessInfo.processInfo.environment
            environment["SELECTED_FILES"] = context.itemURLs.map(\.path).joined(separator: "\n")
            environment["FIRST_FILE"] = context.itemURLs.first?.path ?? ""
            let targetDirectory = context.items.first.map { $0.isDirectory ? $0.url : $0.url.deletingLastPathComponent() }
            environment["TARGET_DIR"] = targetDirectory?.path ?? ""
            process.environment = environment
            process.currentDirectoryURL = targetDirectory

            switch action.actionType {
            case .shellScript, .appleScript:
                let script = workspace.appendingPathComponent(action.actionType == .shellScript ? "action.sh" : "action.applescript")
                try action.scriptContent.write(to: script, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: script.path)
                process.executableURL = URL(fileURLWithPath: action.actionType == .shellScript ? "/bin/sh" : "/usr/bin/osascript")
                process.arguments = [script.path]
            case .openApplication:
                let identifier = action.scriptContent.trimmingCharacters(in: .whitespacesAndNewlines)
                let isBundleID = identifier.contains(".") && !identifier.contains("/") && !identifier.lowercased().hasSuffix(".app")
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                process.arguments = [isBundleID ? "-b" : "-a", identifier] + context.itemURLs.map(\.path)
            }

            // File-backed output prevents a verbose script from filling an unread pipe.
            let outputURL = workspace.appendingPathComponent("stdout")
            let errorURL = workspace.appendingPathComponent("stderr")
            _ = FileManager.default.createFile(atPath: outputURL.path, contents: nil)
            _ = FileManager.default.createFile(atPath: errorURL.path, contents: nil)
            let output = try FileHandle(forWritingTo: outputURL)
            let errors = try FileHandle(forWritingTo: errorURL)
            defer {
                try? output.close()
                try? errors.close()
            }
            process.standardOutput = output
            process.standardError = errors

            let exitStatus = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
                process.terminationHandler = { finished in
                    continuation.resume(returning: finished.terminationStatus)
                }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }

            let standardOutput = try readOutput(outputURL)
            let standardError = try readOutput(errorURL)
            guard exitStatus == 0 else {
                let detail = standardError.isEmpty ? standardOutput : standardError
                let reason = L("动作退出，代码 \(exitStatus)。", "The action exited with code \(exitStatus).")
                return .failed(reason: detail.isEmpty ? reason : reason + "\n" + detail, recoverable: true)
            }
            return .completed(message: standardOutput.isEmpty ? L("自定义动作已完成。", "Custom action completed.") : standardOutput)
        } catch {
            return .failed(reason: error.localizedDescription, recoverable: true)
        }
    }

    private func readOutput(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: 16_384) ?? Data()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
