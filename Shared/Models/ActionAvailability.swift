import Foundation

public struct ActionAvailability: Codable, Hashable, Sendable {
    public var allowedContextKinds: Set<ActionContextKind>
    public var minimumSelectionCount: Int
    public var maximumSelectionCount: Int?
    public var requiresFileItems: Bool
    public var requiresTextSelection: Bool
    public var requiredFileExtensions: Set<String>
    public var requiredSourceApplicationBundleIdentifiers: Set<String>

    public init(
        allowedContextKinds: Set<ActionContextKind> = [],
        minimumSelectionCount: Int = 1,
        maximumSelectionCount: Int? = nil,
        requiresFileItems: Bool = false,
        requiresTextSelection: Bool = false,
        requiredFileExtensions: Set<String> = [],
        requiredSourceApplicationBundleIdentifiers: Set<String> = []
    ) {
        self.allowedContextKinds = allowedContextKinds
        self.minimumSelectionCount = minimumSelectionCount
        self.maximumSelectionCount = maximumSelectionCount
        self.requiresFileItems = requiresFileItems
        self.requiresTextSelection = requiresTextSelection
        self.requiredFileExtensions = Set(requiredFileExtensions.map { $0.lowercased() })
        self.requiredSourceApplicationBundleIdentifiers = requiredSourceApplicationBundleIdentifiers
    }

    public func matches(_ context: ActionContext) -> Bool {
        if !allowedContextKinds.isEmpty, !allowedContextKinds.contains(context.kind) {
            return false
        }

        if context.totalSelectionCount < minimumSelectionCount {
            return false
        }

        if let maximumSelectionCount, context.totalSelectionCount > maximumSelectionCount {
            return false
        }

        if requiresFileItems, !context.hasFileItems {
            return false
        }

        if requiresTextSelection, !context.hasTextSelection {
            return false
        }

        if !requiredFileExtensions.isEmpty {
            let contextExtensions = context.itemFileExtensions
            if contextExtensions.isEmpty || !contextExtensions.isSubset(of: requiredFileExtensions) {
                return false
            }
        }

        if !requiredSourceApplicationBundleIdentifiers.isEmpty {
            guard let sourceApplicationBundleIdentifier = context.sourceApplicationBundleIdentifier else {
                return false
            }

            if !requiredSourceApplicationBundleIdentifiers.contains(sourceApplicationBundleIdentifier) {
                return false
            }
        }

        return true
    }
}

