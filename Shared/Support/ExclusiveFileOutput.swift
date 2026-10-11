import Darwin
import Foundation

/// Stages a file on the destination volume and publishes it without replacing any existing entry.
/// Call `cleanup()` in a defer block, including when the producer fails.
public struct ExclusiveFileOutput: Sendable {
    public let temporaryURL: URL
    private let directoryURL: URL
    private let preferredURL: URL
    private let suffixSeparator: String

    public init(preferredURL: URL, suffixSeparator: String = "-") throws {
        guard preferredURL.isFileURL else { throw CocoaError(.fileWriteUnsupportedScheme) }
        self.preferredURL = preferredURL
        self.suffixSeparator = suffixSeparator
        directoryURL = preferredURL.deletingLastPathComponent()
            .appendingPathComponent(".SuperRClick-output-\(UUID().uuidString)", isDirectory: true)
        // mkdir must create this exact directory; an existing entry is never adopted.
        let created = directoryURL.withUnsafeFileSystemRepresentation { mkdir($0, 0o700) }
        guard created == 0 else {
            let failure = errno
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(failure), userInfo: [NSFilePathErrorKey: directoryURL.path])
        }
        temporaryURL = directoryURL.appendingPathComponent(preferredURL.lastPathComponent)
    }

    /// RENAME_EXCL checks and moves atomically. Existing files, directories and dangling
    /// symlinks all remain untouched, including entries created after an earlier check.
    public func publish() throws -> URL {
        let parent = preferredURL.deletingLastPathComponent()
        let stem = preferredURL.deletingPathExtension().lastPathComponent
        let fileExtension = preferredURL.pathExtension
        var index = 0

        while true {
            let destination: URL
            if index == 0 {
                destination = preferredURL
            } else {
                let name = "\(stem)\(suffixSeparator)\(index)"
                destination = fileExtension.isEmpty
                    ? parent.appendingPathComponent(name)
                    : parent.appendingPathComponent(name).appendingPathExtension(fileExtension)
            }
            let result = temporaryURL.withUnsafeFileSystemRepresentation { source in
                destination.withUnsafeFileSystemRepresentation { target in
                    renamex_np(source, target, UInt32(RENAME_EXCL))
                }
            }
            if result == 0 { return destination }
            let failure = errno
            guard failure == EEXIST else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(failure), userInfo: [NSFilePathErrorKey: destination.path])
            }
            index += 1
        }
    }

    /// Removes only the private staging directory created by this instance.
    public func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    public static func write(_ data: Data, preferredURL: URL, suffixSeparator: String = "-") throws -> URL {
        let output = try ExclusiveFileOutput(preferredURL: preferredURL, suffixSeparator: suffixSeparator)
        defer { output.cleanup() }
        try data.write(to: output.temporaryURL, options: .withoutOverwriting)
        return try output.publish()
    }
}
