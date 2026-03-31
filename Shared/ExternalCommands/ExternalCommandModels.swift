import Foundation

public enum ExternalCommandKind: String, Codable, Hashable, Sendable {
    case presentBatchRename
    case runAction
}

public struct ExternalCommandItem: Codable, Hashable, Sendable {
    public var bookmarkData: Data
    public var displayName: String?
    public var isDirectory: Bool
    /// Raw file path as fallback when security-scoped bookmark resolution fails
    /// (e.g. during local development without proper code signing).
    public var filePath: String?

    public init(
        bookmarkData: Data,
        displayName: String? = nil,
        isDirectory: Bool,
        filePath: String? = nil
    ) {
        self.bookmarkData = bookmarkData
        self.displayName = displayName
        self.isDirectory = isDirectory
        self.filePath = filePath
    }
}

public struct ExternalCommandRequest: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var kind: ExternalCommandKind
    public var createdAt: Date
    public var sourceApplicationBundleIdentifier: String?
    public var workspaceIdentifier: String?
    public var metadata: [String: String]
    public var items: [ExternalCommandItem]

    public init(
        id: UUID = UUID(),
        kind: ExternalCommandKind,
        createdAt: Date = Date(),
        sourceApplicationBundleIdentifier: String? = nil,
        workspaceIdentifier: String? = nil,
        metadata: [String: String] = [:],
        items: [ExternalCommandItem]
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.sourceApplicationBundleIdentifier = sourceApplicationBundleIdentifier
        self.workspaceIdentifier = workspaceIdentifier
        self.metadata = metadata
        self.items = items
    }
}

public struct ResolvedExternalCommand: Sendable {
    public var request: ExternalCommandRequest
    public var context: ActionContext
    public var securityScopedURLs: [URL]

    public init(
        request: ExternalCommandRequest,
        context: ActionContext,
        securityScopedURLs: [URL]
    ) {
        self.request = request
        self.context = context
        self.securityScopedURLs = securityScopedURLs
    }
}

