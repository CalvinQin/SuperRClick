import Foundation

public enum BatchRenameMode: String, Codable, Hashable, Sendable {
    case prefix
    case suffix
}

public struct BatchRenameNumberingOptions: Codable, Hashable, Sendable {
    public var isEnabled: Bool
    public var start: Int
    public var step: Int
    public var padding: Int
    public var separator: String

    public init(
        isEnabled: Bool = false,
        start: Int = 1,
        step: Int = 1,
        padding: Int = 0,
        separator: String = "-"
    ) {
        self.isEnabled = isEnabled
        self.start = start
        self.step = step == 0 ? 1 : step
        self.padding = max(0, padding)
        self.separator = separator
    }

    func formattedValue(for index: Int) -> String {
        guard isEnabled else { return "" }

        let rawValue = start + (index * step)
        guard padding > 0 else { return String(rawValue) }

        return String(format: "%0*d", padding, rawValue)
    }
}

public struct BatchRenameItemInput: Identifiable, Codable, Hashable, Sendable {
    public var id: URL { url }

    public var url: URL
    public var displayName: String?
    public var isDirectory: Bool

    public init(
        url: URL,
        displayName: String? = nil,
        isDirectory: Bool = false
    ) {
        self.url = url
        self.displayName = displayName
        self.isDirectory = isDirectory
    }

    public init(actionItem: ActionItem) {
        self.init(
            url: actionItem.url,
            displayName: actionItem.displayName,
            isDirectory: actionItem.isDirectory
        )
    }
}

public struct BatchRenameRequest: Codable, Hashable, Sendable {
    public var mode: BatchRenameMode
    public var token: String
    public var numbering: BatchRenameNumberingOptions
    public var items: [BatchRenameItemInput]
    public var preserveFileExtension: Bool

    public init(
        mode: BatchRenameMode,
        token: String,
        numbering: BatchRenameNumberingOptions = BatchRenameNumberingOptions(),
        items: [BatchRenameItemInput],
        preserveFileExtension: Bool = true
    ) {
        self.mode = mode
        self.token = token.trimmingCharacters(in: .whitespacesAndNewlines)
        self.numbering = numbering
        self.items = items
        self.preserveFileExtension = preserveFileExtension
    }
}

public enum BatchRenamePreviewStatus: String, Codable, Hashable, Sendable {
    case ready
    case unchanged
    case duplicateProposedName
    case existingFileOnDisk
    case invalidName
}

public struct BatchRenameConflict: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable {
        case noSelection
        case duplicateProposedName
        case existingFileOnDisk
        case invalidName
    }

    public var id: UUID
    public var kind: Kind
    public var sourceURL: URL?
    public var proposedURL: URL?
    public var message: String

    public init(
        id: UUID = UUID(),
        kind: Kind,
        sourceURL: URL? = nil,
        proposedURL: URL? = nil,
        message: String
    ) {
        self.id = id
        self.kind = kind
        self.sourceURL = sourceURL
        self.proposedURL = proposedURL
        self.message = message
    }
}

public struct BatchRenamePreviewItem: Identifiable, Codable, Hashable, Sendable {
    public var id: URL { sourceURL }

    public var sourceURL: URL
    public var sourceName: String
    public var proposedURL: URL
    public var proposedName: String
    public var sequenceValue: String?
    public var status: BatchRenamePreviewStatus

    public init(
        sourceURL: URL,
        sourceName: String,
        proposedURL: URL,
        proposedName: String,
        sequenceValue: String? = nil,
        status: BatchRenamePreviewStatus
    ) {
        self.sourceURL = sourceURL
        self.sourceName = sourceName
        self.proposedURL = proposedURL
        self.proposedName = proposedName
        self.sequenceValue = sequenceValue
        self.status = status
    }
}

public struct BatchRenamePlan: Codable, Hashable, Sendable {
    public var request: BatchRenameRequest
    public var previews: [BatchRenamePreviewItem]
    public var conflicts: [BatchRenameConflict]

    public init(
        request: BatchRenameRequest,
        previews: [BatchRenamePreviewItem],
        conflicts: [BatchRenameConflict]
    ) {
        self.request = request
        self.previews = previews
        self.conflicts = conflicts
    }

    public var hasConflicts: Bool {
        !conflicts.isEmpty
    }

    public var canApply: Bool {
        !previews.isEmpty && conflicts.isEmpty
    }

    public var summary: String {
        if previews.isEmpty {
            return L("未选择任何项目。", "No items selected.")
        }

        if conflicts.isEmpty {
            return L("准备重命名 \(previews.count) 个项目。", "Ready to rename \(previews.count) item(s).")
        }

        return L("\(previews.count) 个项目，\(conflicts.count) 个冲突。", "\(previews.count) item(s), \(conflicts.count) conflict(s).")
    }
}
