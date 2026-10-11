import Foundation

public struct AppGroupContainer: Sendable {
    public var groupIdentifier: String?
    public var fallbackFolderName: String

    public init(groupIdentifier: String? = nil, fallbackFolderName: String = "SuperRClick") {
        self.groupIdentifier = groupIdentifier
        self.fallbackFolderName = fallbackFolderName
    }

    public func resolveDirectory(fileManager: FileManager = .default) throws -> URL {
        #if DEBUG
        // UI tests and local previews must never migrate or overwrite the user's configuration.
        if let path = ProcessInfo.processInfo.environment["SUPERRCLICK_TEST_STORAGE"], path.hasPrefix("/") {
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            try ensureDirectoryExists(directory, fileManager: fileManager)
            return directory
        }
        #endif
        if let groupIdentifier,
           let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) {
            try ensureDirectoryExists(containerURL, fileManager: fileManager)
            return containerURL
        }

        // Fallback to /Users/Shared to guarantee cross-process file sharing 
        // even if App Group entitlements fail during local ad-hoc signing.
        let fallbackDirectory = URL(fileURLWithPath: "/Users/Shared").appendingPathComponent(fallbackFolderName, isDirectory: true)
        try ensureDirectoryExists(fallbackDirectory, fileManager: fileManager)
        return fallbackDirectory
    }

    public func makePersistenceController(fileManager: FileManager = .default) throws -> PersistenceController {
        let directory = try resolveDirectory(fileManager: fileManager)
        return PersistenceController(storageDirectory: directory, fileManager: fileManager)
    }

    public func makeExternalCommandCenter(fileManager _: FileManager = .default) -> ExternalCommandCenter {
        ExternalCommandCenter(container: self)
    }

    private func ensureDirectoryExists(_ directory: URL, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: directory.path, isDirectory: nil) {
            return
        }

        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
    }
}
