import Foundation

public enum ActionContextKind: String, Codable, Hashable, Sendable {
    case finderSelection
    case textSelection
    case mixedSelection
    case custom
}

public enum FinderSurface: String, Codable, Hashable, Sendable {
    case selection
    case container
    case desktop
}

public struct ActionItem: Identifiable, Codable, Hashable, Sendable {
    public var id: URL { url }
    public var url: URL
    public var displayName: String?
    public var contentTypeIdentifier: String?
    public var isDirectory: Bool

    public init(
        url: URL,
        displayName: String? = nil,
        contentTypeIdentifier: String? = nil,
        isDirectory: Bool = false
    ) {
        self.url = url
        self.displayName = displayName
        self.contentTypeIdentifier = contentTypeIdentifier
        self.isDirectory = isDirectory
    }

    public var fileExtension: String {
        url.pathExtension.lowercased()
    }
}

public struct ContextSnapshot: Codable, Hashable, Sendable {
    public var kind: ActionContextKind
    public var itemPaths: [String]
    public var selectedTextPreview: String?
    public var sourceApplicationBundleIdentifier: String?
    public var workspaceIdentifier: String?

    public init(
        kind: ActionContextKind,
        itemPaths: [String],
        selectedTextPreview: String? = nil,
        sourceApplicationBundleIdentifier: String? = nil,
        workspaceIdentifier: String? = nil
    ) {
        self.kind = kind
        self.itemPaths = itemPaths
        self.selectedTextPreview = selectedTextPreview
        self.sourceApplicationBundleIdentifier = sourceApplicationBundleIdentifier
        self.workspaceIdentifier = workspaceIdentifier
    }
}

public struct ActionContext: Codable, Hashable, Sendable {
    public enum MetadataKey: String, Codable, Hashable, Sendable {
        case finderMenuKind = "finder.menu.kind"
        case finderSurface = "finder.surface"
    }

    public var kind: ActionContextKind
    public var items: [ActionItem]
    public var selectedText: String?
    public var sourceApplicationBundleIdentifier: String?
    public var workspaceIdentifier: String?
    public var metadata: [String: String]

    public init(
        kind: ActionContextKind? = nil,
        items: [ActionItem] = [],
        selectedText: String? = nil,
        sourceApplicationBundleIdentifier: String? = nil,
        workspaceIdentifier: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.items = items
        self.selectedText = Self.normalizedText(selectedText)
        self.sourceApplicationBundleIdentifier = sourceApplicationBundleIdentifier
        self.workspaceIdentifier = workspaceIdentifier
        self.metadata = metadata
        self.kind = kind ?? Self.inferredKind(items: items, selectedText: self.selectedText)
    }

    public static func finderSelection(
        _ items: [ActionItem],
        sourceApplicationBundleIdentifier: String? = nil,
        workspaceIdentifier: String? = nil,
        metadata: [String: String] = [:]
    ) -> ActionContext {
        ActionContext(
            kind: .finderSelection,
            items: items,
            selectedText: nil,
            sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier,
            workspaceIdentifier: workspaceIdentifier,
            metadata: metadata
        )
    }

    public static func finderContainer(
        _ url: URL,
        displayName: String? = nil,
        surface: FinderSurface = .container,
        sourceApplicationBundleIdentifier: String? = nil,
        workspaceIdentifier: String? = nil,
        metadata: [String: String] = [:]
    ) -> ActionContext {
        var resolvedMetadata = metadata
        resolvedMetadata[MetadataKey.finderSurface.rawValue] = surface.rawValue
        resolvedMetadata[MetadataKey.finderMenuKind.rawValue] = resolvedMetadata[MetadataKey.finderMenuKind.rawValue] ?? "container"

        return ActionContext.finderSelection(
            [
                ActionItem(
                    url: url,
                    displayName: displayName ?? url.lastPathComponent,
                    contentTypeIdentifier: nil,
                    isDirectory: true
                )
            ],
            sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier,
            workspaceIdentifier: workspaceIdentifier ?? url.path,
            metadata: resolvedMetadata
        )
    }

    public static func textSelection(
        _ text: String,
        sourceApplicationBundleIdentifier: String? = nil,
        workspaceIdentifier: String? = nil,
        metadata: [String: String] = [:]
    ) -> ActionContext {
        ActionContext(
            kind: .textSelection,
            items: [],
            selectedText: text,
            sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier,
            workspaceIdentifier: workspaceIdentifier,
            metadata: metadata
        )
    }

    public static func mixedSelection(
        items: [ActionItem],
        selectedText: String,
        sourceApplicationBundleIdentifier: String? = nil,
        workspaceIdentifier: String? = nil,
        metadata: [String: String] = [:]
    ) -> ActionContext {
        ActionContext(
            kind: .mixedSelection,
            items: items,
            selectedText: selectedText,
            sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier,
            workspaceIdentifier: workspaceIdentifier,
            metadata: metadata
        )
    }

    public var hasTextSelection: Bool {
        selectedText?.isEmpty == false
    }

    public var hasFileItems: Bool {
        !items.isEmpty
    }

    public var totalSelectionCount: Int {
        items.count + (hasTextSelection ? 1 : 0)
    }

    public var directoryItems: [ActionItem] {
        items.filter { $0.isDirectory }
    }

    public var fileItems: [ActionItem] {
        items.filter { !$0.isDirectory }
    }

    public var itemURLs: [URL] {
        items.map(\.url)
    }

    public var itemFileExtensions: Set<String> {
        Set(items.map(\.fileExtension).filter { !$0.isEmpty })
    }

    public var snapshot: ContextSnapshot {
        ContextSnapshot(
            kind: kind,
            itemPaths: items.map(\.url.path),
            selectedTextPreview: selectedText.map { Self.previewText($0) },
            sourceApplicationBundleIdentifier: sourceApplicationBundleIdentifier,
            workspaceIdentifier: workspaceIdentifier
        )
    }

    public var summary: String {
        if isFinderDesktopSurface, let item = items.first {
            return item.displayName ?? "Desktop"
        }

        if hasTextSelection {
            return "Text: \(Self.previewText(selectedText ?? ""))"
        }

        switch items.count {
        case 0:
            return "No selection"
        case 1:
            let item = items[0]
            return item.displayName ?? item.url.lastPathComponent
        default:
            return "\(items.count) items"
        }
    }

    public var finderMenuKind: String? {
        metadata[MetadataKey.finderMenuKind.rawValue]
    }

    public var finderSurface: FinderSurface? {
        guard let rawValue = metadata[MetadataKey.finderSurface.rawValue] else {
            return nil
        }

        return FinderSurface(rawValue: rawValue)
    }

    public var isFinderDesktopSurface: Bool {
        finderSurface == .desktop
    }

    public var primaryItem: ActionItem? {
        items.first
    }

    public var primaryDirectoryURL: URL? {
        if let directory = items.first(where: \.isDirectory) {
            return directory.url
        }

        return items.first?.url.deletingLastPathComponent()
    }

    private static func inferredKind(items: [ActionItem], selectedText: String?) -> ActionContextKind {
        let hasItems = !items.isEmpty
        let hasText = selectedText?.isEmpty == false

        switch (hasItems, hasText) {
        case (true, true):
            return .mixedSelection
        case (true, false):
            return .finderSelection
        case (false, true):
            return .textSelection
        case (false, false):
            return .custom
        }
    }

    private static func normalizedText(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func previewText(_ text: String, limit: Int = 80) -> String {
        let compact = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard compact.count > limit else { return compact }
        let index = compact.index(compact.startIndex, offsetBy: limit)
        return String(compact[..<index]) + "…"
    }
}
