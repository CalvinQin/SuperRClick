import Foundation

public struct AppGroupContainer: Sendable {
    public var groupIdentifier: String?
    public var fallbackFolderName: String

    public init(groupIdentifier: String? = nil, fallbackFolderName: String = "SuperRClick") {
        self.groupIdentifier = groupIdentifier
        self.fallbackFolderName = fallbackFolderName
    }

    public func resolveDirectory(fileManager: FileManager = .default) throws -> URL {
        if let groupIdentifier,
           let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) {
            try ensureDirectoryExists(containerURL, fileManager: fileManager)
            return containerURL
        }

        let appSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let fallbackDirectory = appSupportDirectory.appendingPathComponent(fallbackFolderName, isDirectory: true)
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
