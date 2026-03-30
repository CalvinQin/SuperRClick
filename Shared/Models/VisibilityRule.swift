import Foundation

public enum VisibilityRuleMode: String, Codable, Hashable, Sendable {
    case include
    case exclude
}

public struct VisibilityRule: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var actionID: ActionID?
    public var mode: VisibilityRuleMode
    public var allowedContextKinds: Set<ActionContextKind>?
    public var minimumSelectionCount: Int?
    public var maximumSelectionCount: Int?
    public var requiresFileItems: Bool?
    public var requiresTextSelection: Bool?
    public var requiredFileExtensions: Set<String>?
    public var requiredSourceApplicationBundleIdentifiers: Set<String>?

    public init(
        id: UUID = UUID(),
        actionID: ActionID? = nil,
        mode: VisibilityRuleMode,
        allowedContextKinds: Set<ActionContextKind>? = nil,
        minimumSelectionCount: Int? = nil,
        maximumSelectionCount: Int? = nil,
        requiresFileItems: Bool? = nil,
        requiresTextSelection: Bool? = nil,
        requiredFileExtensions: Set<String>? = nil,
        requiredSourceApplicationBundleIdentifiers: Set<String>? = nil
    ) {
        self.id = id
        self.actionID = actionID
        self.mode = mode
        self.allowedContextKinds = allowedContextKinds
        self.minimumSelectionCount = minimumSelectionCount
        self.maximumSelectionCount = maximumSelectionCount
        self.requiresFileItems = requiresFileItems
        self.requiresTextSelection = requiresTextSelection
        self.requiredFileExtensions = requiredFileExtensions.map { Set($0.map { $0.lowercased() }) }
        self.requiredSourceApplicationBundleIdentifiers = requiredSourceApplicationBundleIdentifiers
    }

    public func matches(actionID: ActionID, context: ActionContext) -> Bool {
        if let configuredActionID, configuredActionID != actionID {
            return false
        }

        if let allowedContextKinds, !allowedContextKinds.contains(context.kind) {
            return false
        }

        if let minimumSelectionCount, context.totalSelectionCount < minimumSelectionCount {
            return false
        }

        if let maximumSelectionCount, context.totalSelectionCount > maximumSelectionCount {
            return false
        }

        if let requiresFileItems, requiresFileItems && !context.hasFileItems {
            return false
        }

        if let requiresTextSelection, requiresTextSelection && !context.hasTextSelection {
            return false
        }

        if let requiredFileExtensions {
            let contextExtensions = context.itemFileExtensions
            if contextExtensions.isEmpty || !contextExtensions.isSubset(of: requiredFileExtensions) {
                return false
            }
        }

        if let requiredSourceApplicationBundleIdentifiers {
            guard let sourceApplicationBundleIdentifier = context.sourceApplicationBundleIdentifier else {
                return false
            }

            if !requiredSourceApplicationBundleIdentifiers.contains(sourceApplicationBundleIdentifier) {
                return false
            }
        }

        return true
    }

    private var configuredActionID: ActionID? {
        actionID
    }
}

