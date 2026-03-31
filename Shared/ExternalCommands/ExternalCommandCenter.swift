import Foundation

public struct ExternalCommandCenter: Sendable {
    public enum ExternalCommandError: LocalizedError {
        case unsupportedContext(ActionContextKind)
        case missingItems
        case bookmarkEncodingFailed(URL, Error)
        case bookmarkResolutionFailed(Error)
        case noResolvableItems

        public var errorDescription: String? {
            switch self {
            case let .unsupportedContext(kind):
                return "External commands do not support context kind \(kind.rawValue)."
            case .missingItems:
                return "At least one Finder item is required."
            case let .bookmarkEncodingFailed(url, error):
                return "Failed to create a security-scoped bookmark for \(url.lastPathComponent): \(error.localizedDescription)"
            case let .bookmarkResolutionFailed(error):
                return "Failed to resolve a pending Finder selection: \(error.localizedDescription)"
            case .noResolvableItems:
                return "The pending Finder selection could not be restored."
            }
        }
    }

    public static let notificationName = Notification.Name("com.haoqiqin.superrclick.external-command-updated")

    public typealias BookmarkEncoder = @Sendable (URL) throws -> Data
    public typealias BookmarkResolver = @Sendable (Data) throws -> URL
    public typealias SecurityScopeStarter = @Sendable (URL) -> Bool

    private let container: AppGroupContainer
    private let storageFileName: String
    private let bookmarkEncoder: BookmarkEncoder
    private let bookmarkResolver: BookmarkResolver
    private let securityScopeStarter: SecurityScopeStarter

    public init(
        container: AppGroupContainer,
        storageFileName: String = "pending-external-command.json",
        bookmarkEncoder: @escaping BookmarkEncoder = Self.defaultBookmarkEncoder,
        bookmarkResolver: @escaping BookmarkResolver = Self.defaultBookmarkResolver,
        securityScopeStarter: @escaping SecurityScopeStarter = Self.defaultSecurityScopeStarter
    ) {
        self.container = container
        self.storageFileName = storageFileName
        self.bookmarkEncoder = bookmarkEncoder
        self.bookmarkResolver = bookmarkResolver
        self.securityScopeStarter = securityScopeStarter
    }

    public func storeBatchRenameRequest(
        for context: ActionContext,
        fileManager: FileManager = .default
    ) throws -> ExternalCommandRequest {
        guard context.kind == .finderSelection || context.kind == .mixedSelection || context.kind == .custom else {
            throw ExternalCommandError.unsupportedContext(context.kind)
        }

        guard !context.items.isEmpty else {
            throw ExternalCommandError.missingItems
        }

        let items = try context.items.map { item in
            do {
                return ExternalCommandItem(
                    bookmarkData: try bookmarkEncoder(item.url),
                    displayName: item.displayName,
                    isDirectory: item.isDirectory,
                    filePath: item.url.path
                )
            } catch {
                throw ExternalCommandError.bookmarkEncodingFailed(item.url, error)
            }
        }

        let request = ExternalCommandRequest(
            kind: .presentBatchRename,
            sourceApplicationBundleIdentifier: context.sourceApplicationBundleIdentifier,
            workspaceIdentifier: context.workspaceIdentifier,
            metadata: context.metadata,
            items: items
        )

        let data = try JSONEncoder().encode(request)
        try data.write(to: storageFileURL(fileManager: fileManager), options: .atomic)
        return request
    }

    public func storeRunActionRequest(
        actionID: String,
        for context: ActionContext,
        fileManager: FileManager = .default
    ) throws -> ExternalCommandRequest {
        guard context.kind == .finderSelection || context.kind == .mixedSelection || context.kind == .custom else {
            throw ExternalCommandError.unsupportedContext(context.kind)
        }

        let items = try context.items.map { item in
            do {
                return ExternalCommandItem(
                    bookmarkData: try bookmarkEncoder(item.url),
                    displayName: item.displayName,
                    isDirectory: item.isDirectory,
                    filePath: item.url.path
                )
            } catch {
                throw ExternalCommandError.bookmarkEncodingFailed(item.url, error)
            }
        }

        var metadata = context.metadata
        metadata["target.action.id"] = actionID

        let request = ExternalCommandRequest(
            kind: .runAction,
            sourceApplicationBundleIdentifier: context.sourceApplicationBundleIdentifier,
            workspaceIdentifier: context.workspaceIdentifier,
            metadata: metadata,
            items: items
        )

        let data = try JSONEncoder().encode(request)
        try data.write(to: storageFileURL(fileManager: fileManager), options: .atomic)
        return request
    }

    public func loadPendingRequest(fileManager: FileManager = .default) throws -> ExternalCommandRequest? {
        let fileURL = try storageFileURL(fileManager: fileManager)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(ExternalCommandRequest.self, from: data)
    }

    public func consumePendingRequest(fileManager: FileManager = .default) throws -> ExternalCommandRequest? {
        let fileURL = try storageFileURL(fileManager: fileManager)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        try? fileManager.removeItem(at: fileURL)
        return try JSONDecoder().decode(ExternalCommandRequest.self, from: data)
    }

    public func clearPendingRequest(fileManager: FileManager = .default) throws {
        let fileURL = try storageFileURL(fileManager: fileManager)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return
        }

        try fileManager.removeItem(at: fileURL)
    }

    public func resolveRequest(_ request: ExternalCommandRequest) throws -> ResolvedExternalCommand {
        var validItems: [ActionItem] = []
        var scopedURLs: [URL] = []

        for item in request.items {
            // Try security-scoped bookmark first
            if let url = try? bookmarkResolver(item.bookmarkData) {
                validItems.append(ActionItem(
                    url: url.standardizedFileURL,
                    displayName: item.displayName ?? url.lastPathComponent,
                    contentTypeIdentifier: nil,
                    isDirectory: item.isDirectory
                ))
                if securityScopeStarter(url) {
                    scopedURLs.append(url)
                }
                continue
            }

            // Fallback: use raw file path (works in local dev without proper code signing)
            if let filePath = item.filePath {
                let url = URL(fileURLWithPath: filePath)
                if FileManager.default.fileExists(atPath: filePath) {
                    NSLog("[SuperRClick] resolveRequest: bookmark failed for %@, using filePath fallback", filePath)
                    validItems.append(ActionItem(
                        url: url.standardizedFileURL,
                        displayName: item.displayName ?? url.lastPathComponent,
                        contentTypeIdentifier: nil,
                        isDirectory: item.isDirectory
                    ))
                    continue
                }
            }

            NSLog("[SuperRClick] resolveRequest: could not resolve item %@", item.displayName ?? "unknown")
        }

        guard !validItems.isEmpty else {
            throw ExternalCommandError.noResolvableItems
        }

        let workspaceIdentifier = request.workspaceIdentifier
            ?? validItems.first?.url.deletingLastPathComponent().path(percentEncoded: false)

        var metadata = request.metadata
        metadata["external.command.kind"] = request.kind.rawValue

        let context = ActionContext.finderSelection(
            validItems,
            sourceApplicationBundleIdentifier: request.sourceApplicationBundleIdentifier,
            workspaceIdentifier: workspaceIdentifier,
            metadata: metadata
        )

        return ResolvedExternalCommand(
            request: request,
            context: context,
            securityScopedURLs: scopedURLs
        )
    }

    private func storageFileURL(fileManager: FileManager) throws -> URL {
        try container.resolveDirectory(fileManager: fileManager)
            .appendingPathComponent(storageFileName, isDirectory: false)
    }

    public static func defaultBookmarkEncoder(url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    public static func defaultBookmarkResolver(data: Data) throws -> URL {
        var isStale = false
        let resolvedURL = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        return resolvedURL
    }

    public static func defaultSecurityScopeStarter(url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }
}

