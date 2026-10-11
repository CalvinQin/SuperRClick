import Foundation

/// A validated invocation of macOS's zip tool, shared by the app and Finder extension.
/// Creating a plan does not create or modify any files.
public struct ZipArchivePlan: Sendable {
    public enum ValidationError: LocalizedError, Equatable, Sendable {
        case noSelection
        case nonFileURL(URL)
        case differentDirectories
        case missingInput(URL)

        public var errorDescription: String? {
            switch self {
            case .noSelection:
                return L("请先选择要压缩的文件或文件夹。", "Select files or folders to compress.")
            case .nonFileURL:
                return L("只能压缩本地文件或文件夹。", "Only local files or folders can be compressed.")
            case .differentDirectories:
                return L("压缩功能要求所有文件在同一文件夹下。", "Compression requires items from the same folder.")
            case let .missingInput(url):
                return L("找不到要压缩的项目：\(url.lastPathComponent)。", "An item to compress is missing: \(url.lastPathComponent).")
            }
        }
    }

    public let workingDirectoryURL: URL
    public let archiveURL: URL
    public let arguments: [String]

    public init(selectedURLs: [URL]) throws {
        guard !selectedURLs.isEmpty else { throw ValidationError.noSelection }
        if let nonFileURL = selectedURLs.first(where: { !$0.isFileURL }) {
            throw ValidationError.nonFileURL(nonFileURL)
        }

        let inputs = selectedURLs.map(\.standardizedFileURL)
        let parent = inputs[0].deletingLastPathComponent()
        guard inputs.allSatisfy({ $0.deletingLastPathComponent().path == parent.path }) else {
            throw ValidationError.differentDirectories
        }
        if let missingInput = inputs.first(where: { !FileManager.default.fileExists(atPath: $0.path) }) {
            throw ValidationError.missingInput(missingInput)
        }

        // A directory is an input just like a file: zip runs from its parent.
        workingDirectoryURL = parent
        let timestamp = Int(Date().timeIntervalSince1970 * 1_000)
        var destination: URL
        repeat {
            destination = parent.appendingPathComponent("SuperRClick-\(timestamp)-\(UUID().uuidString).zip")
        } while FileManager.default.fileExists(atPath: destination.path)
        archiveURL = destination

        // -MM fails if an input disappears after validation; -nw prevents wildcard
        // interpretation; -- protects filenames beginning with a hyphen.
        // Apple's zip advertises -UN=UTF8 in help but rejects it when executed.
        arguments = ["-r", "-q", "-MM", "-nw", archiveURL.lastPathComponent, "--"]
            + inputs.map(\.lastPathComponent)
    }
}
