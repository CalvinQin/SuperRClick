import Foundation
import FinderSync
import Shared

public enum SuperRClickFinderMenuKind: String, CaseIterable {
    case items
    case container
    case sidebar
    case toolbar

    init(_ finderMenuKind: FIMenuKind) {
        switch finderMenuKind {
        case .contextualMenuForContainer:
            self = .container
        case .contextualMenuForSidebar:
            self = .sidebar
        case .toolbarItemMenu:
            self = .toolbar
        default:
            self = .items
        }
    }
}

public enum SuperRClickFinderSurface: String, CaseIterable {
    case items
    case desktopBackground
    case folderBackground
    case sidebar
    case toolbar
}

public struct SuperRClickFinderContext {
    public let menuKind: SuperRClickFinderMenuKind
    public let targetedURL: URL?
    public let selectedItemURLs: [URL]
    public let monitoredDirectoryURLs: [URL]

    public init(
        menuKind: SuperRClickFinderMenuKind,
        targetedURL: URL?,
        selectedItemURLs: [URL],
        monitoredDirectoryURLs: [URL]
    ) {
        self.menuKind = menuKind
        self.targetedURL = targetedURL?.standardizedFileURL
        self.selectedItemURLs = selectedItemURLs.map { $0.standardizedFileURL }
        self.monitoredDirectoryURLs = monitoredDirectoryURLs.map { $0.standardizedFileURL }
    }

    public var surface: SuperRClickFinderSurface {
        switch menuKind {
        case .items:
            return .items
        case .container:
            return isDesktopBackground ? .desktopBackground : .folderBackground
        case .sidebar:
            return .sidebar
        case .toolbar:
            return .toolbar
        }
    }

    public var hasSelection: Bool {
        !selectedItemURLs.isEmpty
    }

    public var isMultiSelection: Bool {
        selectedItemURLs.count > 1
    }

    public var isDesktopBackground: Bool {
        guard menuKind == .container, let targetedURL else {
            return false
        }

        return Self.isDesktopURL(targetedURL)
    }

    public var isContainerBackground: Bool {
        menuKind == .container && !hasSelection
    }

    public var workspaceIdentifier: String? {
        if let targetedURL {
            return targetedURL.path
        }

        if let firstSelection = selectedItemURLs.first {
            return firstSelection.deletingLastPathComponent().path
        }

        return nil
    }

    public var effectiveSelectionURLs: [URL] {
        if hasSelection {
            return selectedItemURLs
        }
        if let targetedURL {
            return [targetedURL]
        }
        return []
    }

    public var actionContext: ActionContext {
        let metadata = [
            ActionContext.MetadataKey.finderMenuKind.rawValue: menuKind.rawValue,
            ActionContext.MetadataKey.finderSurface.rawValue: sharedFinderSurface.rawValue
        ]

        if !hasSelection, let targetedURL {
            return ActionContext.finderContainer(
                targetedURL,
                displayName: targetedURL.lastPathComponent.isEmpty ? "Finder" : targetedURL.lastPathComponent,
                surface: sharedFinderSurface,
                sourceApplicationBundleIdentifier: "com.apple.finder",
                workspaceIdentifier: workspaceIdentifier,
                metadata: metadata
            )
        }

        return ActionContext(
            kind: menuKind == .toolbar ? .custom : .finderSelection,
            items: effectiveSelectionURLs.map { Self.makeActionItem(from: $0) },
            sourceApplicationBundleIdentifier: "com.apple.finder",
            workspaceIdentifier: workspaceIdentifier,
            metadata: metadata
        )
    }

    private var sharedFinderSurface: FinderSurface {
        switch surface {
        case .desktopBackground:
            return .desktop
        case .folderBackground, .sidebar, .toolbar:
            return .container
        case .items:
            return .selection
        }
    }

    private static func makeActionItem(from url: URL) -> ActionItem {
        ActionItem(
            url: url,
            displayName: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
            contentTypeIdentifier: nil,
            isDirectory: isDirectory(url)
        )
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        return isDirectory.boolValue
    }

    private static func isDesktopURL(_ url: URL) -> Bool {
        let normalizedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        return [RealUserDirectories.desktop()]
            .map { $0.standardizedFileURL.resolvingSymlinksInPath() }
            .contains(where: { $0.path == normalizedURL.path })
    }
}
